require 'amqp'

EventMachine.run do
  connection = AMQP.connect(:host => '127.0.0.1')
  puts "Connecting to RabbitMQ. Running #{AMQP::VERSION} version of the gem..."

  ch  = AMQP::Channel.new(connection)
  q   = ch.queue("com.smpp_gateway.bulk.receiver")
  x   = ch.default_exchange

  q.subscribe do |metadata, payload|
    puts "Received a message: #{payload}. Disconnecting..."

    connection.close {
      EventMachine.stop { exit }
    }
  end
end