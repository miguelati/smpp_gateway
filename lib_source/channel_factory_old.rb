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
          if msg_parsed['type'] == "1" && ((!msg_parsed['expire_in'].nil? && DateTime.parse(msg_parsed['expire_in']) > DateTime.now) || msg_parsed['expire_in'].nil?)
            DaemonKit.logger.info " Received message type: 1"
            send_sms(msg_parsed['body']);
          elsif msg_parsed['type'] == "2"
            DaemonKit.logger.info "Received message type: 2 with #{msg_parsed['body'].size} SMS"
            msg_parsed['body'].each do |msg_to_send|
              send_sms(msg_to_send)
              sleep(1.0/$config['configuration']['delay_per_second']) # Evita que se vayan más mensajes por segundo
            end
          end
          DaemonKit.logger.info "Finish send message"
        rescue Exception => e
          DaemonKit.logger.error e.inspect
        end
      end

      def response_ok(message)
        unless message['id'].nil? || message['id'] == ""
          DaemonKit.logger.info "Intenta enviar al RAbbitMQ"
          begin
            @helper.publish({id: message['id'], status: "ACK_DAEMON"}.to_json, :routing_key => @options['activemq_topic_response'], :persistent => true, :content_type => 'text/json') do |connection|
              DaemonKit.logger.info "Response is ok!"
            end
          rescue Exception => e
            DaemonKit.logger.info e.inspect
          end

        end
      end

      def prepare_dlr_url(app, msg_id)
        "http://localhost:#{$config['configuration']['dlr_port']}/?type=%d&error=%A&id=#{msg_id}&app=#{app}"
      end

      def insert_msg_to_storage(options, msg)
        registro = Sender.create(from: @options['short_number'], to: msg['cellphone'], message: msg['message'], app: @options['name'], status: 'PENDING', id_message: msg['id'])
        DaemonKit.logger.info "prepare for rabbit"
        DaemonKit.logger.info msg.inspect
        response_ok(msg)
        @options['mongo_id'] = registro.id
        registro
      end

      def prepare_message(message)
        message.gsub(/[^\P{C}\n]+/u,'').tr('áéíóúÁÉÍÓÚ', 'aeiouAEIOU').gsub(/ñ/,'n').gsub(/Ñ/,'N').gsub(/”/, "\"").gsub(/“/,"\"")
      end

      def prepare_cellphone(cellphone)
        cellphone.strip.gsub(/[^0987654321 +-]/, '')
      end

      def clean_message(msg)
        {'id' => msg['id'], 'cellphone' => prepare_cellphone(msg['cellphone']),'message' => prepare_message(msg['message'])}
      end

      def status_kannel_process(options, msg, dlr)
        status = "PENDING"

        @kannel = Server::Kannel.new(username: @options['kannel_user'], password: @options['kannel_pass'], url: @options['kannel_url'], :dlr_mask => $config['configuration']['dlr_mask'], :dlr_callback_url => dlr)

        @kannel.send_sms(from: @options['short_number'], to: msg['cellphone'],body: msg['message']) do |response|
          sended = Sender.find(@options['mongo_id'])
          if response.success?
            DaemonKit.logger.info "Correct sended message"
            sended.status = 'SUCCESS'
          else
            DaemonKit.logger.info "Failed sended message"
            sended.status = 'RETRY'
          end
          sended.save
        end

        status
      end

      def send_sms(msg)
        begin
          msg = clean_message(msg)
          registro = insert_msg_to_storage(@options, msg)
          dlr = prepare_dlr_url(@options['name'], msg['id'])
          DaemonKit.logger.info "DLR INFO: ---> " + dlr
          registro.status = status_kannel_process(@options, msg, dlr)
          registro.save
        rescue Exception => e
          DaemonKit.logger.info e.inspect
        end
      end
    end

    Kernel.const_set "#{channel_name.capitalize}Channel", c
  end
end