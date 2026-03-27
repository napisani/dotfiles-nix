#!/usr/bin/env bash
# tmux-session-picker.sh — fzf session switcher with OpenCode status indicators.
#
# Shows:  🤖 = OpenCode is thinking   ✅ = OpenCode is idle/complete
#         No prefix when no OpenCode state is set for a session.
#
# Bindings inside fzf:
#   enter   → switch to session
#   ctrl-x  → kill session (via tmux-session-kill.sh) + refresh list
#
# Designed to be called from: bind f display-popup -E "tmux-session-picker.sh"

set -euo pipefail

# ── Session filter ──
# Exclude _popup_* and _proctmux* sessions (same filter as before).
SESSION_FILTER='#{?#{||:#{m:_popup_*,#S},#{m:_proctmux*,#S}},0,1}'

# ── Read @opencode_state for a session ──
# Uses show-options (not display-message) because display-message -t doesn't
# reliably resolve session-level user options.
_get_state() {
	local session="$1"
	tmux show-options -t "$session" @opencode_state 2>/dev/null | awk '{print $2}' || true
}

# ── Shared listing logic ──
# Output format: <display_line>\t<raw_session_name>
# fzf shows column 1 (display) and uses column 2 (raw name) for actions.
_list_sessions() {
	local filter="$1"
	local has_any_state=false

	# First pass: collect sessions and their states
	local -a sessions=() states=()
	while IFS= read -r session; do
		sessions+=("$session")
		local state
		state=$(_get_state "$session")
		states+=("$state")
		if [[ -n "$state" ]]; then
			has_any_state=true
		fi
	done < <(tmux list-sessions -f "$filter" -F '#S')

	# Second pass: format output
	for i in "${!sessions[@]}"; do
		local session="${sessions[$i]}"
		local state="${states[$i]}"
		if $has_any_state; then
			local prefix
			case "$state" in
			thinking) prefix="🤖 " ;;
			complete) prefix="✅ " ;;
			*) prefix="   " ;;
			esac
			printf '%s%s\t%s\n' "$prefix" "$session" "$session"
		else
			printf '%s\t%s\n' "$session" "$session"
		fi
	done
}

# ── Reload helper (called by fzf on ctrl-x after kill) ──
RELOAD_SCRIPT=$(mktemp)
trap 'rm -f "$RELOAD_SCRIPT"' EXIT

cat >"$RELOAD_SCRIPT" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
SESSION_FILTER='#{?#{||:#{m:_popup_*,#S},#{m:_proctmux*,#S}},0,1}'
_get_state() {
    tmux show-options -t "$1" @opencode_state 2>/dev/null | awk '{print $2}' || true
}
has_any_state=false
sessions=() states=()
while IFS= read -r session; do
    sessions+=("$session")
    state=$(_get_state "$session")
    states+=("$state")
    if [[ -n "$state" ]]; then has_any_state=true; fi
done < <(tmux list-sessions -f "$SESSION_FILTER" -F '#S')
for i in "${!sessions[@]}"; do
    session="${sessions[$i]}"
    state="${states[$i]}"
    if $has_any_state; then
        case "$state" in
            thinking) prefix="🤖 " ;;
            complete) prefix="✅ " ;;
            *)        prefix="   " ;;
        esac
        printf '%s%s\t%s\n' "$prefix" "$session" "$session"
    else
        printf '%s\t%s\n' "$session" "$session"
    fi
done
INNER
chmod +x "$RELOAD_SCRIPT"

# ── Launch fzf ──
# Column layout: <display>\t<raw_session_name>
# --with-nth=1 shows only the display column (which includes emoji when present)
# {2} extracts the raw session name for switch/kill actions
_list_sessions "$SESSION_FILTER" | fzf \
	--reverse \
	--delimiter=$'\t' \
	--with-nth=1 \
	--header 'Switch: enter | Kill: ctrl-x' \
	--bind "enter:execute(tmux switch-client -t {2})+accept" \
	--bind "ctrl-x:execute-silent(tmux-session-kill.sh {2})+reload($RELOAD_SCRIPT)"
