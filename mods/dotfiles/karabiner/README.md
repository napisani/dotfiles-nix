# Karabiner Configuration

This directory contains the TypeScript source files for generating Karabiner-Elements configuration.

## Workflow

### 1. Edit TypeScript source files
Modify keyboard mappings in `src/` directory

### 2. Generate karabiner.json
```bash
cd "$(sh_dotfiles_dir)/mods/dotfiles/karabiner"
deno task build
```

The build writes `../karabiner.json` and regenerates `../look-sources/window-management.toml`
from the shared window action catalog. Commit both. Reload Look with `Cmd+Shift+;` afterwards.

### 3. Reload Karabiner to apply changes
```bash
karabiner-reload.sh
```

Alternatively, use the full app restart method:
```bash
osascript -e 'quit app "Karabiner-Elements"' && sleep 1 && open -a 'Karabiner-Elements'
```

## How it Works

- mise's `[dotfiles]` table links `~/.config/karabiner/karabiner.json` to the generated
  `mods/dotfiles/karabiner.json` through `~/.config/mise/dotfiles`, so a rebuild takes effect
  without re-applying anything.
- Generation only writes beside its source; it never replaces the deployed link.

## Troubleshooting

### Karabiner doesn't see changes after regenerating config

1. **Run the reload script**: `karabiner-reload.sh`
   - This restarts the Karabiner console user server

2. **If reload script doesn't work**, restart Karabiner-Elements completely:
   ```bash
   osascript -e 'quit app "Karabiner-Elements"' && sleep 1 && open -a 'Karabiner-Elements'
   ```

3. **Verify the symlink is correct**:
   ```bash
   ls -la ~/.config/karabiner/karabiner.json
   # Should show: ... -> ~/.config/mise/dotfiles/karabiner.json
   ```

4. **If the link is missing**, re-apply the dotfiles:
   ```bash
   mise -C ~ dot apply '~'
   ```

### The link was replaced with a regular file

Karabiner's settings UI can save over the link. Compare the file with the generated one, move it
aside, then re-apply the dotfiles with `mise -C ~ dot apply '~'`.

## Notes

- **Do NOT** run `touch ~/.config/karabiner/karabiner.json` - this will break the symlink
- Karabiner watches the config file but may need manual reload via `karabiner-reload.sh`
