class ChannelFactory
  
  def self.create(channel_name)
    c = Class.new() do
      include Celluloid
      attr_reader :timer
      
      def initialize(config)
        @options = config
      end
      
      def connect_queues(connection)
        @connection = connection
        
        @helper = AmqpHelper.new(@connection)
        @helper.subscribe(@options['activemq_topic_sender'], durable: true) do |metadata, payload|
          process_message(payload)
        end
      end
      
      def process_message(msg)
        begin
          msg_parsed = JSON.parse(msg)
          if msg_parsed['type'] == "1"
            DaemonKit.logger.debug " Received message type: 1"
            send_sms(msg_parsed['body']);
          elsif msg_parsed['type'] == "2"
            DaemonKit.logger.debug "Received message type: 2 with #{msg_parsed['body'].size} SMS"
            msg_parsed['body'].each do |msg_to_send|
              send_sms(msg_to_send)
              sleep(1.0/$config['configuration']['delay_per_second']) # Evita que se vayan más mensajes por segundo
            end
          end
        rescue Exception => e
          puts e.inspect
        end
      end
      
      def response_ok(message)
        unless message['id'].nil? || message['id'] == ""
          puts "hola"
          @helper.publish({id: message['id'], status: "ACK_DAEMON"}.to_json, :routing_key => @options['activemq_topic_response'], :persistent => true, :content_type => 'text/json') do |connection|
            puts "Response is ok!"
          end
        end
      end
      
      def prepare_dlr_url(app, msg_id)
        "http://localhost:#{$config['configuration']['dlr_port']}/?type=%d&error=%A&id=#{msg_id}&app=#{app}"
      end
      
      def insert_msg_to_storage(options, msg)
        registro = Sender.create(from: @options['short_number'], to: msg['cellphone'], message: msg['message'], app: @options['name'], status: 'PENDING', id_message: msg['id'])
        response_ok(msg)
        @options['mongo_id'] = registro.id
        registro
      end
      
      def status_kannel_process(options, msg, dlr)
        status = "PENDING"
        @kannel = EM::Kannel.new(username: @options['kannel_user'], password: @options['kannel_pass'], url: @options['kannel_url'], :dlr_mask => $config['configuration']['dlr_mask'], :dlr_callback_url => dlr)
        @kannel.send_sms(from: @options['short_number'], to: msg['cellphone'],body: msg['message']) do |response|
          if response.success?
            sended = Sender.find(@options['mongo_id'])
            sended.status = 'SUCCESS'
            sended.save
          end
        end
        @kannel = nil
        status
      end
      
      def send_sms(msg)
        begin
          registro = insert_msg_to_storage(@options, msg)
          dlr = prepare_dlr_url(@options['name'], msg['id'])
          registro.status = status_kannel_process(@options, msg, dlr)
          registro.save
        rescue Exception => e
          puts e.inspect
        end
      end
    end
    
    Kernel.const_set "#{channel_name.capitalize}Channel", c
  end
end