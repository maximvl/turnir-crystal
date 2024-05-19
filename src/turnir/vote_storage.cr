require "./ws_client/ws_client"

module Turnir::VoteStorage
  extend self

  Storage = Array(Turnir::WSClient::VoteMessage).new
  StorageMutex = Mutex.new
  @@last_access = Time.utc

  def add_vote(vote)
    StorageMutex.synchronize do
      Storage << vote
    end
  end

  def get_votes(since : Int32)
    @@last_access = Time.utc
    StorageMutex.synchronize do
      Storage.select { |vote| vote.ts >= since }
    end
  end

  def clear
    StorageMutex.synchronize do
      Storage.clear
    end
  end

  def should_stop_websocket?
     @@last_access + 15.minutes < Time.utc
  end
end
