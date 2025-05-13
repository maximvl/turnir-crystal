module Turnir::Config
  extend self

  ROADHOUSE_CHAT = "channel-chat:6367818"
  LASQA_CHAT     = "channel-chat:8845069"

  BUILD_TIME = {{ "#{`date`.strip}" }}

  def webserver_ip
    ENV.fetch("IP", "127.0.0.1")
  end

  def webserver_port
    ENV.fetch("PORT", "8080").to_i
  end

  TWITCH_OAUTH_TOKEN = ENV.fetch("TWITCH_OAUTH", "NO_TOKEN")
  TWITCH_CLIENT_ID   = ENV.fetch("TWITCH_CLIENT_ID", "NO_CLIENT_ID")
  TWITCH_NICK        = ENV.fetch("TWITCH_NICK", "turnir_bot")

  KICK_OAUTH_TOKEN = ENV.fetch("KICK_OAUTH", "NO_TOKEN")
  YOUTUBE_API_KEY = ENV.fetch("YOUTUBE_API_KEY", "NO_API_KEY")
  YOUTUBE_POLL_SECS = ENV.fetch("YOUTUBE_POLL_SECS", "10").to_f

  INACTIVE_TIMEOUT_MINS = ENV.fetch("INACTIVE_TIMEOUT_MINS", "30").to_f
end
