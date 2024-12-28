module Turnir::Client::ChannelMapper
  extend self

  VKChannelsMap = {} of String => String

  def get_vk_channel(channel_name : String) : String | Nil
    VKChannelsMap[channel_name]?
  end

  def set_vk_channel(channel_name : String, channel_id : String)
    VKChannelsMap[channel_name] = channel_id
  end

  NUUMChannelsMap = {} of String => String

  def get_nuum_channel(channel_name : String) : String | Nil
    NUUMChannelsMap[channel_name]?
  end

  def set_nuum_channel(channel_name : String, channel_id : String)
    NUUMChannelsMap[channel_name] = channel_id
  end

end
