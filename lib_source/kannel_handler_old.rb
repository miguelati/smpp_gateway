class KannelHandler
  def call(env)
    req = Rack::Request.new(env)
    DaemonKit.logger.info "[kannel handler] Request params type => #{req.params['type']} | error => #{req.params['error']} | id => #{req.params['id']} | app => #{req.params['app']}"
    DaemonKit.logger.info "Params => " + req.params.inspect
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
      DaemonKit.logger.info "Reject without param 'id'"
      [200, {"Content-Type" => "text/html"}, ["No se encuentra!"]]
    end
  end

  def get_status(type, error)
    DaemonKit.logger.info "ERROR #{error.inspect}"
    if type == '1' || type == '8'
      "SUCCESS"
    elsif error != false && error[:retry] == 1
      "RETRY"
    elsif error != false && error[:code] == '0x0000000B'
      "INVALID_NUMBER"
    elsif error != false && error[:code] == '0x00000401'
      "NO_MONEY"
    elsif error != false && error[:code] == '0x00000402'
      "NO_USERDATA"
    elsif error != false && error[:code] == '0x00000406'
      "GENERIC_ERROR"
    else
      "ERROR"
    end
  end

  def parse_error(error)
    stack_errors = [
      {code: '0x00000401', description: 'La linea de Personal no tiene saldo.', retry: 1},
      {code: '0x0000000B', description: 'La linea de Personal debe ser dada de baja pues no existe.', retry: 0},
      {code: '0x00000000', description: 'Operacion exitosa.', retry: 0},
      {code: '0x00000402', description: 'No se pudo obtener datos del abonado.', retry: 0},
      {code: '0x00000406', description: 'Excepcion Generica.', retry: 0}
    ]
    finded = stack_errors.select{ |el| el[:code] == error.split("/")[1] }
    if finded.nil? || finded.length == 0
      false
    else
      finded[0]
    end
  end

  def convert_status(status)
    if status == "SUCCESS"
      "ACK_SMSC"
    elsif status != "RETRY" && status != 'ERROR'
      "NACK_SMSC_" + status
    else
      "NACK_SMSC"
    end
  end

  def update_status_in_store(status, type, error)
    @sender_reg.status = status
    @sender_reg.save
    send_response_message(status, @sender_reg.app, @sender_reg.id_message) unless @sender_reg.id_message.nil? && @sender_reg.id_message == ""
  end

  def params_is_ok?(params)
    if params['type'] != "" || params['error'] != "" || params['id'] != "" || params['app'] != ""
      true
    else
      false
    end
  end

  def send_response_message(status, app, message_id)
    channel = $config['configuration']['channels'].find {|inner_hash| inner_hash["name"] == app}
    if channel['remote_kannel_response'].nil?
      send_to_amq({id: message_id, status: convert_status(status)}, channel['activemq_topic_response'])
    else
      remote_kr = channel['remote_kannel_response']
      request_remote(remote_kr['url'], {remote_kr['param_id'].to_sym => message_id, remote_kr['param_status'].to_sym => convert_status(status)}, remote_kr['ok_response'])
    end
  end

  def request_remote(url, query_string, check_response) # Usar bajo tu propia responsabilidad!
    DaemonKit.logger.info "[KANNEL HANDLER] response"
    response_ok = false
    delay = 10
    try_send = 3

    while response_ok == false
      begin
        response = HTTParty.get(url, query: query_string)

        if response.to_s == check_response
          response_ok = true
        else
          if try_send > 0
            sleep(try_send)
            try_send -= 1
          end
        end
      rescue Exception => e
        sleep(try_send)
        try_send -= 1
      end
    end
  end

  def send_to_amq(msg, queue)
    $amq = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/amqp.yml"))
    $amq = $amq[ENV['DAEMON_ENV']].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    DaemonKit.logger.info "[KANNEL HANDLER] amqp"

    if queue != ""
      EventMachine.run do
        helper = AmqpHelper.new($amq)
        begin
          helper.publish(msg.to_json, :routing_key => queue, :persistent => true, :content_type => 'text/json') do |connection|
            connection.close {
              EventMachine.stop { exit }
            }
          end
        rescue Exception => e
          DaemonKit.logger.error e.inspect
          helper.close_connection do
            @sender_reg.status = "ERROR_RESPONSE"
            @sender_reg.save
            DaemonKit.logger.info "[KANNEL HANDLER] amqp error"
            EventMachine.stop { exit }
          end
        end
      end

    end
  end
end