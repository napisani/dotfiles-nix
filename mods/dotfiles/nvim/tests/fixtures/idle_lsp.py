import json
import os
import sys
import time


def respond(request_id, result):
    body = json.dumps({"jsonrpc": "2.0", "id": request_id, "result": result}).encode()
    sys.stdout.buffer.write(f"Content-Length: {len(body)}\r\n\r\n".encode() + body)
    sys.stdout.buffer.flush()


documents = {}
while True:
    headers = {}
    for line in sys.stdin.buffer:
        if line == b"\r\n":
            break
        key, value = line.decode().split(":", 1)
        headers[key.lower()] = value.strip()
    if not headers:
        break
    message = json.loads(sys.stdin.buffer.read(int(headers["content-length"])))
    method = message.get("method")
    params = message.get("params", {})
    if method == "initialize":
        if len(sys.argv) > 1 and sys.argv[1] == "fail":
            sys.exit(7)
        if len(sys.argv) > 2:
            time.sleep(float(sys.argv[2]))
        respond(
            message["id"],
            {
                "capabilities": {
                    "textDocumentSync": 1,
                    "definitionProvider": True,
                    "declarationProvider": True,
                    "typeDefinitionProvider": True,
                    "implementationProvider": True,
                    "referencesProvider": True,
                    "hoverProvider": True,
                    "completionProvider": {},
                }
            },
        )
    elif method == "shutdown":
        if len(sys.argv) > 1 and sys.argv[1] == "hang":
            continue
        respond(message["id"], None)
    elif method == "exit":
        break
    elif method == "textDocument/didOpen":
        document = params["textDocument"]
        documents[document["uri"]] = document["text"]
    elif method == "textDocument/didChange":
        documents[params["textDocument"]["uri"]] = params["contentChanges"][-1]["text"]
    elif method in {
        "textDocument/definition",
        "textDocument/declaration",
        "textDocument/typeDefinition",
        "textDocument/implementation",
        "textDocument/references",
    }:
        location = {
            "uri": params["textDocument"]["uri"],
            "range": {
                "start": {"line": 0, "character": 0},
                "end": {"line": 0, "character": 1},
            },
        }
        respond(message["id"], [location])
    elif method == "textDocument/hover":
        respond(
            message["id"],
            {"contents": {"kind": "plaintext", "value": "fixture symbol"}},
        )
    elif method == "textDocument/completion":
        respond(message["id"], [{"label": "fixture_completion"}])
    elif method == "test/state":
        respond(message["id"], {"pid": os.getpid(), "documents": documents})
