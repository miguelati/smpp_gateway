class IdUniqueError < StandardError;end

class MessageExpired < StandardError;end

class KannelFailed < StandardError;end

class ChannelFactory

  def self.create(channel_name)
    c = Class.new() do
      include Celluloid
      attr_reader :timer

      def initialize(config)
        @options = config
      end

      def logger(type, opt={})
        log_content = "Class=ChannelFactory," + opt.map {|k, v| k.to_s + "=" + v }.join(",")
        DaemonKit.logger.send(type, log_content)
      end

      def send_status(sms, status)
        unless sms['id'].nil? || sms['id'] == ""
          begin
            @helper.publish({id: sms['id'], status: status}.to_json, :routing_key => @options['activemq_topic_response'], :persistent => true, :content_type => 'text/json') do |connection|
              logger('info', 'Status' => "AMQ Message: {id: #{sms['id']}, status: #{status}}")
            end
          rescue Exception => e
            logger('error', 'Status' => 'Error on \'send_status\'', 'Error' => e.to_s)
          end
        end
      end

      def send_status_from_original(status)
        if @message_original['type'] == '1'
          send_status(@message_original['body'], status)
        else
          @message_original['body'].each {|sms| send_status(sms, status)}
        end
      end

      def connect_queues(connection)
        @connection = connection

        @helper = AmqpHelper.new(@connection)
        @helper.subscribe(@options['activemq_topic_sender'], durable: true) do |metadata, payload|
          @message_raw = payload
          process_message
        end
      end

      def check_message_expired
        raise MessageExpired, "This message are expired!" unless @message_original['expire_in'].nil? || Time.parse(@message_original['expire_in']) > Time.now
      end

      def process_message
        begin
          @message_original = JSON.parse(@message_raw)
          logger('info','Status' => 'MessageReceived', 'Type' => @message_original['type'])
          check_message_expired
          analize_to_send
        rescue MessageExpired => e
          logger('info','Status' => 'MessageExpired', 'ExpireIn' => @message_original['expire_in'])
          send_status_from_original('NACK_DAEMON_EXPIRED')
        rescue Exception => e
          logger('error', 'Status' => 'ErrorProcessMessage', 'Exception' => e.to_s, 'backtrace' => e.backtrace.to_s)
          send_status_from_original('NACK_DAEMON')
        end
      end

      def analize_to_send
        sms_to_send = []
        if @message_original['type'] == '1'
          sms_to_send << clean_message(@message_original['body'])
        else
          @message_original['body'].each {|only_sms| sms_to_send << clean_message(only_sms) }
        end
        sms_to_send.each { |sms| send_sms(sms) }
      end

      def prepare_dlr_url(sms)
        "http://localhost:#{$config['configuration']['dlr_port']}/?type=%d&error=%A&id=#{sms['id']}&app=#{@options['name']}"
      end

      def insert_msg_to_storage(sms)
        @mongo_row = Sender.create(from: @options['short_number'], to: sms['cellphone'], message: sms['message'], app: @options['name'], status: 'PENDING', id_message: sms['id'])
        logger('debug', 'Status' => 'Save row on [MongoDB.Senders]')
      end

      def prepare_message(message)
        message.gsub(/[^\P{C}\n]+/u,'').tr('áéíóúñÁÉÍÓÚÑ”“', 'aeiounAEIOUN""')
      end

      def prepare_cellphone(cellphone)
        cellphone.strip.gsub(/[^0987654321 +-]/, '')
      end

      def clean_message(sms)
        {'id' => sms['id'], 'cellphone' => prepare_cellphone(sms['cellphone']),'message' => prepare_message(sms['message'])}
      end

      def status_kannel_process(sms)
        logger('info', 'sms' => sms.inspect)
        @kannel = Server::Kannel.new(username: @options['kannel_user'], password: @options['kannel_pass'], url: @options['kannel_url'], :dlr_mask => $config['configuration']['dlr_mask'], :dlr_callback_url => prepare_dlr_url(sms))
        @kannel.send_sms(from: @options['short_number'], to: sms['cellphone'],body: sms['message']) do |response|
          if response.success?
            @mongo_row.status = 'SUCCESS'
          else
            @mongo_row.status = 'ERROR'
            send_status(sms, 'NACK_DAEMON')
          end
          @mongo_row.save
          logger('info', 'Status' => "kannel report status: #{@mongo_row.status}")
        end
      end

      def check_if_unique(sms)
        raise IdUniqueError, "This id: #{sms['id']} not unique" if Sender.where(id_message: sms['id'], app: @options['name']).count > 0
      end

      def send_sms(sms)
        begin
          check_if_unique(sms)
          send_status(sms, 'ACK_DAEMON')
          insert_msg_to_storage(sms)
          status_kannel_process(sms)
        rescue IdUniqueError => e
          logger('error', 'Status' => 'ErrorProcessMessage', 'Exception' => e.to_s)
          send_status(sms, 'NACK_DAEMON_DUPLICATED_ID')
        end
      end
    end

    Kernel.const_set "#{channel_name.capitalize}Channel", c
  end
end