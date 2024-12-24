require "./message"

module Turnir::ChatStorage
  extend self

  Storage = Array(Turnir::ChatStorage::Types::ChatMessage).new
  StorageMutex = Mutex.new
  @@last_access = Time.utc

  VKChannelMap = {} of String => String

  MESSAGES_LIMIT = 2000

  def add_message(msg : Turnir::ChatStorage::Types::ChatMessage)
    StorageMutex.synchronize do
      Storage << msg
      if Storage.size > MESSAGES_LIMIT
        Storage.shift
      end
    end
  end

  def get_messages(channel : String, since : Int32, text_filter : String)
    @@last_access = Time.utc
    channel_id = get_vk_channel_id(channel)
    puts "Fetching messages for channel #{channel} ID: #{channel_id}"
    puts "Messages: #{Storage.size}"
    StorageMutex.synchronize do
      Storage.select { |msg| msg.channel == channel_id && msg.ts >= since && msg.message.downcase().includes?(text_filter)  }
    end
  end

  def clear
    StorageMutex.synchronize do
      Storage.clear
    end
  end

  def should_stop_websocket?
     @@last_access + 30.minutes < Time.utc
  end

  def get_vk_channel_id(channel_name : String) : String | Nil
    VKChannelMap[channel_name]?
  end

  def set_vk_channel_id(channel_name : String, channel_id : String)
    VKChannelMap[channel_name] = channel_id
  end

end
