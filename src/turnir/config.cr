module Turnir::Config
  extend self

  ROADHOUSE_CHAT = "channel-chat:6367818"
  LASQA_CHAT     = "channel-chat:8845069"

  BUILD_TIME = {{ "#{`date`.strip}" }}

  def database_url
    ENV.fetch("DATABASE_URL", "mysql://root@127.0.0.1/aukus4")
  end

  def webserver_ip
    ENV.fetch("IP", "127.0.0.1")
  end

  def webserver_port
    ENV.fetch("PORT", "8080").to_i
  end

  def client_restarter_interval_seconds
    ENV.fetch("CLIENT_RESTARTER_INTERVAL_SECONDS", "180").to_i
  end

  def channels_api_url
    ENV.fetch("CHANNELS_API_URL", "https://api.eventlab.dev/users?is_active=1&events=aukus4")
  end

  TWITCH_OAUTH_TOKEN = ENV.fetch("TWITCH_OAUTH", "NO_TOKEN")
  TWITCH_CLIENT_ID   = ENV.fetch("TWITCH_CLIENT_ID", "NO_CLIENT_ID")
  TWITCH_NICK        = ENV.fetch("TWITCH_NICK", "turnir_bot")

  TWITCH_CLIENT_SECRET = ENV.fetch("TWITCH_CLIENT_SECRET", "NO_CLIENT_SECRET")
  @@twitch_access_token : String = ""

  KICK_OAUTH_TOKEN = ENV.fetch("KICK_OAUTH", "NO_TOKEN")

  def get_twitch_token
    @@twitch_access_token
  end

  def set_twitch_token(token : String)
    @@twitch_access_token = token
  end
end
