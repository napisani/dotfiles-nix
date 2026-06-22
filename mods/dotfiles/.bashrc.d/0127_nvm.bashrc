export NVM_DIR="$HOME/.nvm"
# Source nvm.sh from nixpkgs install (nvm-exec and nvm.sh co-located in store)
if command -v nvm-exec >/dev/null 2>&1; then
    . "$(dirname "$(readlink -f "$(command -v nvm-exec)")")/nvm.sh" 2>/dev/null
elif [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
fi