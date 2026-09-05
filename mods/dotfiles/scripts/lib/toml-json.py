"""Decode local tool/project metadata without bootstrapping pip dependencies."""
import json
import sys
import tomllib

with open(sys.argv[1], "rb") as source:
    print(json.dumps(tomllib.load(source)))
