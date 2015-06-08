# to compile
# rbx compile -s '^lib:lib-compiled' lib/
class ReceiverInbox
  VERSION = 1.0
  PARAMETERS = [:from, :to, :message, :incoming_at]

  def self.clean_number(cellphone)
    URI.unescape(cellphone).gsub(/^\+595/, '0').gsub(/^\+09/, '09')
  end

  def self.clean_message(data)
    CGI.unescape(data.to_s)
  end

  def self.sanitize_options
    PARAMETERS.each do |item|
      if item == :from || item == :to
        @options[item] = ReceiverInbox.clean_number(@options[item])
      else
        @options[item] = ReceiverInbox.clean_message(@options[item])
      end
    end
  end

  def self.set_channel
    @channel = $config['configuration']['channels'].find {|inner_hash| @options[:to] == inner_hash['short_number'] && Regexp.new(inner_hash["receiver_expression"]).match(@options[:message].downcase)}
    @channel = $config['configuration']['channels'].find {|inner_hash| @options[:to] == inner_hash['short_number'] && inner_hash["default"] == 1} if @channel.nil?
  end

  def self.perform(args)
    @options = OptparseReceiver.parse(args)
    ReceiverInbox.sanitize_options
    ReceiverInbox.set_channel
    Commander.run(@options)

    EventMachine.run do
      status = 'SUCCESS'
      helper = AmqpHelper.new($amq)
      message = @options.keep_if{|key, value| key != :delivery_report && key != :metadata}
      begin
        helper.publish(message.to_json, :routing_key => @channel['activemq_topic_receiver'], :persistent => true, :content_type => 'text/json') do |connection|
          EventMachine.stop { exit }
        end
      rescue
        status = 'ERROR1'
        helper.close_connection do
          EventMachine.stop { exit }
        end
      ensure
        Receiver.create(from: message[:from], to: message[:to], message: message[:message], app: @channel['name'].downcase, status: status, incoming_at: message[:incoming_at], delivery_report_value: @options[:delivery_report], metadata_tlv: @options[:metadata])
      end
    end
  end
end
