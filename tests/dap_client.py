"""Bounded DAP framing for native adapter acceptance probes."""

import json
import queue
import threading
import time


class DapClient:
    def __init__(self, reader, writer):
        self.reader = reader
        self.writer = writer
        self.messages = queue.Queue()
        self.pending = []
        self.sequence = 0
        self.deadline = time.monotonic() + 60
        threading.Thread(target=self.read_messages, daemon=True).start()

    def read_messages(self):
        try:
            while True:
                headers = {}
                while True:
                    line = self.reader.readline()
                    if not line:
                        raise EOFError("adapter closed transport")
                    if line == b"\r\n":
                        break
                    key, value = line.decode().split(":", 1)
                    headers[key.lower()] = value.strip()
                self.messages.put(json.loads(self.reader.read(int(headers["content-length"]))))
        except Exception as error:
            self.messages.put(error)

    def send(self, command, arguments):
        self.sequence += 1
        body = json.dumps({
            "seq": self.sequence, "type": "request", "command": command,
            "arguments": arguments,
        }).encode()
        self.writer.write(f"Content-Length: {len(body)}\r\n\r\n".encode() + body)
        self.writer.flush()
        return self.sequence

    def receive(self, predicate):
        while True:
            for index, message in enumerate(self.pending):
                if predicate(message):
                    return self.pending.pop(index)
            message = self.messages.get(timeout=max(0, self.deadline - time.monotonic()))
            if isinstance(message, Exception):
                raise message
            self.pending.append(message)

    def response(self, sequence):
        message = self.receive(lambda item: item.get("request_seq") == sequence)
        assert message["success"], message
        return message
