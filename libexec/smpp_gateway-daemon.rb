# Generated amqp daemon
# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...
DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  config.trap('INT') do
    # do something clever
    $pid.each { |pid| Process.kill('KILL', pid) }
    #puts "termino!!"
  end
  config.trap( 'TERM', Proc.new { $pid.each {|pid| Process.kill('KILL', pid) } } )
end

$pid = []
#Receiver for kannel message
$pid[0] = fork do
  require 'kannel_handler'
  #Rubinius::CodeLoader.require_compiled 'kannel_handler'
  Signal.trap("HUP") { puts "Fork finnish"; exit}
  $config = DaemonKit::Config.load('configurations')
  
  begin
    Rack::Handler::Mongrel.run KannelHandler.new, :Port => $config['configuration']['dlr_port']
  rescue Exception => e
    puts e
  end
end

# Timer for tasks
$pid[1] = fork do
  require 'retry'
  #Rubinius::CodeLoader.require_compiled 'retry'
  Signal.trap("HUP") { puts "Fork finnish"; exit}
  
  DaemonKit::Cron.scheduler.every("1m") do
    #DaemonKit.logger.debug "Scheduled task completed at #{Time.now}"
  end
  
  DaemonKit::Cron.run
  
end

# API Server
$pid[2] = fork do
  require 'api_server'
  #Rubinius::CodeLoader.require_compiled 'api_server'
  Signal.trap("HUP") { puts "Fork finnish"; exit}
  $config = DaemonKit::Config.load('configurations')
  
  begin
    Rack::Handler::Mongrel.run ApiServer.new, :Port => $config['configuration']['api_server']['port']
  rescue Exception => e
    puts e
  end
end

# IMPORTANT CONFIGURATION NOTE
#
# Please review and update 'config/amqp.yml' accordingly or this
# daemon won't work as advertised.

# Run an event-loop for processing
DaemonKit::AMQP.run do |connection|
  # Inside this block we're running inside the reactor setup by the
  # amqp gem. Any code in the examples (from the gem) would work just
  # fine here.

  # Uncomment this for connection keep-alive
  # connection.on_tcp_connection_loss do |client, settings|
  #   DaemonKit.logger.debug("AMQP connection status changed: #{status}")
  #   client.reconnect(false, 1)
  # end

  # amq = AMQP::Channel.new
  # amq.queue('test').subscribe do |msg|
  #   DaemonKit.logger.debug "Received message: #{msg.inspect}"
  # end
  
  $config['configuration']['channels'].size.times do |inx|
    $supervisor.actors[inx].connect_queues(connection)
  end
  #$supervisor.actors[$config['configuration']['channels'].size].process
  
end



