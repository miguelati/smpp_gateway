#
# This is a configuration template for 'god' process monitoring.
#
# More information can be found at http://god.rubyforge.org/
#

DAEMON_ROOT = "/usr/share/smpp_gateway_prosur"

God.watch do |w|
  w.name = 'smpp_gateway'
  w.dir = DAEMON_ROOT
  w.interval = 30.seconds
  w.start = "/usr/bin/env DAEMON_ENV=production ./bin/smpp_gateway start"
  w.stop = "/usr/bin/env DAEMON_ENV=production ./bin/smpp_gateway stop"
  w.log = "#{DAEMON_ROOT}/log/god.log"
  w.start_grace = 10.seconds
  w.stop_grace = 10.seconds
  w.pid_file = "#{DAEMON_ROOT}/log/smpp_gateway.pid"
  w.behavior(:clean_pid_file)
  w.uid = 'root'
  w.gid = 'root'

  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 30.seconds
      c.running = false
      #c.notify = 'sysadmin'
    end
  end

  w.restart_if do |restart|
    restart.condition(:memory_usage) do |c|
      c.above = 250.megabytes
      c.times = [3, 5] # 3 out of 5 intervals
      #c.notify = 'sysadmin'
    end

    restart.condition(:cpu_usage) do |c|
      c.above = 50.percent
      c.times = 5
      #c.notify = 'sysadmin'
    end
  end

  w.lifecycle do |on|
    on.condition(:flapping) do |c|
      c.to_state = [:start, :restart]
      c.times = 5
      c.within = 5.minute
      c.transition = :unmonitored
      c.retry_in = 10.minutes
      c.retry_times = 5
      c.retry_within = 2.hours
      #c.notify = 'sysadmin'
    end
  end
  
end

