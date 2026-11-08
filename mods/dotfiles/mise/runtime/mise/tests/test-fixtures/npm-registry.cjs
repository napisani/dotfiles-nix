const fs = require("node:fs");
const path = require("node:path");
const http = require("node:http");
const { execFileSync } = require("node:child_process");
const root = process.argv[2];
const versions = {};
for (const version of ["1.0.0", "2.0.0"]) {
  const dir = path.join(root, version);
  const pkg = path.join(dir, "package");
  fs.mkdirSync(pkg, { recursive: true });
  const manifest = {
    name: "fixture-tool",
    version,
    bin: { "fixture-tool": "cli.js" },
    scripts: {
      postinstall:
        "node -e \"require('node:fs').writeFileSync('installed.ok','ok')\"",
    },
  };
  fs.writeFileSync(path.join(pkg, "package.json"), JSON.stringify(manifest));
  fs.writeFileSync(
    path.join(pkg, "cli.js"),
    "#!" + process.execPath +
      '\nconsole.log(JSON.stringify({version:require("./package.json").version,cwd:process.cwd(),args:process.argv.slice(2),postinstall:require("node:fs").existsSync(__dirname+"/installed.ok")}));\n',
  );
  execFileSync("tar", [
    "-czf",
    path.join(root, version + ".tgz"),
    "-C",
    dir,
    "package",
  ]);
  versions[version] = { ...manifest, hasInstallScript: true };
}
const server = http.createServer((req, res) => {
  const archive = req.url.match(/^\/(1\.0\.0|2\.0\.0)\.tgz$/);
  if (archive) {
    res.end(fs.readFileSync(path.join(root, archive[1] + ".tgz")));
    return;
  }
  if (req.url !== "/fixture-tool") {
    res.writeHead(404);
    res.end();
    return;
  }
  const port = server.address().port;
  res.setHeader("content-type", "application/json");
  res.end(JSON.stringify({
    name: "fixture-tool",
    "dist-tags": { latest: "2.0.0" },
    versions: Object.fromEntries(
      Object.entries(versions).map(([version, manifest]) => [version, {
        ...manifest,
        dist: { tarball: "http://127.0.0.1:" + port + "/" + version + ".tgz" },
      }]),
    ),
  }));
});
server.listen(
  0,
  "127.0.0.1",
  () => process.send({ port: server.address().port }),
);
