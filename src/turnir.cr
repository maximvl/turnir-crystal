require "./turnir/webserver"
require "./turnir/client/client"
require "./turnir/db_storage"

puts "Starting Turnir build: #{Turnir::Config::BUILD_TIME}"

Turnir::DbStorage.create_tables

# puts Turnir::DbStorage.save_preset Turnir::DbStorage::Preset.new(id: "tmp", title: "test", owner_id: "123", created_at: Time.utc.to_unix, updated_at: Time.utc.to_unix, options: ["1","2","3"])
# puts Turnir::DbStorage.get_preset "tmp"
# exit 0

spawn do
  Turnir::Client.client_auto_stopper
end

# spawn do
#  Turnir.ensure_twitch_websocket_running
#  Turnir::WSClient::TwitchClient.subscribe_to_channel("roadhouse")
# end

Turnir::Webserver.start
