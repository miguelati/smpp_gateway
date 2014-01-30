class Retry
  def self.process
    while do
      now = DateTime.now - Rational(30, 1440)
      
      Sender.where(:updated_at.gt => )
      
      $config['configuration']['time_to_retry']
      # waiting time configured in yml
      sleep(60)
    end
  end
end