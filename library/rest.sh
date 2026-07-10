#!/bin/env bash
# REST API calls

send_message() {
    local channel_id=$1 content=$2
    curl -s -o /dev/null -X POST "$API_BASE/channels/$channel_id/messages" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$(jq -nc --arg content "$content" '{content: $content}')"
}
send_reply() {
    local channel_id=$1 content=$2 reply_to=$3
    curl -s -o /dev/null -X POST "$API_BASE/channels/$channel_id/messages" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$(jq -nc --arg content "$content" --arg reply_to "$reply_to" '{content: $content, "message_reference": {"message_id":"$reply_to"}}')"
}
