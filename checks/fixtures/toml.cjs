// Node has no TOML parser; reuse the runtime's vendored @std/toml through Deno.
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const config = path.resolve(__dirname, "../../mods/dotfiles/mise/runtime/deno.json");

function convert(operation, input) {
  const program = `import * as toml from "@std/toml";
const input = await new Response(Deno.stdin.readable).text();
console.log(${operation === "parse" ? "JSON.stringify(toml.parse(input))" : "toml.stringify(JSON.parse(input))"});`;
  return execFileSync("deno", ["eval", "--frozen", "--cached-only", "--config", config, program], {
    input, encoding: "utf8",
  });
}

module.exports = {
  parse: (text) => JSON.parse(convert("parse", text)),
  stringify: (value) => convert("stringify", JSON.stringify(value)),
};
