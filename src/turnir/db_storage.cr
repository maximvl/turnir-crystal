require "mysql"
require "db"
require "./config"

module Turnir::DbStorage
  extend self

  DB = ::DB.open(Turnir::Config.database_url)

  def create_tables
    DB.exec(
      "CREATE TABLE IF NOT EXISTS chat_messages (" \
      "id BIGINT AUTO_INCREMENT PRIMARY KEY," \
      "created_at INT NOT NULL," \
      "message TEXT NOT NULL," \
      "username VARCHAR(255) NOT NULL," \
      "chat_name VARCHAR(255) NOT NULL" \
      ")"
    )
  end

  def save_message(created_at : Int32, message : String, username : String, chat_name : String)
    DB.exec(
      "INSERT INTO chat_messages (created_at, message, username, chat_name) VALUES (?, ?, ?, ?)",
      created_at, message, username, chat_name
    )
  end

  class ChatMessage
    include DB::Serializable

    @[DB::Field(key: "id", auto_increment: true)]
    property id : Int64

    @[DB::Field(key: "created_at")]
    property created_at : Int32

    @[DB::Field(key: "message")]
    property message : String

    @[DB::Field(key: "username")]
    property username : String

    @[DB::Field(key: "chat_name")]
    property chat_name : String
  end
end
