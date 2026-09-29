## Coding Preferences

- Do not add an abstraction speculatively. Add a layer only when it removes
  duplication that already exists.
- Never discard work you did not write. No git checkout, reset, restore,
  clean, stash, or file deletion touching uncommitted changes without
  explicit approval.
- Run the smallest useful verification before calling work complete.
- Fix type and lint errors rather than silencing them. If a suppression is
  genuinely required, name the exact rule and give a one-line reason.
- Comments explain why the code is as it is. Never describe the change itself,
  the previous behavior, or when something was added.
- Never write a comment that restates what the code does. Comment only what
  the code cannot show: a constraint, an upstream bug, an ordering that looks
  arbitrary, a line someone would otherwise simplify and break.
- Keep comments to one or two lines. Anything longer, including alternatives
  considered and benchmark figures, belongs in the PR description or a doc.

