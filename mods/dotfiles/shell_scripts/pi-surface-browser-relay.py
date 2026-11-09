#!/usr/bin/env python3
import errno
import fcntl
import os
import pty
import re
import select
import signal
import sys
import termios
import tty


BEGIN = b"\x1b[?2026h"
END = b"\x1b[?2026l"
STRING_CONTROL = re.compile(rb"\x1b[\s\S]|[\x07\x18\x1a]")


def passthrough(data):
    return b"\x1bPtmux;" + data.replace(b"\x1b", b"\x1b\x1b") + b"\x1b\\"


class SyncPassthrough:
    def __init__(self):
        self.pending = b""
        self.string_type = None
        self.sync_active = False

    def feed(self, data):
        data = self.pending + data
        self.pending = b""
        output = bytearray()
        position = 0
        while position < len(data):
            if self.string_type is not None:
                control = STRING_CONTROL.search(data, position)
                if control is None:
                    end = len(data) - int(data.endswith(b"\x1b"))
                    output.extend(data[position:end])
                    position = end
                    break
                output.extend(data[position:control.end()])
                token = control.group()
                if token in (b"\x1b\\", b"\x18", b"\x1a") or (token == b"\x07" and self.string_type == ord("]")):
                    self.string_type = None
                position = control.end()
                continue

            escape = data.find(b"\x1b", position)
            if escape < 0:
                output.extend(data[position:])
                position = len(data)
                break
            output.extend(data[position:escape])
            position = escape
            remaining = data[position:]
            if remaining.startswith(BEGIN) or remaining.startswith(END):
                marker = remaining[:len(BEGIN)]
                # tmux consumes these markers and redraws the placeholder grid.
                # Kitty must receive them directly, like the image commands.
                output.extend(passthrough(marker))
                self.sync_active = marker == BEGIN
                position += len(marker)
            elif BEGIN.startswith(remaining) or END.startswith(remaining):
                break
            else:
                if data[position + 1] in b"P]_X^":
                    self.string_type = data[position + 1]
                output.extend(data[position:position + 2])
                position += 2
        self.pending = data[position:]
        return bytes(output)

    def finish(self):
        data, self.pending = self.pending, b""
        return data


def write_all(fd, data):
    while data:
        data = data[os.write(fd, data):]


def run(command):
    original = termios.tcgetattr(0)
    size = fcntl.ioctl(0, termios.TIOCGWINSZ, b"\0" * 8)
    child, master = pty.fork()
    if child == 0:
        try:
            fcntl.ioctl(0, termios.TIOCSWINSZ, size)
            os.environ["PIXEL_TTY"] = os.ttyname(0)
            os.execvp(command[0], command)
        except OSError as error:
            os.write(2, f"pi-surface browser relay: {command[0]}: {error}\n".encode())
            os._exit(127 if error.errno == errno.ENOENT else 126)

    def resize(_signal, _frame):
        fcntl.ioctl(master, termios.TIOCSWINSZ, fcntl.ioctl(0, termios.TIOCGWINSZ, b"\0" * 8))

    def forward_signal(number, _frame):
        try:
            os.kill(child, number)
        except ProcessLookupError:
            pass

    handlers = {number: signal.getsignal(number) for number in (signal.SIGWINCH, signal.SIGHUP, signal.SIGTERM, signal.SIGINT)}
    stream = SyncPassthrough()
    try:
        signal.signal(signal.SIGWINCH, resize)
        for number in (signal.SIGHUP, signal.SIGTERM, signal.SIGINT):
            signal.signal(number, forward_signal)
        tty.setraw(0)
        while True:
            ready, _, _ = select.select([0, master], [], [])
            if master in ready:
                try:
                    data = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not data:
                    break
                write_all(1, stream.feed(data))
            if 0 in ready:
                data = os.read(0, 65536)
                if not data:
                    break
                write_all(master, data)
        write_all(1, stream.finish())
    finally:
        try:
            if stream.sync_active:
                write_all(1, passthrough(END))
        finally:
            for number, handler in handlers.items():
                signal.signal(number, handler)
            termios.tcsetattr(0, termios.TCSADRAIN, original)
            reaped, status = os.waitpid(child, os.WNOHANG)
            if not reaped:
                forward_signal(signal.SIGHUP, None)
                _, status = os.waitpid(child, 0)
            os.close(master)
    exit_code = os.waitstatus_to_exitcode(status)
    return exit_code if exit_code >= 0 else 128 - exit_code


def main():
    if len(sys.argv) < 2:
        print("usage: pi-surface-browser-relay.py <command> [args...]", file=sys.stderr)
        return 2
    if not os.environ.get("TMUX"):
        os.execvp(sys.argv[1], sys.argv[1:])
    if not os.isatty(0) or not os.isatty(1):
        print("pi-surface browser relay: a terminal is required inside tmux", file=sys.stderr)
        return 2
    return run(sys.argv[1:])


if __name__ == "__main__":
    sys.exit(main())
