require "./message"

module Turnir::ChatStorage
  extend self

  class Storage
    property storage : Array(Turnir::ChatStorage::Types::ChatMessage)
    property storage_mutex : Mutex
    property last_access : Time

    MESSAGES_LIMIT = 5000

    def initialize
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

    def get_messages(channel : String, since : Int64, text_filter : String)
      @last_access = Time.utc
      # puts "Fetching messages for #{channel}"
      # puts "Messages: #{Storage.size}"
      @storage_mutex.synchronize do
        @storage.select { |msg| msg.channel == channel && msg.ts >= since && msg.message.downcase.includes?(text_filter) }
      end
    end

    def clear
      @storage_mutex.synchronize do
        @storage.clear
      end
    end

    def should_stop?
      @last_access + 30.minutes < Time.utc
    end

    def get_last_message_ts(channel : String) : Int64
      @storage_mutex.synchronize do
        last_message = @storage.reverse.find { |msg| msg.channel == channel }
        if last_message
          last_message.ts
        else
          0
        end
      end
    end
  end
end
