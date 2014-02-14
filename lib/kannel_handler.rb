
class KannelHandler
  def call(env)    
    req = Rack::Request.new(env)
    puts "[kannel handler] Request params type => #{req.params['type']} | error => #{req.params['error']} | id => #{req.params['id']} | app => #{req.params['app']}"
    Dlr.create(type: req.params['type'], error: req.params['error'], message_id: req.params['id'], app: req.params['app'])
    if params_is_ok?(req.params)
      process(req)
    else
      [403, {"Content-Type" => "text/html"}, ["Acceso denegado!"]]
    end
  end
  
  def process(req)
    @sender_reg = Sender.where(id_message: req.params['id'], app: req.params['app']).first
    puts @sender_reg.inspect
    if @sender_reg != nil
      #if req.params['type'] == '1' || req.params['type'] == '8'
        status = "SUCCESS"
      #else
      #    status = retry_correlation(@sender_reg.status)
      #end
      update_status_in_store(status, req.params['type'], req.params['error'])
    
      [200, {"Content-Type" => "text/html"}, ["ACK"]]
    else
      [404, {"Content-Type" => "text/html"}, ["No se encuentra!"]]
    end
    
  end
  
  def retry_correlation(status)
    if status == "RETRY1"
      "RETRY2"
    elsif status == "RETRY2"
      "RETRY3"
    elsif status == "RETRY3" || status == "ERROR"
      "ERROR"
    end
  end
  
  def convert_status(status)
    if status == "SUCCESS"
      "ACK_SMSC"
    else
      "NACK_SMSC"
    end
  end
  
  def update_status_in_store(status, type, error)
    @sender_reg.status = status
    @sender_reg.dlr_type = type
    @sender_reg.dlr_error = error
    @sender_reg.save
    send_to_amq(status, @sender_reg.app, @sender_reg.id_message)
  end
  
  def params_is_ok?(params)
    if params['type'] != "" || params['error'] != "" || params['id'] != "" || params['app'] != ""
      true
    else
      false
    end
  end
  
  def send_to_amq(status, app, msg_id)
    puts "amq process"
    $amq = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/amqp.yml"))
    $amq = $amq[ENV['DAEMON_ENV']].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    channel = $config['configuration']['channels'].find {|inner_hash| inner_hash["name"] == app}
    
    if channel != ""
      EventMachine.run do
        helper = AmqpHelper.new($amq)
        begin
          helper.publish({id: msg_id, status: convert_status(status)}.to_json, :routing_key => channel['activemq_topic_response'], :persistent => true, :content_type => 'text/json') do |connection|
            connection.close {
              EventMachine.stop { exit }
            }
          end
        rescue
          helper.close_connection do
            @sender_reg.status = "ERROR_RESPONSE"
            @sender_reg.save
            EventMachine.stop { exit }
          end
        end
      end
      
    end
    
  end
end