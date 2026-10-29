#!/usr/bin/env python3
"""Check extended-key routing and multiline paste on an isolated tmux server."""

import fcntl
import os
import pty
import re
import select
import shlex
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time
import tty
from pathlib import Path


def record_input(directory):
    root = Path(directory)
    tty.setraw(0)
    state = None
    with (root / "input").open("ab", buffering=0) as capture:
        while True:
            request = (root / "mode").read_text()
            if request != state:
                mode = int(request)
                os.write(1, f"\033[>4;{mode}m\033[?2004h".encode())
                state = request
                (root / "ready").write_text(request)
            if select.select([0], [], [], 0.01)[0]:
                data = os.read(0, 65536)
                if not data:
                    return
                capture.write(data)


def wait_for(predicate, description, seconds=5):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if predicate():
            return
        time.sleep(0.01)
    raise AssertionError(f"Timed out: {description}")


def check_keys():
    dotfiles = Path(__file__).resolve().parents[2]
    config = dotfiles / ".tmux.conf"
    terminal = dotfiles / "kitty.conf"
    tmux_binary = shutil.which("tmux")
    assert tmux_binary, "tmux is required"
    script = Path(__file__).resolve()
    with tempfile.TemporaryDirectory(prefix="tmux-key-test-") as directory:
        root = Path(directory)
        socket = root / "server"
        test_config = root / "tmux.conf"
        # Do not execute TPM plugins or status commands from the user's server.
        commands = [
            line
            for line in config.read_text().splitlines()
            if re.match(r"set-option -[sg] extended-keys(?:-format)? ", line)
            or re.match(r"bind-key -n .* send-keys -H ", line)
        ]
        assert commands, "No extended-key configuration found"
        test_config.write_text(
            "set -g status off\nset -s escape-time 10\n" + "\n".join(commands) + "\n"
        )
        env = dict(os.environ, TERM="xterm-256color")
        env.pop("TMUX", None)

        def tmux(*args):
            return subprocess.check_output(
                [tmux_binary, "-S", str(socket), *args],
                env=env,
                stderr=subprocess.STDOUT,
                text=True,
            ).strip()

        def recorder(name):
            path = root / name
            path.mkdir()
            (path / "mode").write_text("0")
            (path / "input").touch()
            command = shlex.join([sys.executable, str(script), "--record", str(path)])
            return path, command

        first, first_command = recorder("first")
        second, second_command = recorder("second")
        master = None
        client_pid = None
        try:
            pane = tmux(
                "-f",
                str(test_config),
                "new-session",
                "-d",
                "-P",
                "-F",
                "#{pane_id}",
                "-s",
                "keys",
                "-x",
                "120",
                "-y",
                "40",
                first_command,
            )
            other = tmux(
                "split-window",
                "-d",
                "-P",
                "-F",
                "#{pane_id}",
                "-t",
                pane,
                second_command,
            )
            client_pid, master = pty.fork()
            if client_pid == 0:
                os.execve(
                    tmux_binary,
                    [tmux_binary, "-S", str(socket), "attach-session", "-t", "keys"],
                    env,
                )
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))

            def drain():
                while select.select([master], [], [], 0)[0]:
                    os.read(master, 65536)

            wait_for(lambda: bool(tmux("list-clients")), "attached test client")
            wait_for(
                lambda: (first / "ready").exists() and (second / "ready").exists(),
                "raw input recorders",
            )

            def mode(target, path, value):
                request = path / "mode.next"
                request.write_text(str(value))
                request.replace(path / "mode")
                wait_for(
                    lambda: (path / "ready").read_text() == str(value),
                    "application keyboard request",
                )
                expected = {0: "VT10x", 1: "Ext 1", 2: "Ext 2"}[value]
                try:
                    wait_for(
                        lambda: (
                            tmux(
                                "display-message",
                                "-p",
                                "-t",
                                target,
                                "#{pane_key_mode}",
                            )
                            == expected
                        ),
                        f"pane key mode {expected}",
                    )
                except AssertionError as error:
                    actual = tmux(
                        "display-message", "-p", "-t", target, "#{pane_key_mode}"
                    )
                    raise AssertionError(f"{error}; actual={actual!r}") from error
                tmux("select-pane", "-t", target)
                drain()

            def expect_input(path, incoming, expected, label):
                capture = path / "input"
                offset = capture.stat().st_size
                os.write(master, incoming)
                wait_for(lambda: capture.stat().st_size > offset, label)
                time.sleep(0.03)
                actual = capture.read_bytes()[offset:]
                assert actual == expected, (
                    f"{label}: expected {expected!r}, got {actual!r}"
                )
                drain()

            # kitty's literal key mappings are the outer-terminal input contract.
            keys = {}
            for line in terminal.read_text().splitlines():
                mapping = re.match(r"map\s+(\S+)\s+send_text\s+all\s+(\S+)$", line)
                if mapping:
                    keys[mapping[1]] = (
                        mapping[2].encode().decode("unicode_escape").encode("latin-1")
                    )
            shift_enter = keys["shift+enter"]
            mode(pane, first, 0)
            expect_input(
                first, shift_enter, b"\r", "standard pane receives legacy Enter"
            )
            assert tmux("show-options", "-sv", "extended-keys") == "on", (
                "Use application opt-in, not always"
            )
            print("PASS: standard panes retain legacy keys", flush=True)

            for value in (1, 2):
                mode(pane, first, value)
                for combo, expected in (
                    ("shift+enter", b"\x1b[13;2u"),
                    ("ctrl+enter", b"\x1b[13;5u"),
                    ("ctrl+shift+enter", b"\x1b[13;6u"),
                    ("ctrl+shift+p", b"\x10" if value == 1 else b"\x1b[80;6u"),
                ):
                    expect_input(
                        first,
                        keys[combo],
                        expected,
                        f"mode {value}: {combo}",
                    )
                paste = b"\x1b[200~foo\n" + "β🧪".encode() + b"\nbar\x1b[201~"
                expect_input(
                    first, paste, paste, f"mode {value}: bracketed Unicode paste"
                )
                print(
                    f"PASS: mode {value} modified keys and byte-exact multiline paste",
                    flush=True,
                )

            mode(other, second, 2)
            mode(pane, first, 0)
            expect_input(
                first,
                shift_enter,
                b"\r",
                "other pane's mode 2 does not affect standard pane",
            )
            paste = b"\x1b[200~one\ntwo\x1b[201~"
            expect_input(
                first,
                paste,
                paste,
                "standard pane paste while another pane uses mode 2",
            )
            print("PASS: application keyboard modes are isolated per pane", flush=True)

            bash = None
            for candidate in (
                os.environ.get("SHELL"),
                shutil.which("bash"),
                "/bin/bash",
            ):
                if candidate and Path(candidate).name == "bash":
                    result = subprocess.run(
                        [candidate, "-c", "type -t bind"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        check=False,
                    )
                    if result.returncode == 0:
                        bash = candidate
                        break
            assert bash, "Bash with Readline is required"
            rcfile = root / "bashrc"
            rcfile.write_text(
                "PS1='READLINE_READY> '\nHISTFILE=/dev/null\nbind 'set editing-mode vi'\nbind 'set enable-bracketed-paste on'\n"
            )
            shell = tmux(
                "split-window",
                "-d",
                "-P",
                "-F",
                "#{pane_id}",
                "-t",
                pane,
                shlex.join([bash, "--noprofile", "--rcfile", str(rcfile), "-i"]),
            )
            tmux("select-pane", "-t", shell)
            wait_for(
                lambda: (
                    "READLINE_READY>" in tmux("capture-pane", "-p", "-t", shell)
                    and tmux(
                        "display-message", "-p", "-t", shell, "#{bracket_paste_flag}"
                    )
                    == "1"
                ),
                "Readline bracketed-paste prompt",
            )
            output = root / "accepted"
            command = f"printf '%s\\n' \\\n 'one' \\\n 'two' > {shlex.quote(str(output))}".encode()
            os.write(master, b"\x1b[200~" + command + b"\x1b[201~")
            time.sleep(0.2)
            assert not output.exists(), "Readline executed a paste before Enter"
            assert "106;5u" not in tmux("capture-pane", "-p", "-t", shell), (
                "LF became CSI-u text"
            )
            os.write(master, b"\r")
            wait_for(
                lambda: output.exists() and output.read_bytes() == b"one\ntwo\n",
                "deliberate Enter accepts the intact multiline command",
            )
            print(
                "PASS: Readline retains multiline paste until Enter, with another pane in mode 2",
                flush=True,
            )

            nvim = shutil.which("nvim")
            if nvim:
                events = root / "nvim-events"
                init = root / "init.vim"
                init.write_text(
                    "set nomore\n"
                    + "\n".join(
                        f"nnoremap {key} <Cmd>call writefile(['{name}'], '{events}', 'a')<CR>"
                        for key, name in (
                            ("<S-CR>", "shift-enter"),
                            ("<C-CR>", "ctrl-enter"),
                            ("<C-S-P>", "ctrl-shift-p"),
                        )
                    )
                    + "\n"
                )
                editor = tmux(
                    "new-window",
                    "-P",
                    "-F",
                    "#{pane_id}",
                    "-t",
                    "keys",
                    "-n",
                    "nvim",
                    shlex.join([nvim, "--clean", "-u", str(init), "-i", "NONE", "-n"]),
                )
                wait_for(
                    lambda: (
                        drain()
                        or tmux(
                            "display-message", "-p", "-t", editor, "#{pane_key_mode}"
                        )
                        == "Ext 2"
                    ),
                    "Neovim requests extended-key mode 2",
                )
                for combo in ("shift+enter", "ctrl+enter", "ctrl+shift+p"):
                    os.write(master, keys[combo])
                    time.sleep(0.05)
                    drain()
                wait_for(
                    lambda: (
                        events.exists() and len(events.read_text().splitlines()) == 3
                    ),
                    "Neovim receives distinct modified keys",
                )
                assert events.read_text().splitlines() == [
                    "shift-enter",
                    "ctrl-enter",
                    "ctrl-shift-p",
                ]
                print(
                    "PASS: installed Neovim negotiates mode 2 and recognizes modified Enter and Ctrl-Shift-P",
                    flush=True,
                )
            else:
                print("SKIP: Neovim integration (nvim is not installed)", flush=True)
        finally:
            subprocess.run(
                [tmux_binary, "-S", str(socket), "kill-server"],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if client_pid:
                os.kill(client_pid, signal.SIGKILL)
                os.waitpid(client_pid, 0)
            if master is not None:
                os.close(master)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--record":
        record_input(sys.argv[2])
    else:
        check_keys()
