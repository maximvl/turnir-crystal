require "./vk_client"
require "./twitch_client"
require "./nuum_client"
require "./goodgame_client"

module Turnir::Client
  extend self

  enum ClientType
    VKVIDEO
    TWITCH
    NUUM
    GOODGAME
  end

  alias ClientModule = Turnir::Client::VkWebsocket | Turnir::Client::TwitchWebsocket | Turnir::Client::NuumPolling | Turnir::Client::GoodgameWebsocket

  def log(msg)
    print "[Client] "
    puts msg
  end

  enum ConnectionStatus
    DISCONNECTED
    CONNECTING
    CONNECTED
  end

  STREAMS_STATUS_MAP = Hash(String, ConnectionStatus).new
  STREAMS_STATUS_MAP_MUTEX = Mutex.new

  class Client
    property client_type : ClientType
    property mod : ClientModule
    property fiber : Fiber | Nil = nil
    property ready_channel = Channel(Nil).new(0)
    property mutex = Mutex.new
    property storage = Turnir::ChatStorage::Storage.new
    property channels_map = {} of String => String

    def initialize(client_type : ClientType, mod : ClientModule)
      @client_type = client_type
      @mod = mod
    end
  end

  CLIENTS = {
    ClientType::VKVIDEO  => Client.new(ClientType::VKVIDEO, Turnir::Client::VkWebsocket),
    ClientType::TWITCH   => Client.new(ClientType::TWITCH, Turnir::Client::TwitchWebsocket),
    ClientType::NUUM     => Client.new(ClientType::NUUM, Turnir::Client::NuumPolling),
    ClientType::GOODGAME => Client.new(ClientType::GOODGAME, Turnir::Client::GoodgameWebsocket),
  }

  def ensure_client_running(client_type : ClientType)
    client = CLIENTS[client_type]
    client.mutex.synchronize do
      if client.fiber.nil? || client.fiber.try &.dead?
        client.fiber = spawn do
          client.mod.start(client.ready_channel, client.storage, client.channels_map)
        end
        client.ready_channel.receive
      end
    end
  end

  def get_messages(client_type : ClientType, channel : String, since : Int64, text_filter : String)
    client = CLIENTS[client_type]
    ensure_client_running(client_type)

    # log "Getting messages for #{channel} #{client.channels_map}"

    channel_internal = client.channels_map.fetch(channel, nil)
    if channel_internal.nil?
      return nil
    end

    client.storage.get_messages(channel_internal, since, text_filter)
  end

  def get_connections_statuses
    STREAMS_STATUS_MAP.map { |k, v| [k.downcase, v.to_s.downcase] }.to_h
  end

  def clear_messages(client_type : ClientType)
    client = CLIENTS[client_type]
    client.storage.clear
  end

  def client_auto_stopper
    loop do
      CLIENTS.each do |client_type, client|
        if client.storage.should_stop?
          client.mod.stop
          client.storage.clear
          client.fiber = nil
          clear_streams_statuses_for_client(client_type)
        end
      end

      sleep 60.seconds
    end
  end

  def subscribe_to_channel(client_type : ClientType, channel_name : String)
    client = CLIENTS[client_type]
    client.mod.subscribe_to_channel(channel_name)
  end

  def update_stream_status(stream_name : String, status : ConnectionStatus)
    current_status = get_stream_status(stream_name)
    if current_status == status
      return
    end
    STREAMS_STATUS_MAP_MUTEX.synchronize do
      STREAMS_STATUS_MAP[stream_name] = status
    end
  end

  def get_stream_status(stream_name : String) : ConnectionStatus
    STREAMS_STATUS_MAP.fetch(stream_name, ConnectionStatus::DISCONNECTED)
  end

  def clear_streams_statuses_for_client(client_type : ClientType)
    STREAMS_STATUS_MAP_MUTEX.synchronize do
      STREAMS_STATUS_MAP.reject! do |stream_name, _|
        stream_name.downcase.starts_with?(client_type.to_s.downcase)
      end
    end
  end
end
