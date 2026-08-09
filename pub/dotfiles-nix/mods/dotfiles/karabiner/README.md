# Karabiner Configuration

This directory contains the TypeScript source files for generating Karabiner-Elements configuration.

## Workflow

### 1. Edit TypeScript source files
Modify keyboard mappings in `src/` directory

### 2. Generate karabiner.json
```bash
cd ~/.config/home-manager/mods/dotfiles/karabiner
deno run -A polyfill.ts > ../karabiner.json
```

### 3. Reload Karabiner to apply changes
```bash
karabiner-reload.sh
```

Alternatively, use the full app restart method:
```bash
osascript -e 'quit app "Karabiner-Elements"' && sleep 1 && open -a 'Karabiner-Elements'
```

## How it Works

- The generated `karabiner.json` is symlinked from `~/.config/karabiner/karabiner.json`
- The symlink is managed by home-manager in `mods/shell.nix` (lines 77-79)
- Uses `mkOutOfStoreSymlink` to point directly to `mods/dotfiles/karabiner.json`
- This allows editing the generated file without rebuilding home-manager
- **Important**: The symlink goes through Nix store intermediates but ultimately resolves to this dotfiles directory

## Symlink Chain

```
~/.config/karabiner/karabiner.json 
  → /nix/store/...-home-manager-files/.config/karabiner/karabiner.json
    → /nix/store/...-hm_karabiner.json
      → ~/.config/home-manager/mods/dotfiles/karabiner.json
```

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
   # Should show: lrwxr-xr-x ... -> /nix/store/.../karabiner.json
   ```

4. **If symlink is broken or missing**, rebuild home-manager:
   ```bash
   nixswitch
   ```

### Symlink was accidentally replaced with a regular file

If you see `~/.config/karabiner/karabiner.json` as a regular file instead of a symlink:

1. Remove the file:
   ```bash
   rm ~/.config/karabiner/karabiner.json
   ```

2. Rebuild home-manager to restore the symlink:
   ```bash
   nixswitch
   ```

## Notes

- **Do NOT** run `touch ~/.config/karabiner/karabiner.json` - this will break the symlink
- No need to run `nixswitch` after regenerating karabiner.json (only after fixing broken symlinks)
- The symlink configuration is in `~/.config/home-manager/mods/shell.nix`
- Karabiner watches the config file but may need manual reload via `karabiner-reload.sh`
