class AmqpHelper
  def initialize(connection)
    @connection = set_connection(connection)
    @channel = AMQP::Channel.new(@connection)
  end
  
  
  def set_connection(connection)
    if connection.class.to_s == "AMQP::Session"
      connection
    elsif connection.is_a?(Hash)
      AMQP.connect(connection)
    end
  end
  
  def publish(message, options={})
    exchange = @channel.default_exchange
    
    @channel.on_error do |ch, close|
      DaemonKit.logger.error "Error on channel2: #{ch.inspect}, #{close.inspect}"
    end
    
    exchange.publish message, options do
      yield(@connection) if block_given?
    end
  end
  
  def subscribe(queue_name, options = {}, &block)
    @channel.queue(queue_name, options).subscribe do |metadata, payload|
      block.call(metadata, payload) if block_given?
    end
    @channel.on_error do |ch, close|
      DaemonKit.logger.error "Error on channel: #{close.reply_text}, #{close.inspect}"
    end
  end
  
  def close_connection
    unless @connection.nil?
      @connection.close {
        yield if block_given?
      }
    end
  end
end