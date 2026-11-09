import errno
import fcntl
import importlib.util
import os
from pathlib import Path
import select
import signal
import struct
import subprocess
import sys
import termios
import time
import unittest


SUBJECT = Path(__file__).resolve().parents[1] / "pi-surface-browser-relay.py"
spec = importlib.util.spec_from_file_location("surface_relay", SUBJECT)
relay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relay)

BEGIN = b"\x1b[?2026h"
END = b"\x1b[?2026l"


def passthrough(data):
    return b"\x1bPtmux;" + data.replace(b"\x1b", b"\x1b\x1b") + b"\x1b\\"


class StreamTests(unittest.TestCase):
    def transform(self, chunks):
        stream = relay.SyncPassthrough()
        return b"".join(stream.feed(chunk) for chunk in chunks) + stream.finish()

    def test_batch_markers_bypass_tmux(self):
        image = passthrough(b"\x1b_Ga=T,t=s;shared-memory-name\x1b\\")
        original = BEGIN + image + END
        expected = passthrough(BEGIN) + image + passthrough(END)
        self.assertEqual(self.transform([original]), expected)
        for split in range(len(original) + 1):
            with self.subTest(split=split):
                self.assertEqual(self.transform([original[:split], original[split:]]), expected)
        self.assertEqual(self.transform([bytes([byte]) for byte in original]), expected)

    def test_unrelated_text_and_escape_sequences_are_unchanged(self):
        original = "αβ text\n".encode() + b"\x1b[2J\x1b[?2026$p\x1b[?20260h\x1b[?2026;25h"
        self.assertEqual(self.transform([original]), original)

    def test_control_string_payloads_are_opaque(self):
        for start, stop in [(b"\x1b]", b"\x07"), (b"\x1b]", b"\x1b\\"), (b"\x1b_", b"\x1b\\"), (b"\x1bP", b"\x1b\\")]:
            original = start + b"payload" + BEGIN + END + stop + BEGIN + END
            expected = start + b"payload" + BEGIN + END + stop + passthrough(BEGIN) + passthrough(END)
            with self.subTest(start=start, stop=stop):
                self.assertEqual(self.transform([bytes([byte]) for byte in original]), expected)

    def test_already_wrapped_markers_are_not_wrapped_again(self):
        original = passthrough(BEGIN) + passthrough(END) + BEGIN
        expected = passthrough(BEGIN) + passthrough(END) + passthrough(BEGIN)
        for split in range(len(original) + 1):
            with self.subTest(split=split):
                self.assertEqual(self.transform([original[:split], original[split:]]), expected)

    def test_bell_does_not_end_an_apc_payload(self):
        original = b"\x1b_payload\x07" + BEGIN + b"\x1b\\" + END
        expected = b"\x1b_payload\x07" + BEGIN + b"\x1b\\" + passthrough(END)
        self.assertEqual(self.transform([original]), expected)

    def test_cancelled_control_strings_do_not_hide_markers(self):
        for cancel in [b"\x18", b"\x1a"]:
            self.assertEqual(self.transform([b"\x1bPpayload" + cancel + BEGIN]), b"\x1bPpayload" + cancel + passthrough(BEGIN))

    def test_partial_marker_is_preserved_at_eof(self):
        for length in range(1, len(BEGIN)):
            original = b"text" + BEGIN[:length]
            self.assertEqual(self.transform([original]), original)

    def test_large_payload_does_not_accumulate_in_the_parser(self):
        stream = relay.SyncPassthrough()
        original = b"\x1b_G;" + b"a" * 100000
        self.assertEqual(stream.feed(original), original)
        self.assertEqual(stream.finish(), b"")


