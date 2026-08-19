## pi-fabric tool access

Filesystem and shell access in this session may be provided by the
`pi-fabric` plugin (single tool: `fabric_exec`) instead of native
`Read`/`Write`/`Edit`/`Glob`/`Grep`/`Bash`/`Task` tools. If those native
tool names are absent from your tool list, do not conclude you lack
filesystem or shell access — check for `fabric_exec` first.

Equivalents, called as methods on the `pi` object inside executed
TypeScript (not separate top-level tools — they will not appear in
`Object.keys(pi)` or any reflection):

- `pi.read`, `pi.write`, `pi.edit` — file read/write/edit
- `pi.glob`, `pi.find`, `pi.ls` — file discovery
- `pi.grep` — content search
- `pi.bash` — shell commands
- `pi.task` / `pi.spawnAgent` — subagent spawning

Load the `fabric-exec` skill for the full API if an unfamiliar argument
shape or error is encountered.
