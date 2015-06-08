# to compile
# rbx compile -s '^lib:lib-compiled' lib/
class ResendQueue
  VERSION = 1.0
  def self.perform(args)
    options = OptparseReceiver.parse(args)

    channel = $config['configuration']['channels'].find {|inner_hash| options[:application] == inner_hash['name'] }

    if channel.empty?
      puts "App doesn't exist"
    else
      EventMachine.run do
        status = 'SUCCESS'
        helper = AmqpHelper.new($amq)
        begin

          Sender.where(:id_message.gte => options[:from], :id_message.lte => options[:to], :app => options[:application]).order_by(id_message: 1).all.each do |row|
            helper.publish({id: row['id_message'], status: 'ACK_DAEMON'}.to_json, :routing_key => channel['activemq_topic_response'], :persistent => true, :content_type => 'text/json')

            error = self.parse_error(row.dlr.error)
            status = self.get_status(row.dlr.type, error)

            helper.publish({id: row['id_message'], status: status}.to_json, :routing_key => channel['activemq_topic_response'], :persistent => true, :content_type => 'text/json')
          end

          helper.close_connection
          EventMachine.stop { exit }
        rescue
          puts "Ocurrió un error"
        end
      end
    end
  end

  private
  def self.get_status(type, error)
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

  def self.parse_error(error)
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
      finded
    end
  end
end
