#!/bin/bash

input=$(cat)

# ── Parse JSON input ───────────────────────────────────────────────────────────
model_full=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input"       | jq -r '.context_window.used_percentage // empty')
session_id=$(echo "$input" | jq -r '.session_id // ""')

# Shorten model name: strip leading "Claude " prefix
model="${model_full#Claude }"

LOG_FILE="/home/tobias.edmeades/.claude/usage_log.jsonl"

# ── Parse usage log for this session ──────────────────────────────────────────
cost_str="~\$0.0000"
cache_pct_str="cache 0%"
token_str="0t"

if [ -n "$session_id" ] && [ -f "$LOG_FILE" ]; then
    session_lines=$(grep "\"$session_id\"" "$LOG_FILE" 2>/dev/null)

    if [ -n "$session_lines" ]; then
        # Sum estimated_cost_usd across all turns
        cost_sum=$(echo "$session_lines" \
            | jq -r '.estimated_cost_usd // 0' 2>/dev/null \
            | awk '{s += $1} END {printf "%.4f", s+0}')
        cost_str=$(printf "~\$%s" "$cost_sum")

        # Cache hit ratio: sum(cache_read) / sum(cache_read + input_tokens)
        cache_pct=$(echo "$session_lines" | jq -r '[.cache_read_input_tokens // 0, .input_tokens // 0] | @tsv' 2>/dev/null \
            | awk '{cr += $1; inp += $2} END {
                total = cr + inp;
                if (total > 0) printf "%.0f", cr / total * 100;
                else print "0"
            }')
        cache_pct_str="cache ${cache_pct}%"

        # Total output tokens for the session
        total_out=$(echo "$session_lines" \
            | jq -r '.output_tokens // 0' 2>/dev/null \
            | awk '{s += $1} END {printf "%.0f", s+0}')
        token_str="${total_out}t"
    fi
fi

# ── ANSI helpers ───────────────────────────────────────────────────────────────
reset="\033[0m"

pick_color() {
    local pct="$1"
    if   [ "$pct" -ge 80 ]; then printf "\033[31m"
    elif [ "$pct" -ge 50 ]; then printf "\033[33m"
    else                          printf "\033[32m"
    fi
}

# ── Context bar (solid blocks, 12 wide) ───────────────────────────────────────
make_block_bar() {
    local pct="$1" width=12
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar=""
    local i
    for i in $(seq 1 $filled); do bar="${bar}█"; done
    for i in $(seq 1 $empty);  do bar="${bar} "; done
    printf "%s" "$bar"
}

if [ -n "$used" ]; then
    used_int=$(printf "%.0f" "$used")
    ctx_color=$(pick_color "$used_int")
    ctx_bar=$(make_block_bar "$used_int")
    ctx_seg="${ctx_color}ctx [${ctx_bar}] ${used_int}%${reset}"
else
    ctx_seg="ctx [            ] --%"
fi

# ── Assemble single line with · separators ────────────────────────────────────
dot=" · "
printf "%b" "${model}${dot}${ctx_seg}${dot}${cache_pct_str}${dot}${cost_str}${dot}${token_str}"
