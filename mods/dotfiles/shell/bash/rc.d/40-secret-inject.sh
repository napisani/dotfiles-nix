if command -v secret_inject &> /dev/null
then
  secret_inject_args=()
  if [ -n "${SECRET_INJECT_PROFILE:-}" ]; then
    secret_inject_args+=(--profile "$SECRET_INJECT_PROFILE")
  fi
  OUTPUT=$(secret_inject "${secret_inject_args[@]}")
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    eval "$OUTPUT"
  else
    echo "$OUTPUT" >> /dev/stderr
  fi
fi
