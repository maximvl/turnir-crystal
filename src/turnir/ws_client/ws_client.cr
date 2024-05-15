require "json"
require "xml"
require "http/client"

require "./chat_message"
require "../vote_storage"

module Turnir::WSClient
  extend self

  WS_URL = "wss://pubsub.live.vkplay.ru/connection/websocket?cf_protocol_version=v2"
  Headers = HTTP::Headers{"Origin" => "https://live.vkplay.ru"}

  @@websocket : HTTP::WebSocket | Nil = nil
  WebsocketMutex = Mutex.new

  def log(msg)
    print "[WSClient] "
    puts msg
  end

  struct VoteMessage
    include JSON::Serializable

    property id : Int32
    property text : String
    property user_id : Int32
    property user_name : String
    property timestamp : Int32

    def initialize(@id : Int32, @text : String, @user_id : Int32, @user_name : String, @timestamp : Int32)
    end
  end

  def start
    app_config = get_vk_app_config
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
        handle_message(parsed)
      end
    end

    websocket.on_close do |code|
      log "Websocket Closed: #{code}"
      @@websocket = nil
    end

    log "Starting websocket"
    send_initial_messages(app_config.websocket.token)
    websocket.run
    @@websocket = nil
  end

  def parse_message(json_message)
    begin
      parsed = ChatMessage.from_json(json_message)
    rescue ex
      log "Failed to parse message: #{ex.inspect}"
      return nil
    end

    # log "Parsed: #{parsed.inspect}"
    # return nil

    if parsed.push.pub.data.type != "message"
      return
    end

    message_data = parsed.push.pub.data.data.data

    text = String.build do |io|
      message_data.each do |data|
        if data.type == "text"
          io << Array(JSON::Any).from_json(data.content)[0].to_s
        end
      end
    end

    # log "text: #{text}"

    user_name = parsed.push.pub.data.data.author.displayName
    user_id = parsed.push.pub.data.data.author.id
    created_at = parsed.push.pub.data.data.createdAt
    message_id = parsed.push.pub.data.data.id

    return VoteMessage.new(
      id: message_id,
      text: text,
      user_id: user_id,
      user_name: user_name,
      timestamp: created_at,
    )
  end

  def handle_message(message : VoteMessage)
    log "Vote Message: #{message.inspect}"
    Turnir::VoteStorage.add_vote message
  end

  def send_initial_messages(vk_token : String)
    login_message = {
      "connect" => {"token" => vk_token, "name" => "js"},
      "id" => 1,
    }
    @@websocket.try { |ws| ws.send(login_message.to_json) }

    subscribe_message = {
      "subscribe" => {"channel" => "channel-chat:6367818"},
      "id" => 2,
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
    response = HTTP::Client.get "https://live.vkplay.ru"
    parsed = XML.parse_html(response.body)
    node = parsed.document.xpath_node("/html/body/script[@id='app-config']")
    node.try { |node| VkAppConfig.from_json node.content }
  end
end
