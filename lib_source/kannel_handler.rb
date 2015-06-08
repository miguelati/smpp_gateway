class ParamsError < StandardError
end

class SenderIdNotExists < StandardError
end

class KannelHandler
  ERRORS = [
    {code: '0x00000401', status: 'NACK_SMSC_NO_MONEY', description: 'La linea de Personal no tiene saldo.', retry: 1},
    {code: '0x0000000b', status: 'NACK_SMSC_INVALID_NUMBER', description: 'La linea de Personal debe ser dada de baja pues no existe.', retry: 0},
    {code: '0x00000000', status: 'ACK_SMSC', description: 'Operacion exitosa.', retry: 0},
    {code: '0x00000402', status: 'NACK_SMSC_NO_USERDATA', description: 'No se pudo obtener datos del abonado.', retry: 0},
    {code: '0x00000406', status: 'NACK_SMSC_GENERIC_ERROR', description: 'Excepcion Generica.', retry: 0}
  ]
  PARAMS_REQUIRED = ['id', 'type', 'error', 'app']

  def logger(type, opt={})
    error_text = "Class=KannelHandler," + opt.map {|k, v| k.to_s + "=" + v }.join(",")
    DaemonKit.logger.send(type, error_text)
  end

  def http200(message)
    logger('info', status: "HTTP 200 / #{message}")
    [200, {"Content-Type" => "text/html"}, [message]]
  end

  def http403
    logger('info', status: 'Error HTTP 403')
    [403, {"Content-Type" => "text/html"}, ["Acceso denegado!"]]
  end

  def call(env)
    req = Rack::Request.new(env)
    logger('info', status: 'Request begin!', params: req.params.inspect)
    begin
      process(req.params)
    rescue ParamsError => e
      logger('error', 'error' => e.to_s)
      http403
    rescue SenderIdNotExists => e
      http200('Id no válido')
    rescue Exception => e
      logger('error', 'error' => e.to_s)
      http403
    end
  end

  def process(params)
    params_ok?(params)
    status = get_status(params['type'], params['error'])
    sender_update(status, params)
    send_response_message(status, params['app'], params['id']) unless params['id'].nil? && params['id'] == ""
    http200('ACK')
  end

  def sender_update(status, options = {})
    sender = Sender.where(id_message: options['id'], app: options['app']).first
    raise SenderIdNotExists, "No existe el id" if sender.nil?
    sender.dlr = Dlr.new(type: options['type'], error: options['error'], message_id: options['id'], app: options['app'])
    sender.status = status
    sender.save
  end

  def get_status(type, error)
    error_selected = ERRORS.select { |err| err[:code] == error.split("/")[1] }
    if type == '1' || type == '8'
      "ACK_SMSC"
    elsif !error_selected.empty?
      error_selected[0][:status]
    else
      "NACK_SMSC"
    end
  end

  def params_ok?(params)
    PARAMS_REQUIRED.each do |val|
      raise ParamsError, "Missing params requireds" if params[val] == "" || params[val].nil?
    end
  end

  def send_response_message(status, app, message_id)
    channel = $config['configuration']['channels'].find {|inner_hash| inner_hash["name"] == app}
    if channel['remote_kannel_response'].nil?
      send_to_amq({id: message_id, status: status}, channel['activemq_topic_response'])
    else
      remote_kr = channel['remote_kannel_response']
      request_remote(remote_kr['url'], {remote_kr['param_id'].to_sym => message_id, remote_kr['param_status'].to_sym => convert_status(status)}, remote_kr['ok_response'])
    end
  end

  def request_remote(url, query_string, check_response) # Usar bajo tu propia responsabilidad!
    begin
      logger('error', error: 'check_response no coincide en el request') unless HTTParty.get(url, query: query_string) == check_response
    rescue Exception => e
      logger('error', error: e.to_s)
    end
  end

  def send_to_amq(msg, queue)
    $amq = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/amqp.yml"))
    $amq = $amq[ENV['DAEMON_ENV']].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

    if queue != ""
      EventMachine.run do
        helper = AmqpHelper.new($amq)
        begin
          helper.publish(msg.to_json, :routing_key => queue, :persistent => true, :content_type => 'text/json') do |connection|
            logger('info', 'status' => "Sended OK! message: #{msg.inspect}")
            connection.close {
              EventMachine.stop { exit }
            }
          end
        rescue Exception => e
          logger('error', 'error' => e.to_s)
          helper.close_connection do
            EventMachine.stop { exit }
          end
        end
      end
    end
  end
end