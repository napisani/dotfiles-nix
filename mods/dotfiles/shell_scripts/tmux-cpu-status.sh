#!/usr/bin/env bash

# Use ps so this works on both macOS and Linux.
cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || printf '1')"
cpu_percent="$(LC_ALL=C ps -A -o %cpu= 2>/dev/null | awk -v count="$cpu_count" '{sum += $1} END {if (count > 0) printf "%.0f", sum / count; else printf "0"}')"

printf ' CPU %s%%' "${cpu_percent:-0}"
