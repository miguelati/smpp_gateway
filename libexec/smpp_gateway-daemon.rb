# Generated amqp daemon
# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...


$pid = fork do
  require 'kannel_handler'
  Signal.trap("HUP") { puts "Fork finnish"; exit}
  $config = DaemonKit::Config.load('configurations')
  
  begin
    Rack::Handler::Mongrel.run KannelHandler.new, :Port => $config['configuration']['dlr_port']
  rescue Exception => e
    puts e
  end
  
end

DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  config.trap( 'INT' ) do
    # do something clever
    Process.kill("HUP", $pid)
    #puts "termino!!"
  end
  #config.trap( 'TERM', Proc.new { puts 'chau!' } )
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



