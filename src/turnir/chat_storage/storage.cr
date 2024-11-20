require "./message"

module Turnir::ChatStorage
  extend self

  Storage = Array(Turnir::ChatStorage::Types::ChatMessage).new
  StorageMutex = Mutex.new
  @@last_access = Time.utc

  def add_message(msg : Turnir::ChatStorage::Types::ChatMessage)
    StorageMutex.synchronize do
      Storage << msg
    end
  end

  def get_messages(since : Int32, text_filter : String)
    @@last_access = Time.utc
    StorageMutex.synchronize do
      Storage.select { |vote| vote.ts >= since && vote.message.includes?(text_filter) }
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

end
