require 'yaml'
require 'mongoid'

# Be sure to restart your daemon when you modify this file

Dir["#{File.dirname(__FILE__)}/../models/*.rb"].each {|file| require file }

# Uncomment below to force your daemon into production mode
#ENV['DAEMON_ENV'] ||= 'production'
ENV['DAEMON_ENV'] ||= 'development'

# Boot up
require File.join(File.dirname(__FILE__), 'boot')

# Auto-require default libraries and those for the current ruby environment.
Bundler.require :default, DaemonKit.env
$config = DaemonKit::Config.load('configurations')

DaemonKit::Initializer.run do |config|

  # The name of the daemon as reported by process monitoring tools
  config.daemon_name = 'smpp_gateway'

  # Force the daemon to be killed after X seconds from asking it to
  config.force_kill_wait = 100

  # Log backraces when a thread/daemon dies (Recommended)
  config.backtraces = true
end