class PtyTests(unittest.TestCase):
    def setUp(self):
        self.master, self.slave = os.openpty()
        fcntl.ioctl(self.master, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 640, 480))
        self.original = termios.tcgetattr(self.slave)
        self.output = b""
        self.process = None

    def tearDown(self):
        if self.process is not None and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        os.close(self.master)
        os.close(self.slave)

    def start(self, command):
        self.process = subprocess.Popen(
            [sys.executable, "-B", str(SUBJECT), *command],
            stdin=self.slave, stdout=self.slave, stderr=self.slave,
            env={**os.environ, "TMUX": "test"}, start_new_session=True,
        )

    def read_until(self, expected):
        deadline = time.monotonic() + 5
        while expected not in self.output and time.monotonic() < deadline:
            readable, _, _ = select.select([self.master], [], [], 0.1)
            if readable:
                try:
                    data = os.read(self.master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                self.output += data
        self.assertIn(expected, self.output)

    def assert_restored(self, expected_status):
        self.assertEqual(self.process.wait(timeout=5), expected_status)
        restored, expected = termios.tcgetattr(self.slave), self.original.copy()
        # macOS marks input for reprocessing when canonical mode is restored.
        restored[3] &= ~termios.PENDIN
        expected[3] &= ~termios.PENDIN
        self.assertEqual(restored, expected)

    def test_filters_real_tty_output_and_preserves_exit_status(self):
        self.start([sys.executable, "-c", "import os;os.write(1,b'\\x1b[?2026hHELLO\\x1b[?2026l');raise SystemExit(7)"])
        self.read_until(passthrough(END))
        self.assertIn(passthrough(BEGIN) + b"HELLO" + passthrough(END), self.output)
        self.assert_restored(7)

    def test_exit_closes_an_unfinished_batch(self):
        self.start([sys.executable, "-c", "import os;os.write(1,b'\\x1b[?2026hLAST');raise SystemExit(3)"])
        self.read_until(passthrough(BEGIN) + b"LAST" + passthrough(END))
        self.assert_restored(3)

    def test_child_signal_is_reported_as_a_shell_exit_code(self):
        self.start([sys.executable, "-c", "import os,signal;os.kill(os.getpid(),signal.SIGTERM)"])
        self.assert_restored(128 + signal.SIGTERM)

    def test_input_round_trips_without_becoming_browser_output(self):
        self.start([sys.executable, "-c", "import os,tty;tty.setraw(0);os.write(1,b'READY');data=b''\nwhile len(data)<6: data+=os.read(0,6-len(data))\nos.write(1,b'GOT:'+data.hex().encode())"])
        self.read_until(b"READY")
        os.write(self.master, b"\x1b[A\xc3\xa9!")
        self.read_until(b"GOT:1b5b41c3a921")
        self.assert_restored(0)

    def test_size_and_resize_reach_the_child(self):
        code = """import fcntl,os,signal,termios,tty

def report(*_):
    import struct
    size = struct.unpack('HHHH',fcntl.ioctl(0,termios.TIOCGWINSZ,b'\\0'*8))
    os.write(1,('SIZE:'+','.join(map(str,size))).encode())
tty.setraw(0)
signal.signal(signal.SIGWINCH,report)
report()
os.read(0,1)
"""
        self.start([sys.executable, "-c", code])
        self.read_until(b"SIZE:24,80,640,480")
        fcntl.ioctl(self.master, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 100, 900, 700))
        self.process.send_signal(signal.SIGWINCH)
        self.read_until(b"SIZE:40,100,900,700")
        os.write(self.master, b"x")
        self.assert_restored(0)

    def test_shutdown_forwards_to_child_and_restores_terminal(self):
        code = "import os,signal,time;signal.signal(signal.SIGTERM,lambda *_:exit(0));os.write(1,('PID:'+str(os.getpid())+';').encode());time.sleep(60)"
        self.start([sys.executable, "-c", code])
        self.read_until(b";")
        child_pid = int(self.output.split(b"PID:")[1].split(b";")[0])
        self.process.terminate()
        self.assert_restored(0)
        with self.assertRaises(ProcessLookupError):
            os.kill(child_pid, 0)

    def test_missing_executable_reports_failure_and_restores_terminal(self):
        self.start(["/not/a/real/browser"])
        self.read_until(b"/not/a/real/browser")
        self.assert_restored(127)

    def test_outside_tmux_executes_without_a_relay(self):
        env = {**os.environ}
        env.pop("TMUX", None)
        result = subprocess.run([sys.executable, "-B", str(SUBJECT), sys.executable, "-c", "print('plain');exit(4)"], env=env, capture_output=True)
        self.assertEqual(result.returncode, 4)
        self.assertEqual(result.stdout, b"plain\n")
        self.assertEqual(result.stderr, b"")


if __name__ == "__main__":
    unittest.main()
