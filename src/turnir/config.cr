module Turnir::Config
  extend self

  ROADHOUSE_CHAT = "channel-chat:6367818"
  LASQA_CHAT = "channel-chat:8845069"

  def webserver_ip
    ENV.fetch("IP", "127.0.0.1")
  end

  def webserver_port
    ENV.fetch("PORT", "8080").to_i
  end

  def vk_chat_id
    ENV.fetch("VK_CHAT_ID", LASQA_CHAT)
  end
end
