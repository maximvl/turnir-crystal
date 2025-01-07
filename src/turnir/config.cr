module Turnir::Config
  extend self

  ROADHOUSE_CHAT = "channel-chat:6367818"
  LASQA_CHAT = "channel-chat:8845069"

  BUILD_TIME = {{ "#{`date`.strip}" }}

  def webserver_ip
    ENV.fetch("IP", "127.0.0.1")
  end

  def webserver_port
    ENV.fetch("PORT", "8080").to_i
  end

  TWITCH_OAUTH_TOKEN = ENV.fetch("TWITCH_OAUTH", "NO_TOKEN")
  TWITCH_CLIENT_ID = ENV.fetch("TWITCH_CLIENT_ID", "NO_CLIENT_ID")
  TWITCH_NICK = ENV.fetch("TWITCH_NICK", "turnir_bot")
end
