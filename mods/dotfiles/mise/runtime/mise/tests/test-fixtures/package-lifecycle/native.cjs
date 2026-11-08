const fs = require("node:fs");

const action = process.argv[2];
const request = JSON.parse(process.env.FIXTURE_REQUEST);
const file = process.env.FIXTURE_NATIVE_STATE;
const installed = fs.existsSync(file)
  ? JSON.parse(fs.readFileSync(file, "utf8"))
  : {};
fs.appendFileSync(
  process.env.FIXTURE_CALL_LOG,
  JSON.stringify({ action, request }) + "\n",
);
if (action === process.env.FIXTURE_FAIL_ACTION) {
  throw new Error(`fixture ${action} failed`);
}
if (action === "status") {
  const packages = request.map(({ name }) =>
    Object.hasOwn(installed, name)
      ? { name, state: "installed", version: installed[name] }
      : { name, state: "missing" }
  );
  process.stdout.write(JSON.stringify({ packages }));
} else {
  if (!["install", "upgrade", "uninstall"].includes(action)) {
    throw new Error("unknown fixture action");
  }
  if (action === "install" && process.env.FIXTURE_INSTALL_READY) {
    const ready = process.env.FIXTURE_INSTALL_READY;
    const release = process.env.FIXTURE_INSTALL_RELEASE;
    if (fs.existsSync(ready) && !fs.existsSync(release)) {
      fs.writeFileSync(process.env.FIXTURE_INSTALL_OVERLAP, "overlap\n");
      throw new Error("concurrent native installation");
    }
    fs.writeFileSync(ready, "ready\n");
    const deadline = Date.now() + 10_000;
    while (!fs.existsSync(release)) {
      if (Date.now() > deadline) throw new Error("fixture release timed out");
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 10);
    }
  }
  for (const { name, version } of request) {
    if (action === "uninstall") delete installed[name];
    else {installed[name] = version ||
        (action === "upgrade" ? "2.0.0" : "1.0.0");}
    fs.writeFileSync(file, JSON.stringify(installed) + "\n");
    if (name === process.env.FIXTURE_FAIL_AFTER) {
      throw new Error(`fixture failed after ${name}`);
    }
    if (action === "install" && process.env.FIXTURE_AFTER_INSTALL_READY) {
      fs.writeFileSync(process.env.FIXTURE_AFTER_INSTALL_READY, "installed\n");
      const deadline = Date.now() + 10_000;
      while (!fs.existsSync(process.env.FIXTURE_AFTER_INSTALL_RELEASE)) {
        if (Date.now() > deadline) {
          throw new Error("fixture post-install release timed out");
        }
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 10);
      }
    }
  }
}
