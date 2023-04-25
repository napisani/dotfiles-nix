ENV_VARS_SEC_CONFIG_SLUG=clearing
OUTPUT=$(secret_inject --project workstation_env_vars --env $ENV_VARS_SEC_CONFIG_SLUG)
RESULT=$?
if [ $RESULT -eq 0 ]; then
  source "$OUTPUT"
else
  echo "$OUTPUT" >> /dev/stderr
fi
