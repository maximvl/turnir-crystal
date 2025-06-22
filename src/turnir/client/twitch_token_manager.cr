require "http/client"
require "json"

module Turnir::Client::TwitchTokenManager
  extend self

  struct TokenResponse
    include JSON::Serializable

    property access_token : String
    property refresh_token : String
    property expires_in : Int64
    property scope : Array(String)
    property token_type : String
    property created_at : Int64
    property created_at_str : String
  end

  TOKEN_FILENAME = "twitch_token.json"
  REFRESH_WINDOW = 10.minutes.to_i
  CHECK_INTERVAL = 5.minutes.to_i

  def log(msg)
    print "[TwitchToken] "
    puts msg
  end

  def do_refresh_query(refresh_token : String) : TokenResponse | Nil
    response = HTTP::Client.post("https://id.twitch.tv/oauth2/token",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      form: {
        "client_id"     => Turnir::Config::TWITCH_CLIENT_ID,
        "client_secret" => Turnir::Config::TWITCH_CLIENT_SECRET,
        "grant_type"    => "refresh_token",
        "refresh_token" => refresh_token,
      }
    )

    if response.status_code == 200
      body = JSON.parse(response.body).as_h
      body["created_at"] = JSON::Any.new(Time.utc.to_unix)
      body["created_at_str"] = JSON::Any.new(Time.utc.to_s)
      TokenResponse.from_json(body.to_json)
    else
      log "Failed to refresh token: #{response.status_code} #{response.body}"
      nil
    end
  end

  def save_token_response(token_response : TokenResponse)
    File.write(TOKEN_FILENAME, token_response.to_json)
  end

  def load_token_response : TokenResponse | Nil
    if File.exists?(TOKEN_FILENAME)
      TokenResponse.from_json(
        JSON.parse(File.read(TOKEN_FILENAME)).to_json
      )
    else
      nil
    end
  end

  def refresh_token
    token_response = load_token_response
    if token_response.nil?
      log "No token file found, cannot refresh."
      return nil
    end

    if Turnir::Config.get_twitch_token != token_response.access_token
      Turnir::Config.set_twitch_token(token_response.access_token)
      log "Token updated"
    end

    if (Time.utc.to_unix + REFRESH_WINDOW) > (token_response.created_at + token_response.expires_in)
      new_token_response = do_refresh_query(token_response.refresh_token)
      if new_token_response.nil?
        log "Failed to refresh token."
        return nil
      end
      save_token_response(new_token_response)
      Turnir::Config.set_twitch_token(new_token_response.access_token)
      log "Token refreshed successfully."
    end
  end

  def refresh_loop
    loop do
      refresh_token
      sleep CHECK_INTERVAL
    end
  end
end
