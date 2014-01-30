# to compile
# rbx compile -s '^lib:lib-compiled' lib/

$config = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/configurations.yml"))
$amq = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/amqp.yml"))
$amq = $amq['defaults'].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
Mongoid.load!("#{File.dirname(__FILE__)}/../config/mongoid.yml", :production)

Dir["#{File.dirname(__FILE__)}/../models/*.rb"].each {|file| require file }

class ReceiverInbox
  VERSION = 1.0
  def self.perform(args)
    options = OptparseReceiver.parse(args)
    Commander.run(options)
    channel = $config['configuration']['channels'].find {|inner_hash| Regexp.new(inner_hash["receiver_expression"]).match(options[:message].downcase)}
    channel = $config['configuration']['channels'].find {|inner_hash| inner_hash["default"] == 1} if channel.nil?
    
    EventMachine.run do
      
      begin
        connection = AMQP.connect($amq)

        ch  = AMQP::Channel.new(connection)
        q   = ch.queue(channel['activemq_topic_receiver'], :durable => true)
        x   = ch.default_exchange

        x.publish options.to_json, :routing_key => q.name, :persistent => true do
          connection.close {
            Receiver.create(from: options[:from], to: options[:to], message: options[:message], app: channel['name'].downcase, status: 'success', incoming_at: options[:incoming_at], delivery_report_value: options[:delivery_report], metadata_tlv: options[:metadata])
            EventMachine.stop { exit }
          }
        end
      rescue
        Receiver.create(from: options[:from], to: options[:to], message: options[:message], app: channel['name'].downcase, status: 'error', incoming_at: options[:incoming_at], delivery_report_value: options[:delivery_report], metadata_tlv: options[:metadata])
        connection.close {
          EventMachine.stop { exit }
        }
      end
    end
  end
end
