const path = require("node:path");
const { spawnSync } = require("node:child_process");

const mise = process.env.MISE_TEST_BINARY ||
  spawnSync("/bin/sh", ["-c", "command -v mise"], {
    encoding: "utf8",
  }).stdout.trim();

function environment(root) {
  return {
    HOME: path.join(root, "home"),
    PATH: `${path.dirname(process.execPath)}:${
      process.env.TEST_TOOL_PATH || "/usr/bin:/bin"
    }`,
    XDG_CONFIG_HOME: path.join(root, "config"),
    XDG_DATA_HOME: path.join(root, "data"),
    XDG_STATE_HOME: path.join(root, "state"),
    XDG_CACHE_HOME: path.join(root, "cache"),
    MISE_CONFIG_DIR: path.join(root, "config/mise"),
    MISE_SYSTEM_CONFIG_DIR: path.join(root, "system"),
    MISE_GLOBAL_CONFIG_FILE: path.join(root, "config/mise/config.toml"),
    MISE_DATA_DIR: path.join(root, "data/mise"),
    MISE_STATE_DIR: path.join(root, "state/mise"),
    MISE_CACHE_DIR: path.join(root, "cache/mise"),
    // Cache housekeeping is independent of the package-state mutations under test.
    MISE_CACHE_PRUNE_AGE: "0s",
    MISE_TRUSTED_CONFIG_PATHS: root,
    MISE_ENV_CACHE: "0",
    MISE_YES: "1",
    NO_COLOR: "1",
    FIXTURE_NODE: process.execPath,
    FIXTURE_CLI: path.join(__dirname, "package-lifecycle/native.cjs"),
    FIXTURE_NATIVE_STATE: path.join(root, "native.json"),
    FIXTURE_CALL_LOG: path.join(root, "calls.jsonl"),
  };
}

module.exports = { environment, mise };
