require "./turnir/webserver/endpoints"
require "./turnir/client/client"
require "./turnir/client/twitch_token_manager"
require "./turnir/db_storage"

puts "Starting Turnir build: #{Turnir::Config::BUILD_TIME}"

Turnir::DbStorage.create_tables

spawn do
  Turnir::Client.client_auto_stopper
end

spawn do
  Turnir::Client::TwitchTokenManager.refresh_loop
end

Turnir::Webserver.start
