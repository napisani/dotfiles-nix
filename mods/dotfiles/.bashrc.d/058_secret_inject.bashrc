if command -v secret_inject &> /dev/null
then
  OUTPUT=$(secret_inject)
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    eval "$OUTPUT"
  else
    echo "$OUTPUT" >> /dev/stderr
  fi
fi
