"""Exercise native PostgreSQL in a disposable, Unix-socket-only cluster."""

import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prefix", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    work = args.evidence.resolve()
    work.mkdir(parents=True)
    binaries = args.prefix.resolve() / "bin"
    env = {key: value for key, value in os.environ.items() if not key.startswith("PG")}
    passfile = work / "empty.pgpass"
    passfile.touch(mode=0o600)
    env["PGPASSFILE"] = str(passfile)

    def run(name, command):
        with (work / f"{name}.log").open("w") as log:
            subprocess.run(command, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT,
                           timeout=60, check=True)
        return (work / f"{name}.log").read_text()

    data, socket = work / "data", work / "socket"
    socket.mkdir(mode=0o700)
    version = run("version", [str(binaries / "postgres"), "--version"]).strip()
    run("initdb", [str(binaries / "initdb"), "-D", str(data), "--no-locale", "-A", "trust"])
    control = [str(binaries / "pg_ctl"), "-D", str(data)]
    client = [str(binaries / "psql"), "-X", "-w", "-h", str(socket), "-p", "5432", "-v", "ON_ERROR_STOP=1"]
    try:
        run("start", [*control, "-l", str(work / "server.log"), "-o",
                      shlex.join(["-h", "", "-k", str(socket), "-p", "5432"]), "-w", "start"])
        assert run("listen-addresses", [*client, "-d", "postgres", "-Atc", "SHOW listen_addresses;"]).strip() == ""
        run("write", [*client, "-d", "postgres", "-c",
                      "CREATE TABLE probe (value int); INSERT INTO probe VALUES (42);"])
        dump = work / "dump.sql"
        run("dump", [str(binaries / "pg_dump"), "-w", "-h", str(socket), "-p", "5432",
                     "-d", "postgres", "-f", str(dump)])
        run("create-database", [*client, "-d", "postgres", "-c", "CREATE DATABASE restored;"])
        run("restore", [*client, "-d", "restored", "-f", str(dump)])
        value = run("read", [*client, "-d", "restored", "-Atc", "SELECT value FROM probe;"]).strip()
        assert value == "42", f"Restored fixture has unexpected content: {value!r}"
    finally:
        if (data / "postmaster.pid").exists():
            run("stop", [*control, "-m", "fast", "-w", "stop"])
    report = {"version": version, "prefix": str(args.prefix.resolve()), "sql_round_trip": True,
              "dump_restore": True, "tcp_listeners": False, "stopped": not (data / "postmaster.pid").exists()}
    assert report["stopped"]
    (work / "report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
