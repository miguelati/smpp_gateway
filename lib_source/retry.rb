class Retry
  @delay = 1 # seconds
  def self.find_sms_enqueued
    $amq = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/amqp.yml"))
    #$amq = $amq['production'].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    $amq = $amq['development'].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    
    body = []
    
    Sender.where(:status.in => ['RETRY1', 'RETRY2', 'RETRY3']).limit(10).each do |reg|
      #{"body":{"cellphone":"0981460196","message":"Test of bulk", "id": "123"},"type":"1", "expire_in":"10/04/2014 18:20:00"}
      message = {body: {cellphone: reg.to, message: reg.message, id: reg.id_message, app: reg.app}, type: "1", expire_id: (Time.now + (2*60*60)).strftime("%d/%m/%Y %H:%M:%S") }
      queue = "com.smpp_gateway.#{reg.app.downcase}.sender"
      
      EventMachine.run do
        helper = AmqpHelper.new($amq)

        begin
          helper.publish(message.to_json, :routing_key => queue, :persistent => true) do |connection|
            connection.close {
              reg.status = 'RESENDED'
              reg.save
              EventMachine.stop { exit }
            }
          end
        end
      end
      sleep @delay
    end
  end
end