# ble.sh must attach after prompt integrations and local overrides so it can
# preserve their final PROMPT_COMMAND and PS1 state.

[ -z "${BLE_VERSION:-}" ] || ble-attach
