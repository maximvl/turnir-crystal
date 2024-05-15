require "json"
require "xml"
require "http/client"

response = HTTP::Client.get "https://live.vkplay.ru"

parsed = XML.parse_html(response.body)
node = parsed.document.xpath_node("/html/body/script[@id='app-config']")
node.try { |n| puts (JSON.parse n.content).websocket.token }


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
  /^\/turnir-api\/votes$/ => ->caller(String),
  /^\/turnir-api\/votes\/(.+)$/ => ->caller(String),
}

path = "/turnir-api/votes/abc"

match = map.each.find do |k, v|
  path.match(k)
end

if match
  match[1].call(path)
end
