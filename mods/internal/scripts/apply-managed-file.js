// A fully owned, writable file (e.g. npmrc), including legacy symlink repair.
const { writeConfigFile } = require("./lib/config-file.js");
if (!process.env.TARGET_FILE || process.env.DECLARED_CONTENT === undefined) {
  throw new Error("TARGET_FILE and DECLARED_CONTENT required");
}
writeConfigFile(process.env.TARGET_FILE, process.env.DECLARED_CONTENT);
