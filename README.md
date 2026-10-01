This is an automation script for Playnite Web by andrew-codes:
https://github.com/andrew-codes/playnite-web

Run the .bat file:
- Available commands: start, stop, restart, update, remove
- Without command it defaults to 'start' command
- Checks if .env is present, if not creates it
- Sets MQTT config
- Start docker containers and opens the app in your default browser
- From the .env copy MQTT password to Playnite MQTT plugin