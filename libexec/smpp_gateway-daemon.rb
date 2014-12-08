# Generated amqp daemon
# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...
DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  config.trap('INT') do
    # do something clever
    $pid.each { |pid| Process.kill('KILL', pid) }
  end
  config.trap( 'TERM', Proc.new { $pid.each {|pid| Process.kill('KILL', pid); Safely::Backtrace.safe_shutdown! } } )
end

$pid = []
#Receiver for kannel message
$pid << fork do

  Signal.trap("HUP") { exit }
  $config = DaemonKit::Config.load('configurations')
  app_kannel_handler = Rack::Builder.new do
    use  Rack::MailExceptions do |mail|
      mail.to 'miguel.godoy@me.com'
      mail.from 'miguelgodoyg@gmail.com'
      mail.subject '[KannelHandler] %s'
      mail.smtp $config['configuration']['smtp_settings']
    end
    run KannelHandler.new
  end

  begin
    Rack::Handler.get(:unicorn).run app_kannel_handler, :Port => $config['configuration']['dlr_port'], :config_file => DAEMON_ROOT
  rescue Exception => e
    DaemonKit.logger.error e.inspect
  end
end

# Timer for tasks
$pid << fork do
  Rubinius::CodeLoader.require_compiled 'retry'
  Signal.trap("HUP") { exit }

  DaemonKit::Cron.scheduler.every("1m") do
    #DaemonKit.logger.debug "Scheduled task completed at #{Time.now}"
    Retry.find_sms_enqueued
  end

  DaemonKit::Cron.run
end

# API Server
if $config['configuration']['api_server_enabled']
  $pid << fork do
    Rubinius::CodeLoader.require_compiled 'api_server'
    Signal.trap("HUP") { exit }
    $config = DaemonKit::Config.load('configurations')

    app_api_server = Rack::Builder.new do
      use  Rack::MailExceptions do |mail|
        mail.to 'miguel.godoy@me.com'
        mail.from 'miguelgodoyg@gmail.com'
        mail.subject '[KannelHandler] %s'
        mail.smtp $config['configuration']['smtp_settings']
      end
      run ApiServer.new
    end

    begin
      Rack::Handler.get(:unicorn).run app_api_server, :Port => $config['configuration']['api_server_port'], :config_file => DAEMON_ROOT
    rescue Exception => e
      DaemonKit.logger.error e.inspect
    end
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

end