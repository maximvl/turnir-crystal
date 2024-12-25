require "./message"

module Turnir::ChatStorage

  extend self

  VK_STORAGE = Storage.new
  TWITCH_STORAGE = Storage.new

  VKChannelsMap = {} of String => String

  class Storage
    property storage : Array(Turnir::ChatStorage::Types::ChatMessage)
    property storage_mutex : Mutex
    property last_access : Time

    # Storage = Array(Turnir::ChatStorage::Types::ChatMessage).new
    # StorageMutex = Mutex.new
    # @@last_access = Time.utc

    MESSAGES_LIMIT = 2000

    def initialize()
      @storage = [] of Turnir::ChatStorage::Types::ChatMessage
      @storage_mutex = Mutex.new
      @last_access = Time.utc
    end

    def add_message(msg : Turnir::ChatStorage::Types::ChatMessage)
      @storage_mutex.synchronize do
        @storage << msg
        if @storage.size > MESSAGES_LIMIT
          @storage.shift
        end
      end
    end

    def get_messages(channel : String, since : Int32, text_filter : String)
      @last_access = Time.utc
      # puts "Fetching messages for #{channel}"
      # puts "Messages: #{Storage.size}"
      @storage_mutex.synchronize do
        @storage.select { |msg| msg.channel == channel && msg.ts >= since && msg.message.downcase().includes?(text_filter)  }
      end
    end

    def clear
      @storage_mutex.synchronize do
        @storage.clear
      end
    end

    def should_stop_websocket?
      @last_access + 30.minutes < Time.utc
    end
  end

  def get_vk_channel_id(channel_name : String) : String | Nil
    VKChannelsMap[channel_name]?
  end

  def set_vk_channel_id(channel_name : String, channel_id : String)
    VKChannelsMap[channel_name] = channel_id
  end
end
