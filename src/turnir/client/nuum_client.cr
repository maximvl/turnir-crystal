require "json"
require "http/client"

require "../parser/nuum"

module Turnir::Client::NuumPolling
  extend self

  @@message_counter = 0

  HEADERS = HTTP::Headers{
    "Origin"       => "https://nuum.ru",
    "Accept"       => "application/json",
    "Content-Type" => "application/json",
  }

  PUBLIC_CHANNEL_URL = "https://nuum.ru/api/v2/broadcasts/public?channel_name={{channel}}"
  CHAT_URL           = "https://nuum.ru/api/v3/chats?contentType={{type}}&contentId={{id}}"

  EVENTS_URL = "https://nuum.ru/api/v3/events/{{chat_id}}/events"

  @@storage : Turnir::ChatStorage::Storage | Nil = nil
  @@stop_flag = Atomic(Int32).new(0)

  SUBSCRIBED_CHATS = Set(String).new

  @@channels_map = {} of String => String

  LAST_TS_PER_CHAT = {} of String => String

  def log(msg : String)
    print "[NuumPolling] "
    puts msg
  end

  def start(sync_channel : Channel(Nil), storage : Turnir::ChatStorage::Storage, channels_map : Hash(String, String))
    @@storage = storage
    @@channels_map = channels_map

    sync_channel.send(nil)
    loop do
      SUBSCRIBED_CHATS.each do |chat|
        fetch_events(chat)
      end

      if @@stop_flag.get == 1
        log "Stopping Nuum client"
        break
      end

      sleep 2.seconds
    end
  end

  def subscribe_to_channel(channel_name : String)
    chat_id = get_chat_id(channel_name)
    if chat_id.nil?
      log "Failed to get chat id for #{channel_name}"
      return
    end
    channel = chat_id.to_s
    @@channels_map[channel_name] = channel
    SUBSCRIBED_CHATS << channel
  end

  def get_chat_id(channel_name : String) : Int32 | Nil
    channel_url = PUBLIC_CHANNEL_URL.sub("{{channel}}", channel_name)
    resporse = HTTP::Client.get(channel_url, headers: HEADERS)

    begin
      parsed = Turnir::Parser::Nuum::ChannelResponse.from_json(resporse.body)
    rescue ex
      log "Failed to get media container: #{ex.inspect} #{resporse.body}"
      return nil
    end

    container_id = parsed.result.media_container.media_container_id
    container_type = parsed.result.media_container.media_container_type

    chat_url = CHAT_URL.sub("{{type}}", container_type).sub("{{id}}", container_id.to_s)
    chat_response = HTTP::Client.get(chat_url, headers: HEADERS)

    begin
      parsed = Turnir::Parser::Nuum::ChatResponse.from_json(chat_response.body)
    rescue ex
      log "Failed to get chat id: #{ex.inspect} #{chat_response.body}"
      return nil
    end

    parsed.result.id
  end

  def fetch_events(chat_id : String)
    events_url = EVENTS_URL.sub("{{chat_id}}", chat_id)

    last_5_mins = Time.utc - 5.minutes

    # Format in this way 2024-12-28T14:56:49.691Z
    last_5_mins = last_5_mins.to_s("%Y-%m-%dT%H:%M:%S.%LZ")

    body = {
      "timestampStart" => LAST_TS_PER_CHAT.fetch(chat_id, last_5_mins),
      "sort"           => "ASC",
      "eventTypes"     => ["MESSAGE"],
    }

    response = HTTP::Client.post(events_url, headers: HEADERS, body: body.to_json)

    # log "Events url: #{events_url}, body #{body.to_json}"

    begin
      parsed = Turnir::Parser::Nuum::EventsResponse.from_json(response.body)
    rescue ex
      log "Failed to get events: #{ex.inspect} #{response.body}"
      return
    end

    # log "Fetched events: #{parsed.result}"

    parsed.result.each do |event|
      chat_message = Turnir::ChatStorage::Types::ChatMessage.from_nuum_message(event, channel: chat_id)
      @@storage.try { |s| s.add_message(chat_message) }
      LAST_TS_PER_CHAT[chat_id] = event.timestamp
    end
  end

  def stop
    SUBSCRIBED_CHATS.clear
    @@stop_flag.set(1)
    LAST_TS_PER_CHAT.clear
  end
end
