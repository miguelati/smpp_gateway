# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.
require 'celluloid/autostart'
require 'em-kannel'
require 'json'
require 'rack'
require 'timers'
require 'amqp_helper'
require 'json'
require 'pathname'
require 'simple_router'

#Rubinius::CodeLoader.require_compiled 'channel_factory'
require 'channel_factory'
require 'kannel_handler'



$supervisor = Celluloid::SupervisionGroup.run!

$config['configuration']['channels'].each do |channel|
  ChannelFactory.create(channel['name'])
  
  $supervisor.pool(Object.const_get("#{channel['name'].capitalize}Channel"), as: "#{channel['name'].downcase}_channel".to_sym, args: [channel], size: channel['pool_size'])
  
end
