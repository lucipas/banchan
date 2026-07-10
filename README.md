# Banchan
a discord bot framework written in bash.

### Setup
   1. Create an application + bot at https://discord.com/developers/applications
   2. Under Bot > Privileged Gateway Intents, enable "Message Content Intent"
      (required if you want to read the text of normal messages).
   3. Invite the bot to a server with at least the "Send Messages" permission.
   4. Save the API key to your .env file

### Usage
```bash
. .env # source your Discord Bot API key
. ./library/rest.sh # source the REST API.

. banchan.sh # Source the core runner and helper code

# Gateway intents.
# https://discord.com/developers/docs/topics/gateway#gateway-intents
#   GUILDS          = 1 << 0  = 1
#   GUILD_MESSAGES  = 1 << 9  = 512
#   MESSAGE_CONTENT = 1 << 15 = 32768  (privileged — enable in the portal)

INTENTS=$(( (1 << 0) | (1 << 9) | (1 << 15) )) # Declare your gateway intents.

# Declare how you want to handle events
handle_dispatch() {
    local event_type=$1 data=$2

    case "$event_type" in
        READY)
            local username
            username=$(echo "$data" | jq -r '.user.username')
            log "Logged in as $username"
            ;;
        MESSAGE_CREATE)
            local channel_id content is_bot
            channel_id=$(echo "$data" | jq -r '.channel_id')
            content=$(echo "$data" | jq -r '.content')
            is_bot=$(echo "$data" | jq -r '.author.bot // false')
            message_id=$(echo "$data" | jq -r '.message_id // false')
            [[ "$author_is_bot" == "true" ]] && return   # ignore bots (including ourselves)

            case "$content" in
	        # Add cmds as you wish
                "!ping")
                    send_message "$channel_id" "Pong!" # Send a message
                    ;;
                "!bash")
                    ./cogs/tts.sh # or call a cog.
                    ;;
            esac
            ;;
        *)
            : # noop
            ;;
    esac
}

start_bot
```

### TODOs:
   - Handle reconnection
   - Respect Rate Limiting
   - The bulk of the REST API
   - Presence Handling
   - Sharding
   - Prevent command subsitution  (i.e `!echo $(sudo rm -rf --no-preserve-root /)`)
	   -  with `shopt`?

### Limitations
   - No zlib-compressed transport is requested, so we can stay in
     plain JSON (no compression handling needed in bash).
   - IDK how this would scale for large guilds

### Namespace
#### REST API
| command                                        |                       |
| :--------------------------------------------- | :-------------------- |
| send_message "channel_id" "content"            | sends message         |
| send_reply "channel_id" "content" "message_ID" | sends a reply message |
| ban                                            | bans a user TODO      |
| delete                                         | delets a message TODO |
| pin                                            | pins a message TODO   |
| channel                                        | manages channels TODO |

#### Gateway functions
| command          |                                                                          |
| :--------------- | :----------------------------------------------------------------------- |
| cleanup          | cleans up named pipes                                                    |
| gw_send          | send a JSON payload to gateway                                           |
| get_gateway_url  | acquires gateway endpoint                                                |
| stop_heartbeat   | stops heartbeat loop                                                     |
| start_heartbeat  | starts heartbeat loop                                                    |
| do_identify      | Identifies the bot to gateway                                            |
| handle_payload   | Routes payloads                                                          |
| run_session      | Main bot loop                                                            |
| start_bot        | starts bot                                                               |
| typing           | Start the \[Bot\] is typing TODO                                         |
| update_presence  | Update the presence for the bot TODO                                     |
| emojis           | Handle the Guild's emojis TODO                                           |
| soundboard       | Handle the Guild's soundboard TODO                                       |
| join_vc          | Join a Guild's Voice Channel TODO                                        |
| capture_vc_audio | Capture a voice channel's audio (TODO, IDK this might make my head hurt) |


#### Helper functions
| command     |                     |
| :---------- | :------------------ |
| require_bin | Checks dependencies |
| log         | Logs                |
