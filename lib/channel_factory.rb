require 'celluloid/autostart'
require 'em-kannel'
require 'json'

class ChannelFactory
  def self.create(channel_name)
    c = Class.new() do
      include Celluloid
      attr_reader :timer
      
      def initialize(config)
        @options = config
        @kannel = EM::Kannel.new(username: @options['kannel_user'], password: @options['kannel_pass'], url: @options['kannel_url'])
        DaemonKit.logger.debug "Author: #{self.class.to_s} initialized"
      end
      
      def connect_queues
        @sender = AMQP::Channel.new
        @sender.queue(@options['activemq_topic_sender'], auto_delete: true).subscribe do |msg|
          process_message(msg)
        end
        
        @receiver = AMQP::Channel.new
        test = @receiver.fanout("smpp_gateway.subscribe", auto_delete: true)
        @receiver.queue(@options['activemq_topic_receiver']).bind(test).subscribe do |msg|
          puts msg.inspect
        end
      end
      
      def process_message(msg)
        DaemonKit.logger.debug "Received message"
        msg_parsed = JSON.parse(msg)
        if msg_parsed['type'] == "1"
          DaemonKit.logger.debug "Message type: 1"
          send_sms(msg_parsed['body']);
        elsif msg_parsed['type'] == "2"
          DaemonKit.logger.debug "Message type: 2 with #{msg_parsed['body'].size} SMS"
          msg_parsed['body'].each do |msg_to_send|
            send_sms(msg_to_send)
          end
        end
        
      end
      
      def send_sms(msg)
        begin
          @kannel.send_sms(from: @options['short_number'], to: msg['cellphone'],body: msg['message']) do |response|
            if response.success?
              Sender.create(from: @options['short_number'], to: msg['cellphone'], message: msg['message'], app: @options['name'].downcase, status: 'success')
            else
              #if msg['tryed'].nil? || msg['tryed'] != true
                #@timer = after(60 * 10){
                #  msg['tryed'] = true
                #  send_sms(msg)
                #  @timer.reset
                #  puts "entro"
                #}
                #else
                Sender.create(from: @options['short_number'], to: msg['cellphone'], message: msg['message'], app: @options['name'].downcase, status: 'failed')
                #end
            end
          end
        rescue Exception => e
          puts e.inspect
        end
      end
    end
    Kernel.const_set "#{channel_name.capitalize}Channel", c
  end
end