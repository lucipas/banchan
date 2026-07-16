#!/usr/bin/env bash
# Requirements: bash 4+, curl, jq, websocat
# Gateway stuff

set -uo pipefail

### Configuration

: "${DISCORD_BOT_TOKEN:?Set DISCORD_BOT_TOKEN to your bot token first}"

API_BASE="https://discord.com/api/v10"

RECONNECT_DELAY=5 # seconds between reconnect attempts

### Runtime state

WORKDIR=$(mktemp -d "/tmp/discord-bot.XXXXXX")
SEQ_FILE="$WORKDIR/seq"
HB_PID_FILE="$WORKDIR/heartbeat.pid"
FIFO="$WORKDIR/gateway_in"

echo "null" >"$SEQ_FILE"
mkfifo "$FIFO"

### Cleanup

cleanup() {
	stop_heartbeat
	exec 3>&- 2>/dev/null || true
	rm -rf "$WORKDIR"
}

trap cleanup EXIT
trap 'exit 0' INT TERM

# Small helpers

require_bin() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "Missing dependency: $1" >&2
		exit 1
	}
}

require_bin jq
require_bin curl
require_bin websocat

# TODO: put this behind a var so i don't get log bombed
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

# Send a raw JSON payload up to the gateway (through the open fifo fd).
gw_send() { echo "$1" >&3; }

get_gateway_url() {
	curl -sf -H "Authorization: Bot $DISCORD_BOT_TOKEN" "$API_BASE/gateway/bot" |
		jq -r '.url'
}

# Heartbeat

stop_heartbeat() {
	if [[ -f "$HB_PID_FILE" ]]; then
		kill "$(cat "$HB_PID_FILE")" 2>/dev/null || true
		rm -f "$HB_PID_FILE"
	fi
}

start_heartbeat() {
	local interval_ms=$1
	local interval_s
	interval_s=$(awk -v ms="$interval_ms" 'BEGIN { printf "%.3f", ms/1000 }')

	stop_heartbeat

	(
		sleep "$interval_s"
		while true; do
			seq=$(cat "$SEQ_FILE" 2>/dev/null || echo null)
			gw_send "$(jq -nc --argjson seq "$seq" '{op:1, d:$seq}')"
			log "<3"
			sleep "$interval_s"
		done
	) &
	echo $! >"$HB_PID_FILE"
	log "Heartbeat started (every ${interval_s}s)"
}

# Gateway payload handling

do_identify() {
	gw_send "$(jq -nc \
		--arg token "$DISCORD_BOT_TOKEN" \
		--argjson intents "$INTENTS" \
		'{
            op: 2,
            d: {
                token: $token,
                intents: $intents,
                properties: { os: "linux", browser: "banchan", device: "banchan" }
            }
        }')"
}

handle_payload() {
	local payload=$1
	local op seq event_type data

	op=$(echo "$payload" | jq -r '.op')
	seq=$(echo "$payload" | jq -r '.s')
	event_type=$(echo "$payload" | jq -r '.t // empty')

	[[ "$seq" != "null" ]] && echo "$seq" >"$SEQ_FILE"

	case "$op" in
	0) # Dispatch
		data=$(echo "$payload" | jq -c '.d')
		handle_dispatch "$event_type" "$data"
		;;
	1) # Gateway asks for an immediate heartbeat
		gw_send "$(jq -nc --argjson seq "$(cat "$SEQ_FILE")" '{op:1, d:$seq}')"
		;;
	7) # Reconnect requested
		log "Gateway requested reconnect"
		exit 0
		;;
	9) # Invalid session — reconnect fresh
		log "Invalid session, reconnecting"
		exit 0
		;;
	10) # Hello — carries the heartbeat interval
		local interval
		interval=$(echo "$payload" | jq -r '.d.heartbeat_interval')
		start_heartbeat "$interval"
		do_identify
		;;
	11) # Heartbeat ACK — nothing to do
		;;
	*)
		;;
	esac
}

# Main session loop

run_session() {
	local gateway_url
	gateway_url=$(get_gateway_url)
	if [[ -z "$gateway_url" || "$gateway_url" == "null" ]]; then
		log "Could not fetch gateway URL — check DISCORD_BOT_TOKEN"
		return 1
	fi
	gateway_url="${gateway_url}?v=10&encoding=json"
	log "Connecting to $gateway_url"

	# keep websocat from exiting
	exec 3<>"$FIFO"

	websocat -t "$gateway_url" <&3 | while IFS= read -r line; do
		handle_payload "$line"
	done

	exec 3>&-
	stop_heartbeat
}

update_presence() {
	gw-send $(
		jq -nc \
			--arg name "$1" \
			--argjson type ${3:-0} \
			--arg status "$2" \
			--argjson since "$([ "$2" == "idle" ] && date +%s000 || echo null)" \
			'{
    op: 3,
    d: {
      since: $since,
      activities: [{
        name: $name,
        type: $type
      }],
      status: $status,
      afk: false
    }
}'
	)
}

start_bot() {
	log "Starting."
	while true; do
		run_session || true
		log "Disconnected. Reconnecting in ${RECONNECT_DELAY}s..."
		sleep "$RECONNECT_DELAY"
	done
}
