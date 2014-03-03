# to compile
# rbx compile -s '^lib:lib-compiled' lib/
class ReceiverInbox
  VERSION = 1.0
  def self.perform(args)
    options = OptparseReceiver.parse(args)
    Commander.run(options)
    channel = $config['configuration']['channels'].find {|inner_hash| Regexp.new(inner_hash["receiver_expression"]).match(options[:message].downcase)}
    channel = $config['configuration']['channels'].find {|inner_hash| inner_hash["default"] == 1} if channel.nil?
    
    EventMachine.run do
      status = 'SUCCESS'
      helper = AmqpHelper.new($amq)
      begin
        
        message = {}
        message[:from] = URI.unescape(options[:from]).gsub(/^\+/, '')
        message[:to] = URI.unescape(options[:to]).gsub(/^\+595/, '0')
        message[:message] = CGI.unescape(options[:message])
        message[:incoming_at] = CGI.unescape(options[:incoming_at].to_s)
        
        helper.publish(message.to_json, :routing_key => channel['activemq_topic_receiver'], :persistent => true, :content_type => 'text/json') do |connection|
          EventMachine.stop { exit }
        end
      rescue
        status = 'ERROR1'
        helper.close_connection do
          EventMachine.stop { exit }
        end
      ensure
        Receiver.create(from: message[:from], to: message[:to], message: message[:message], app: channel['name'].downcase, status: status, incoming_at: message[:incoming_at], delivery_report_value: options[:delivery_report], metadata_tlv: options[:metadata])
      end
    end
  end
end
