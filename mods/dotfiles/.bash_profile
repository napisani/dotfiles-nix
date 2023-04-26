
# SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR="$HOME"
for file in ~/.bashrc.d/*.bashrc
do
    file_only=$(basename "$file")
    if ! grep -q "$file_only" ~/.bashrc.d/excludes.txt; then
        source "$file"
    fi
done
# [[ -r ~/.bashrc ]] && . ~/.bashrc

