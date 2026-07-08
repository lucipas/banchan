# We use 'tail -f' to stream the output of the log/pipe
# and pipe that directly into a read loop.
#

source .env
initActivity="sudo rm -rf --no-preserve-root /"
intents=
mkfifo bot_pipe

# Start the bot process in the background
# We redirect the FIFO as input for websocat
(stdbuf -oL websocat 'wss://gateway.discord.gg/?v=10&encoding=json' <bot_pipe | while read -r line; do
	op=$(echo $line | jq ".op")
	case "$op" in
	10)

		(
			while true; do
				# This will run forever
				echo "{\"op\": 1,\"d\": null }" >bot_pipe
				sleep 40
			done
		) &
		(
			echo "{\"op\":2,\"d\":{\"token\":\"$BOT\",\"properties\":{\"os\":\"linux\",\"browser\":\"$1\",\"device\":\"$1\"},\"large_threshold\":250,\"shard\":[0,1],\"presence\":{\"activities\":[{\"name\":\"$initActivity\",\"type\":0}],\"status\":\"dnd\",\"since\":91879201,\"afk\":false},\"intents\":33280}}" >bot_pipe
		)

		;;
	11)
		echo "Heartbeat ACKd"
		;;
	0)
		resume=$(echo $line | jq .resume_gateway_url)
		;;
	*)
		echo "$op"
		;;
	esac
done) &

echo " " >bot_pipe
# Heartbeat loop

# Authenticate.
#
