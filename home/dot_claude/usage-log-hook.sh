#!/bin/bash
# Logs per-turn token usage and estimated cost from the transcript file.
# Fires on the Stop hook; reads token counts from the last assistant message
# in the transcript rather than relying on direct payload fields.
#
# Claude Sonnet 4.6 / Opus 4.6 pricing used for estimation:
#   Input:         $3.00 / $15.00 / 1M tokens
#   Output:        $15.00 / $75.00 / 1M tokens
#   Cache read:    $0.30 / $1.50 / 1M tokens
#   Cache write:   $3.75 / $18.75 / 1M tokens
# (Sonnet 4.6 is 1/5 the price of Opus 4.6)

LOG_FILE="/home/tobias.edmeades/.claude/usage_log.jsonl"

input=$(cat)

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
session_id=$(echo "$input"       | jq -r '.session_id      // ""')
transcript=$(echo "$input"       | jq -r '.transcript_path // ""')
model_id=$(echo "$input"         | jq -r '.model           // ""')

# Read token usage from the last assistant message in the transcript
input_tokens=0
output_tokens=0
cache_read=0
cache_write=0
if [ -f "$transcript" ]; then
    usage=$(grep '"type":"assistant"' "$transcript" 2>/dev/null | tail -1 \
        | jq -r '.message.usage // empty' 2>/dev/null)
    if [ -n "$usage" ]; then
        input_tokens=$(echo "$usage" | jq -r '.input_tokens                // 0')
        output_tokens=$(echo "$usage" | jq -r '.output_tokens               // 0')
        cache_read=$(echo "$usage"    | jq -r '.cache_read_input_tokens     // 0')
        cache_write=$(echo "$usage"   | jq -r '.cache_creation_input_tokens // 0')
    fi
fi

# Estimated cost — use Sonnet 4.6 pricing unless model contains "opus"
is_opus=0
if echo "$model_id" | grep -qi "opus"; then is_opus=1; fi

estimated_cost=$(echo "$input_tokens $output_tokens $cache_read $cache_write $is_opus" | awk '{
    it=$1; ot=$2; cr=$3; cw=$4; opus=$5
    if (opus) {
        # Opus 4.6
        cost = (it * 15.00 + ot * 75.00 + cr * 1.50 + cw * 18.75) / 1000000
    } else {
        # Sonnet 4.6
        cost = (it * 3.00 + ot * 15.00 + cr * 0.30 + cw * 3.75) / 1000000
    }
    printf "%.6f", cost
}')

# Optional overage fields (only present when usage exceeds plan limit)
session_tokens=$(echo "$input" | jq -r '.session_tokens_used // empty')
session_cost=$(echo "$input"   | jq -r '.session_cost_usd    // empty')

# Skip writing if no meaningful data was captured
if [ "$input_tokens" = "0" ] && [ "$output_tokens" = "0" ] && [ -z "$session_tokens" ]; then
    exit 0
fi

jq -n \
    --arg  ts   "$timestamp" \
    --arg  sid  "$session_id" \
    --arg  mid  "$model_id" \
    --argjson it  "$input_tokens" \
    --argjson ot  "$output_tokens" \
    --argjson cr  "$cache_read" \
    --argjson cw  "$cache_write" \
    --argjson ec  "$estimated_cost" \
    --argjson st  "${session_tokens:-null}" \
    --argjson sc  "${session_cost:-null}" \
    '{
        timestamp:                   $ts,
        session_id:                  $sid,
        model:                       $mid,
        input_tokens:                $it,
        output_tokens:               $ot,
        cache_read_input_tokens:     $cr,
        cache_creation_input_tokens: $cw,
        estimated_cost_usd:          $ec,
        session_tokens_used:         $st,
        session_cost_usd:            $sc
    }' -c >> "$LOG_FILE"
