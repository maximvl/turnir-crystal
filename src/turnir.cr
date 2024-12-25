require "./turnir/webserver"
require "./turnir/ws_client/vk_client"
require "./turnir/db_storage"

module Turnir
  extend self

  @@vk_websocket_fiber : Fiber | Nil = nil
  @@websocket_ready = Channel(Nil).new(0)
  @@websocket_mutex = Mutex.new

  def start_webserver
    Webserver.start
  end

  def ensure_websocket_running
    @@websocket_mutex.synchronize do
      if @@vk_websocket_fiber.nil? || @@vk_websocket_fiber.try &.dead?
        @@vk_websocket_fiber = spawn do
          WSClient::VkClient.start(@@websocket_ready)
        end
        @@websocket_ready.receive()
      end
    end
  end

  def websocket_watcher
    loop do
      if Turnir::ChatStorage::VK_STORAGE.should_stop_websocket? && @@vk_websocket_fiber
        puts "Stopping websocket"
        WSClient::VkClient.stop()
        @@vk_websocket_fiber = nil
        Turnir::ChatStorage::VK_STORAGE.clear()
      end
      sleep 60.seconds
    end
  end
end

Turnir::DbStorage.create_tables

# puts Turnir::DbStorage.save_preset Turnir::DbStorage::Preset.new(id: "tmp", title: "test", owner_id: "123", created_at: Time.utc.to_unix, updated_at: Time.utc.to_unix, options: ["1","2","3"])
# puts Turnir::DbStorage.get_preset "tmp"
# exit 0


spawn do
  Turnir.websocket_watcher
end

Turnir.start_webserver
