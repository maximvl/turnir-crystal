require "json"
require "xml"
require "http/client"

require "../parsing/vk_message"
require "./channel_mapper"

module Turnir::Client::VkWebsocket
  extend self

  WS_URL = "wss://pubsub.live.vkvideo.ru/connection/websocket?cf_protocol_version=v2"
  Headers = HTTP::Headers{"Origin" => "https://live.vkvideo.ru"}

  CHANNEL_INFO_URL = "https://api.live.vkvideo.ru/v1/blog/{{name}}/public_video_stream/chat/user/"

  @@websocket : HTTP::WebSocket | Nil = nil
  WebsocketMutex = Mutex.new

  @@message_counter = 0

  def log(msg)
    print "[VkvideoWS] "
    puts msg
  end

  def start(sync_channel : Channel(Nil), storage : Turnir::ChatStorage::Storage)
    app_config = get_vk_app_config()
    if app_config.nil?
      log "Failed to get vk token"
      return
    end

    log "Got app config: #{app_config.inspect}"

    WebsocketMutex.synchronize do
      if @@websocket.nil?
        @@websocket = HTTP::WebSocket.new(
          WS_URL,
          headers=Headers,
        )
      end
    end

    websocket = @@websocket
    if websocket.nil?
      log "Failed to create websocket"
      return
    end

    websocket.on_message do |msg|
      # log "WS message: #{msg}"
      if msg == "{}"
        websocket.send("{}")
        next
      end
      parsed = parse_message(msg)
      if parsed
        storage.add_message(parsed)
      end
    end

    websocket.on_close do |code|
      log "Websocket Closed: #{code}"
      @@websocket = nil
    end

    log "Starting websocket"
    send_login(app_config.websocket.token)

    sync_channel.send(nil)
    websocket.run()
    @@websocket = nil
  end

  def parse_message(json_message)
    begin
      parsed = Turnir::Parsing::VkMessage::ChatMessage.from_json(json_message)
    rescue ex
      log "Failed to parse message: #{ex.inspect}"
      log "Message: #{json_message.inspect}"
      return nil
    end

    # log "Parsed: #{parsed.inspect}"
    # return nil

    if parsed.push.pub.data.type != "message"
      return
    end

    message_data = parsed.push.pub.data.data.data
    mentions = Array(Turnir::Parsing::VkMessage::ContentDataMention).new

    text = String.build do |io|
      message_data.each do |data|
        if data.is_a?(Turnir::Parsing::VkMessage::ContentDataText) && data.type == "text" && !data.content.empty?
          begin
            io << Array(JSON::Any).from_json(data.content)[0].to_s
          rescue ex
            log "Failed to parse content data: #{ex.inspect}"
            log "Content: #{data.inspect}"
          end
        end
        if data.is_a?(Turnir::Parsing::VkMessage::ContentDataMention) && data.type == "mention"
          mentions << data
        end
      end
    end

    # log "text: #{text}"
    text = text.strip
    if text.empty?
      return nil
    end

    username = parsed.push.pub.data.data.author.displayName
    user_id = parsed.push.pub.data.data.author.id
    created_at = parsed.push.pub.data.data.createdAt
    message_id = parsed.push.pub.data.data.id

    return Turnir::ChatStorage::Types::ChatMessage.from_vk_message(
      message: parsed,
      text: text,
      mentions: mentions,
    )
  end

  def send_login(vk_token : String)
    @@message_counter += 1
    login_message = {
      "connect" => {"token" => vk_token, "name" => "js"},
      "id" => @@message_counter,
    }
    @@websocket.try { |ws| ws.send(login_message.to_json) }
  end

  def subscribe_to_channel(channel_name : String)
    channel_id = get_vk_channel_id(channel_name)
    if channel_id.nil?
      log "Failed to get channel id for #{channel_name}"
      return
    end

    channel = "channel-chat:#{channel_id}"
    Turnir::Client::ChannelMapper.set_vk_channel(channel_name, channel)
    send_subscribe(channel)
  end

  def send_subscribe(channel : String)
    log("Subscribing to #{channel}")

    @@message_counter += 1
    subscribe_message = {
      "subscribe" => {"channel" => channel},
      "id" => @@message_counter,
    }
    @@websocket.try { |ws| ws.send(subscribe_message.to_json) }
  end

  def stop
    @@websocket.try { |ws| ws.close }
  end

  struct VkAppConfig
    include JSON::Serializable
    property websocket : VkAppConfigWebsocket
  end

  struct VkAppConfigWebsocket
    include JSON::Serializable
    property token : String
  end

  def get_vk_app_config
    response = HTTP::Client.get "https://live.vkvideo.ru/"
    parsed = XML.parse_html(response.body)
    node = parsed.document.xpath_node("/html/body/script[@id='app-config']")
    node.try { |node| VkAppConfig.from_json node.content }
  end

  struct VkChannelInfo
    include JSON::Serializable
    property data : VkChannelInfoData
  end

  struct VkChannelInfoData
    include JSON::Serializable
    property owner : VkChannelInfoOwner
  end

  struct VkChannelInfoOwner
    include JSON::Serializable
    property id : Int32
    property name : String
    property nick : String
  end

  def get_vk_channel_id(name : String) : Int32 | Nil
    url = CHANNEL_INFO_URL.gsub("{{name}}", name)
    response = HTTP::Client.get url
    begin
      parsed = VkChannelInfo.from_json(response.body)
      return parsed.data.owner.id
    rescue ex
      log "Failed to get channel for #{name} exception: #{ex.inspect}"
      log "Response: #{response.body.inspect}"
      return nil
    end
  end
end
