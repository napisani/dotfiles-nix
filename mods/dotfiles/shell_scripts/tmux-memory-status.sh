#!/usr/bin/env bash

if [ -r /proc/meminfo ]; then
  memory_percent="$(awk '
    /MemTotal:/ { total = $2 }
    /MemAvailable:/ { available = $2 }
    END {
      if (total > 0) printf "%.0f", (total - available) * 100 / total
    }
  ' /proc/meminfo)"
else
  # macOS reports free, purgeable, and speculative pages through vm_stat.
  page_size="$(pagesize 2>/dev/null || printf '4096')"
  total_bytes="$(sysctl -n hw.memsize 2>/dev/null || printf '0')"
  unused_pages="$(vm_stat 2>/dev/null | awk '
    /Pages free/ { free = $3 }
    /Pages purgeable/ { purgeable = $3 }
    /Pages speculative/ { speculative = $3 }
    END {
      gsub(/\./, "", free)
      gsub(/\./, "", purgeable)
      gsub(/\./, "", speculative)
      printf "%.0f", free + purgeable + speculative
    }
  ')"
  memory_percent="$(awk -v total="$total_bytes" -v page="$page_size" -v unused="$unused_pages" 'BEGIN {
    if (total > 0) printf "%.0f", (total - unused * page) * 100 / total
  }')"
fi

printf ' MEM %s%%' "${memory_percent:-0}"
