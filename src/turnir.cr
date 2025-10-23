require "./turnir/webserver/endpoints"
require "./turnir/client/client"
require "./turnir/client/twitch_token_manager"
require "./turnir/db_storage"
require "./turnir/config"

puts "Starting Turnir build: #{Turnir::Config::BUILD_TIME}"

# Turnir::DbStorage.create_tables

Turnir::Config.initial_channels.each do |channel_string|
  parts = channel_string.split("/")
  if parts.size == 2
    domain, channel_name = parts
    platform = Turnir::Client::DOMAIN_TO_CLIENT_TYPE.fetch(domain, nil)
    if platform
      Turnir::Client.ensure_client_running(platform)
      Turnir::Client.subscribe_to_channel(platform, channel_name)
    else
      puts "Unknown platform: #{domain}"
    end
  end
end

spawn do
  Turnir::Client::TwitchTokenManager.refresh_loop
end

spawn do
  Turnir::Client.client_restarter
end

Turnir::Webserver.start
