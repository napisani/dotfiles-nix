"""Initialize Node and Chrome sessions using Neovim's resolved native adapter."""

import argparse
import json
import os
from pathlib import Path
import queue
import re
import signal
import socket
import subprocess
import threading

from dap_client import DapClient


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--node", required=True)
    parser.add_argument("--adapter", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    args.evidence.mkdir(parents=True)
    adapter = json.loads(args.adapter.read_text())
    command = [args.node, *[arg.replace("${port}", "0") for arg in adapter["executable"]["args"]]]
    with (args.evidence / "adapter.stderr").open("w") as stderr:
        process = subprocess.Popen(
            command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=stderr, text=True, start_new_session=True,
        )
        try:
            lines = queue.Queue()
            threading.Thread(target=lambda: lines.put(process.stdout.readline()), daemon=True).start()
            line = lines.get(timeout=15)
            (args.evidence / "adapter.stdout").write_text(line)
            match = re.search(r"listening at 127\.0\.0\.1:(\d+)", line)
            assert match, f"Unexpected adapter startup: {line!r}"
            for name in ["pwa-node", "pwa-chrome"]:
                with socket.create_connection(("127.0.0.1", int(match[1])), timeout=10) as connection:
                    connection.settimeout(None)
                    reader, writer = connection.makefile("rb"), connection.makefile("wb")
                    try:
                        client = DapClient(reader, writer)
                        initialized = client.response(client.send("initialize", {
                            "clientID": "neovim", "adapterID": name,
                            "linesStartAt1": True, "columnsStartAt1": True,
                        }))
                        assert initialized["body"]["supportsConfigurationDoneRequest"]
                        (args.evidence / f"{name}.json").write_text(json.dumps(initialized, indent=2))
                    finally:
                        # The peer can close while the probe is releasing its streams.
                        try:
                            connection.shutdown(socket.SHUT_RDWR)
                        except OSError:
                            pass
                        reader.close()
                        writer.close()
            print("Native Node and Chrome DAP initialize handshakes passed")
        finally:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)


if __name__ == "__main__":
    main()
