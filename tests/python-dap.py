"""Launch a dependency-free project venv through the native debugpy adapter."""

import argparse
import json
import os
from pathlib import Path
import signal
import subprocess

from dap_client import DapClient


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--python", required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    args.evidence = args.evidence.resolve()
    args.evidence.mkdir(parents=True)
    project = args.evidence / "project venv"
    subprocess.run([args.python, "-m", "venv", "--without-pip", str(project)], check=True)
    python = project / "bin/python"
    subprocess.run([
        str(python), "-c",
        "import importlib.util; assert importlib.util.find_spec('debugpy') is None",
    ], check=True)
    result = args.evidence / "debuggee.json"
    program = args.evidence / "main.py"
    program.write_text(
        "import json, sys\nfrom pathlib import Path\n"
        f"Path({str(result)!r}).write_text(json.dumps({{'prefix': sys.prefix}}))\n"
    )
    with (args.evidence / "adapter.stderr").open("wb") as stderr:
        process = subprocess.Popen(
            [args.adapter], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=stderr, start_new_session=True,
        )
        client = DapClient(process.stdout, process.stdin)

        try:
            client.response(client.send("initialize", {"adapterID": "python", "linesStartAt1": True}))
            launch = client.send("launch", {
                "name": "native adapter probe", "type": "python", "request": "launch",
                "program": str(program), "pythonPath": str(python),
                "console": "internalConsole", "justMyCode": False,
            })
            client.receive(lambda item: item.get("event") == "initialized")
            client.response(client.send("configurationDone", {}))
            client.response(launch)
            client.receive(lambda item: item.get("event") == "terminated")
            assert json.loads(result.read_text())["prefix"] == str(project)
            client.response(client.send("disconnect", {}))
            print("Native Python DAP initialized, launched the isolated project interpreter and terminated")
        finally:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)


if __name__ == "__main__":
    main()
