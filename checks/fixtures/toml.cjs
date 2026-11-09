// Node has no TOML parser; reuse the writer runtime's locked Python TOML packages.
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const runtime = path.resolve(__dirname, "../../mods/dotfiles/mise/runtime");

function convert(operation, input) {
  const program = `import json, sys, tomllib, tomli_w
text = sys.stdin.read()
sys.stdout.write(${operation === "parse" ? "json.dumps(tomllib.loads(text))" : "tomli_w.dumps(json.loads(text))"})`;
  return execFileSync("uv", ["run", "--locked", "--project", runtime, "python", "-c", program], {
    input, encoding: "utf8",
  });
}

module.exports = {
  parse: (text) => JSON.parse(convert("parse", text)),
  stringify: (value) => convert("stringify", JSON.stringify(value)),
};
