require "json"
require "xml"
require "http/client"
require "./turnir/config"
require "./turnir/webserver/utils"
require "process"

sig = <<-EOS
GHN+b5y+WZrINaINuVC7JGrK5C/AbGTybhvnrKAQTGQa4yxJoqIvMmbXiG1+W7vQou1DlGghKYhiPCbNu06vnZmfilQRTaa34PtCalcZPT6EKiH8qehNut2Lm6SBhVyKohRCedF5uqXMK0Saqq2bLHdtpxjBZrVFWNBYzGU1xjTx/A3fOGgjuiDF8/x7NwhKvCW51B997Hw350rW3lY3UaJeAEYCb+OQTnYLyLBQDfASU1F4KzRK7EbRILrYI+rUZd4yXcE+3pDVEv1f25VItw8W36Zc9sHjJJfr4vN7fwiCS4v0AO9FpMsN7zCMWzaMqWswIp3d023JuyQJALupbQ==
EOS

body = <<-EOS
01JVWMSYEHQFCS2YK1GJ5KX7A1.2025-05-22T18:41:33Z.{"message_id":"33c4beea-b6df-4f15-8762-7d1d430d00c3","broadcaster":{"is_anonymous":false,"user_id":1365215,"username":"Praden","is_verified":false,"profile_picture":"https://dbxmjjzl5pc1g.cloudfront.net/68417caf-7cdd-43e3-8a65-c6d605e1b881/images/user-profile-pic.png","channel_slug":"praden","identity":null},"sender":{"is_anonymous":false,"user_id":48882306,"username":"mapcdr","is_verified":false,"profile_picture":"","channel_slug":"mapcdr","identity":{"username_color":"#72ACED","badges":[]}},"content":"+лото","emotes":null}
EOS

# puts Turnir::Webserver::Utils.verify_kick_signature(body, sig)

# Escape variables for shell safety
escaped_signed_message = body.gsub("'", "'\\''")
escaped_signature_b64 = sig.gsub("'", "'\\''")
escaped_public_key_pem = Turnir::Webserver::Utils::KICK_PUBLIC_KEY_STRING

# Execute the command
puts "command start: #{Time.utc.to_unix_ms}"
output = IO::Memory.new
status = Process.run("bash", args: ["-c", command], output: output, shell: true)
puts "command end: #{Time.utc.to_unix_ms}"

# Check the result
if status.success? && output.to_s.includes?("Verified OK")
  puts "Signature is valid."
else
  puts "Signature verification failed."
end

exit 0

time_str = "2025-05-13T17:17:06.16633+00:00"
time = Time.parse(time_str, "%Y-%m-%dT%H:%M:%S.%6N%z", Time::Location::UTC)
puts time
puts time.to_unix_ms

exit 0

puts "0.5".to_f
now = Time.utc
puts "now: #{now}"
sleep "1.5".to_f.seconds
puts "diff: #{Time.utc - now}"

exit 0

require "./turnir/parser/kick"

struct Test1
  include JSON::Serializable
  property field1 : String
  property field2 : Int32
end

struct Test2
  include JSON::Serializable
  property field1 : String
  property field3 : String
end

struct TestData
  include JSON::Serializable
  property items : Array(Test1 | Test2)
end

puts TestData.from_json(
  %<{"items":[{"field1":"test", "field2":5}, {"field1":"test", "field3": "x"}]}>
).inspect

exit 0

response = HTTP::Client.get "https://www.kinopoisk.ru/film/196604"
puts response.status_code
puts response.body
parsed = XML.parse_html(response.body)
puts parsed
node = parsed.document.xpath_node("//*span[@data-tid='75209b22']")
puts node
puts node.try &.content

exit 0

r = Random.new
puts r.urlsafe_base64(6)

exit 0

response = HTTP::Client.get "https://live.vkplay.ru"

parsed = XML.parse_html(response.body)
node = parsed.document.xpath_node("/html/body/script[@id='app-config']")

exit 0

puts ENV.fetch("var", nil)

module Test
  extend self
  @@my_x = 5

  def get_x
    @@my_x
  end

  def set_x(x : Int32)
    @@my_x = x
  end
end

puts Test.get_x
Test.set_x(10)
puts Test.get_x
exit 0

x = spawn do
  puts "before 1"
  sleep 3
  puts "after 1"
end

puts x.dead?

sleep 1

puts x.dead?

sleep 1

exit(0)

class TwoFields
  include JSON::Serializable

  def initialize(@field1 : String, @field2 : Int32)
  end
end

# puts TwoFields.from_json("{\"fild1\":\"abc\",\"field2\":5, \"field3\":10}").inspect
puts typeof(JSON.parse("[5]"))

exit(0)

def caller(arg1 : String)
  puts "caller"
  puts arg1
end

map = {
  /^\/turnir-api\/votes$/       => ->caller(String),
  /^\/turnir-api\/votes\/(.+)$/ => ->caller(String),
}

path = "/turnir-api/votes/abc"

match = map.each.find do |k, v|
  path.match(k)
end

if match
  match[1].call(path)
end
