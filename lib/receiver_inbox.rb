# to compile
# rbx compile -s '^lib:lib-compiled' lib/

$config = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/configurations.yml"))
$amq = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/amqp.yml"))

Mongoid.load!("#{File.dirname(__FILE__)}/../config/mongoid.yml", :development)

Dir["#{File.dirname(__FILE__)}/../models/*.rb"].each {|file| require file }

class ReceiverInbox
  VERSION = 1.0
  def self.perform(args)
    options = OptparseReceiver.parse(args)
    channel = $config['configuration']['channels'].find {|inner_hash| Regexp.new(inner_hash["receiver_expression"]).match(options[:message].downcase)}
    channel = $config['configuration']['channels'].find {|inner_hash| inner_hash["default"] == 1} if channel.nil?
    
    Receiver.create(from: options[:from], to: options[:to], message: options[:message], app: channel['name'].downcase, status: 'success', incoming_at: options[:incoming_at], delivery_report_value: options[:delivery_report], metadata_tlv: options[:metadata])
    
    EventMachine.run do
      connection = AMQP.connect($amq['default'])

      ch  = AMQP::Channel.new(connection)
      q   = ch.queue(channel['activemq_topic_receiver'])
      x   = ch.default_exchange

      x.publish options.to_json, :routing_key => q.name do
        connection.close {
          EventMachine.stop { exit }
        }
      end
    end
  end
end
