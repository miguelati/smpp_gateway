class Retry
  @delay = "10 "
  def self.find_sms_enqueued
    puts "hola"
    puts $config.inspect
    Sender.where(:status.nin => ['SUCCESS']).limit(10).each do |reg|
      
    end
    puts "fin"
  end
end