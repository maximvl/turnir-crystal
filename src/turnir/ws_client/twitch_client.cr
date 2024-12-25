module Turnir::WSClient::TwitchClient
  extend self

  @@websocket : HTTP::WebSocket | Nil = nil
  WebsocketMutex = Mutex.new

  @@message_counter = 0

  def log(msg)
    print "[TwitchWS] "
    puts msg
  end

  def start(sync_channel : Channel(Nil))
    WebsocketMutex.synchronize do
      if @@websocket.nil?
        @@websocket = HTTP::WebSocket.new(
          "wss://irc-ws.chat.twitch.tv:443",
          headers=HTTP::Headers{
            "Origin" => "https://www.twitch.tv"
          },
        )
      end
    end

    websocket = @@websocket
    if websocket.nil?
      log "Failed to start websocket"
      return
    end

    websocket.on_message do |msg|
      if msg == "PING :tmi.twitch.tv"
        websocket.send("PONG :tmi.twitch.tv")
        next
      end
      # log "WS message: #{msg}"
      parsed = parse_message(msg)
      # log "Parsed message: #{parsed.inspect}"
      if parsed
        Turnir::ChatStorage::TWITCH_STORAGE.add_message(parsed)
      end
    end

    websocket.on_close do |code|
      log "Websocket Closed: #{code}"
      @@websocket = nil
    end

    websocket.send("PASS oauth:#{Turnir::Config::TWITCH_OAUTH_TOKEN}")
    websocket.send("NICK #{Turnir::Config::TWITCH_NICK}")
    sync_channel.send(nil)
    websocket.run()
    @@websocket = nil
  end

  def subscribe_to_channel(channel_name : String)
    websocket = @@websocket
    if websocket.nil?
      log "Websocket is not connected"
      return
    end

    websocket.send("JOIN ##{channel_name}")
  end

  def stop
    @@websocket.try { |ws| ws.close }
  end

  def parse_message(msg : String) : Turnir::ChatStorage::Types::ChatMessage | Nil
    parts = msg.split(" ")
    if parts.size < 4
      return nil
    end

    channel = parts[2][1..-1]
    message = parts[3..-1].join(" ").strip()
    ts = Time.utc.to_unix

    @@message_counter += 1
    message_id = @@message_counter

    user_name = parts[0].split("!")[0][1..-1]
    user = Turnir::ChatStorage::Types::ChatUser.new(username: user_name, id: user_name)

    Turnir::ChatStorage::Types::ChatMessage.new(id: message_id, ts: ts, message: message, user: user, vkFields: nil, channel: channel)
  end

end
