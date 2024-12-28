require "json"
require "http/client"

require "../parsing/nuum_message"
require "./channel_mapper"

module Turnir::Client::NuumWebsocket
  extend self

  WS_URL = "wss://socket.nuum.ru/connection/v1/websocket"

  @@websocket : HTTP::WebSocket | Nil = nil
  WebsocketMutex = Mutex.new

  @@message_counter = 0

  HEADERS = HTTP::Headers{
    "Origin" => "https://nuum.ru",
    "Accept" => "application/json",
    "Content-Type" => "application/json"
  }

  PUBLIC_CHANNEL_URL = "https://nuum.ru/api/v2/broadcasts/public?channel_name={{channel}}"
  CHAT_URL = "https://nuum.ru/api/v3/chats?contentType={{type}}&contentId={{id}}"

  def log(msg : String)
    print "[NuumPolling] "
    puts msg
  end

  def start(sync_channel : Channel(Nil), storage : Turnir::ChatStorage::Storage)
    WebsocketMutex.synchronize do
      if @@websocket.nil?
        @@websocket = HTTP::WebSocket.new(
          WS_URL,
          headers=HEADERS,
        )
      end
    end

    websocket = @@websocket
    if websocket.nil?
      log "Failed to start websocket"
      return
    end

    websocket.on_message do |msg|
      log "WS message: #{msg}"
      if msg == "{}"
        websocket.send("{}")
        next
      end

      parsed = parse_message(msg)
      if parsed
        chat_message = Turnir::ChatStorage::Types::ChatMessage.from_nuum_message(parsed)
        storage.add_message(chat_message)
      end
    end

    websocket.on_close do |code|
      log "Websocket Closed: #{code}"
      @@websocket = nil
    end

    send_connect()
    sync_channel.send(nil)
    websocket.run()
    @@websocket = nil
  end

  def send_connect()
    @@message_counter += 1
    connect_message = {
      "connect" => {"name" => "js"},
      "id" => @@message_counter,
    }
    @@websocket.try { |ws| ws.send(connect_message.to_json) }
  end

  def subscribe_to_channel(channel_name : String)
    chat_id = get_chat_id(channel_name)
    if chat_id.nil?
      log "Failed to get chat id for #{channel_name}"
      return
    end
    channel = "chats:#{chat_id}"
    Turnir::Client::ChannelMapper.set_nuum_channel(channel_name, channel)
    send_subscribe(channel)
  end

  def send_subscribe(channel : String)
    @@message_counter += 1
    subscribe_message = {
      "subscribe" => {"channel" => channel},
      "id" => @@message_counter,
    }
    @@websocket.try { |ws| ws.send(subscribe_message.to_json) }
  end

  def get_chat_id(channel_name : String) : Int32 | Nil
    channel_url = PUBLIC_CHANNEL_URL.sub("{{channel}}", channel_name)
    resporse = HTTP::Client.get(channel_url, headers: HEADERS)

    begin
      parsed = Turnir::Parsing::NuumMessage::ChannelResponse.from_json(resporse.body)
    rescue ex
      log "Failed to get media container: #{ex.inspect} #{resporse.body}"
      return nil
    end

    container_id = parsed.result.media_container.media_container_id
    container_type = parsed.result.media_container.media_container_type

    chat_url = CHAT_URL.sub("{{type}}", container_type).sub("{{id}}", container_id.to_s)
    chat_response = HTTP::Client.get(chat_url, headers: HEADERS)

    begin
      parsed = Turnir::Parsing::NuumMessage::ChatResponse.from_json(chat_response.body)
    rescue ex
      log "Failed to get chat id: #{ex.inspect} #{chat_response.body}"
      return nil
    end

    parsed.result.id
  end

  def parse_message(msg : String) : Turnir::Parsing::NuumMessage::ChatMessage | Nil
    begin
      Turnir::Parsing::NuumMessage::ChatMessage.from_json(msg)
    rescue ex
      log "Failed to parse message: #{ex.inspect} #{msg}"
      return nil
    end
  end

  def stop
    @@websocket.try { |ws| ws.close }
  end
end
