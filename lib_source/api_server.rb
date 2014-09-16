class ApiServer
  include SimpleRouter::DSL

  post '/send' do |params|
    unless params['num'].nil? && params['msg'].nil?
      message = ApiServer.prepare_json(params)
      DaemonKit.logger.info "[KANNEL API] #{message.inspect}"
      to_queue = ApiServer.get_channel(params)

      ApiServer.send_message(message, to_queue)

    else
      "500"
    end
  end

  def self.send_message(message, queue)
    if queue.nil?
      "500"
    else
      ApiServer.to_amq(message, queue)
      "200"
    end
  end

  def self.get_channel(params)
    if @@channel.count > 1 && !params['channel'].nil?
      aux = @@channel.find do |inner|
        inner['name'].downcase == params['channel'].downcase
      end
      aux['activemq_topic_sender'] unless aux.nil?
    else
      @@channel[0]['activemq_topic_sender']
    end
  end

  def self.prepare_json(params)
    if params['num'].kind_of?(Array)
      body = []
      params['num'].each do |item|
        body << {cellphone: item["num"], message: params['msg'], id: item["id"]}
      end
      {body: body, type: "2"}
    else
      {body: {cellphone: params['num'], message: params['msg'], id: params['id']}, type: "1"}
    end
  end

  def self.to_amq(message, queue)
    $amq = YAML::load(File.open("#{File.dirname(__FILE__)}/../config/amqp.yml"))
    $amq = $amq[ENV['DAEMON_ENV']].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    if queue != ""
      EventMachine.run do
        helper = AmqpHelper.new($amq)
        begin
          helper.publish(message.to_json, :routing_key => queue, :persistent => true) do |connection|
            connection.close {
              EventMachine.stop { exit }
            }
          end
        end
      end
    end
  end

  def self.authentication(env)
    tmp = $config['configuration']['channels'].select do |inner_hash|
      inner_hash['api_server']['enabled'] == true
    end
    channel = tmp.select do |inner_hash|
      user = inner_hash['api_server']['users'].find do |inner|
        inner['name'] == env['HTTP_API_USER'] && inner['pass'] == env['HTTP_API_PASS']
      end
      if user.nil?
        false
      else
        user.count > 0
      end
    end
    channel
  end

  def call(env)
    @@channel = ApiServer.authentication(env)
    if @@channel.nil? || @@channel.count == 0
      [404, {'Content-Type' => 'text/html'}, ['404 page not found']]
    else
      request = Rack::Request.new(env)

      # TODO: Modificación para que valide el usuario

      verb = request.request_method.downcase.to_sym
      path = Rack::Utils.unescape(request.path_info)

      route = self.class.routes.match(verb, path)
      route.nil? ?
        [404, {'Content-Type' => 'text/html'}, ['404 page not found']] :
        [200, {'Content-Type' => 'text/html'}, [route.action.call(*route.values.push(request.params))]]
    end
  end
end