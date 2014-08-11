class KannelHandler
  def call(env)    
    req = Rack::Request.new(env)
    DaemonKit.logger.info "[kannel handler] Request params type => #{req.params['type']} | error => #{req.params['error']} | id => #{req.params['id']} | app => #{req.params['app']}"
    if params_is_ok?(req.params)
      process(req)
    else
      [403, {"Content-Type" => "text/html"}, ["Acceso denegado!"]]
    end
  end
  
  def process(req)
    @sender_reg = Sender.where(id_message: req.params['id'], app: req.params['app']).first
    error = parse_error(req.params['error'])
    if @sender_reg != nil
      @sender_reg.dlr = Dlr.new(type: req.params['type'], error: req.params['error'], message_id: req.params['id'], app: req.params['app'])
      status = get_status(req.params['type'], error)
      update_status_in_store(status, req.params['type'], req.params['error'])
      [200, {"Content-Type" => "text/html"}, ["ACK"]]
    else
      [404, {"Content-Type" => "text/html"}, ["No se encuentra!"]]
    end
  end

  def get_status(type, error)
    if type == '1' || type == '8'
      "SUCCESS"
    elsif error != false && error[:retry] == 1
      "RETRY"
    elsif error != false && error[:code] == '0x0000000B'
      "INVALID_NUMBER"
    else
      "ERROR"
    end
  end

  def parse_error(error)
    stack_errors = [
      {code: '0x00000401', description: 'La linea de Personal no tiene saldo.', retry: 1},
      {code: '0x0000000B', description: 'La linea de Personal debe ser dada de baja pues no existe.', retry: 0},
      {code: '0x00000000', description: 'Operacion exitosa.', retry: 1},
      {code: '0x00000402', description: 'No se pudo obtener datos del abonado.', retry: 1},
      {code: '0x00000406', description: 'Excepcion Generica.', retry: 1}
    ]

    finded = stack_errors.select{ |el| el[:code] == error.split("/")[2] }
    if finded.nil? || finded.length == 0
      false
    else
      finded
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
    @sender_reg.save
    send_to_amq(status, @sender_reg.app, @sender_reg.id_message) unless @sender_reg.id_message.nil? && @sender_reg.id_message == ""
  end
  
  def params_is_ok?(params)
    if params['type'] != "" || params['error'] != "" || params['id'] != "" || params['app'] != ""
      true
    else
      false
    end
  end

  def send_response_message(status, app, message_id)
    send_to_amq(app, {id: message_id, status: convert_status(status)}, 'activemq_topic_response')
  end
  
  def send_to_amq(app, msg, queue)
    #puts "amq process"
    $amq = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/amqp.yml"))
    $amq = $amq[ENV['DAEMON_ENV']].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    channel = $config['configuration']['channels'].find {|inner_hash| inner_hash["name"] == app}
    
    if channel != ""
      EventMachine.run do
        helper = AmqpHelper.new($amq)
        begin
          helper.publish(msg.to_json, :routing_key => channel[queue], :persistent => true, :content_type => 'text/json') do |connection|
            connection.close {
              EventMachine.stop { exit }
            }
          end
        rescue Exception => e
          DaemonKit.logger.error e.inspectn
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