// Shared writable-config seam: compare the projected bytes, then either
// report drift without writing or atomically apply. No ownership ledger here.
const fs = require("node:fs");
const { atomicWriteFileSync } = require("./managed-state.js");
function writeConfigFile(file, content) {
  const mode = process.env.RECONCILE_MODE || "apply";
  if (!["apply", "status"].includes(mode)) {
    throw new Error(`invalid config mode: ${mode}`);
  }
  if (
    fs.existsSync(file) && !fs.lstatSync(file).isSymbolicLink() &&
    fs.readFileSync(file, "utf8") === content
  ) return false;
  if (mode === "status") {
    console.log(`config: drift at ${file}`);
    process.exitCode = 1;
    return false;
  }
  atomicWriteFileSync(file, content);
  return true;
}
module.exports = { writeConfigFile };
