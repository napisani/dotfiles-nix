"""Build, stop and continue a native Go debuggee through Delve's TCP adapter."""

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
    parser.add_argument("--go", required=True)
    parser.add_argument("--dlv", required=True)
    parser.add_argument("--adapter", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    work = args.evidence.resolve()
    work.mkdir(parents=True)
    (work / "go.mod").write_text("module example.test/dap\n\ngo 1.26.0\n")
    (work / "main.go").write_text(
        'package main\nimport "os"\n'
        'func main() { if err := os.WriteFile(os.Args[1], []byte("continued"), 0600); err != nil { panic(err) } }\n'
    )
    binary, result = work / "debuggee", work / "result"
    with (work / "build.log").open("w") as log:
        subprocess.run(
            [args.go, "build", "-gcflags=all=-N -l", "-o", str(binary), "."],
            cwd=work, env={**os.environ, "GOTOOLCHAIN": "local", "CGO_ENABLED": "0"},
            stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180,
        )
    adapter = json.loads(args.adapter.read_text())
    command = [args.dlv, *[arg.replace("${port}", "0") for arg in adapter["executable"]["args"]]]
    with (work / "adapter.stderr").open("w") as stderr:
        process = subprocess.Popen(
            command, stdout=subprocess.PIPE, stderr=stderr, text=True, start_new_session=True,
        )
        completed = False
        try:
            lines = queue.Queue()
            threading.Thread(target=lambda: lines.put(process.stdout.readline()), daemon=True).start()
            line = lines.get(timeout=15)
            (work / "adapter.stdout").write_text(line)
            match = re.search(r"DAP server listening at: 127\.0\.0\.1:(\d+)", line)
            assert match, f"Unexpected Delve startup: {line!r}"
            with socket.create_connection(("127.0.0.1", int(match[1])), timeout=10) as connection:
                connection.settimeout(None)
                reader, writer = connection.makefile("rb"), connection.makefile("wb")
                try:
                    client = DapClient(reader, writer)
                    client.response(client.send("initialize", {"adapterID": "go", "linesStartAt1": True}))
                    launch = client.send("launch", {
                        "name": "native Go probe", "type": "go", "request": "launch",
                        "mode": "exec", "program": str(binary), "cwd": str(work),
                        "args": [str(result)], "stopOnEntry": True,
                    })
                    client.response(launch)
                    client.receive(lambda item: item.get("event") == "initialized")
                    client.response(client.send("configurationDone", {}))
                    stopped = client.receive(lambda item: item.get("event") == "stopped")
                    assert not result.exists(), "debuggee ran before the debugger continued it"
                    client.response(client.send("continue", {"threadId": stopped["body"]["threadId"]}))
                    client.receive(lambda item: item.get("event") == "terminated")
                    assert result.read_text() == "continued"
                    client.response(client.send("disconnect", {}))
                    (work / "stopped.json").write_text(json.dumps(stopped, indent=2))
                    completed = True
                    print("Native Go DAP launched, stopped, continued and terminated the debuggee")
                finally:
                    # The peer may close its socket after disconnect.
                    try:
                        connection.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass
                    reader.close()
                    writer.close()
        finally:
            # After disconnect, Delve owns debugserver cleanup; wait for its normal exit.
            if not completed and process.poll() is None:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            process.wait(timeout=5)


if __name__ == "__main__":
    main()
