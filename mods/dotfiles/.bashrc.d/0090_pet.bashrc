if command -v pet &> /dev/null
then
    function prev() {
      PREV=$(echo `history | tail -n2 | head -n1` | sed 's/[0-9]* //')
      sh -c "pet new `printf %q "$PREV"`"
    }
    function pet-select() {
      BUFFER=$(pet search --query "$READLINE_LINE" --config $(animal-rescue --config ~/.config/pet/config.toml))
      #echo "$BUFFER" | tr '\n' ' ' | pbcopy
      #echo "copied to clipboard!"
      READLINE_LINE=$BUFFER
      READLINE_POINT=${#BUFFER}
    }
    bind -x '"\C-f\C-r": pet-select'
else
    echo "'pet' is missing"
fi
