# Safely is responsible for providing exception reporting and the
# logging of backtraces when your daemon dies unexpectedly. The full
# documentation for safely can be found at
# http://github.com/kennethkalmer/safely/wiki


# By default Safely will use the daemon-kit's logger to log exceptions,
# and will store backtraces in the "log" directory.

# Comment out to enable Hoptoad support
# Safely::Strategy::Hoptoad.hoptoad_key = ""

# Comment out to use email exceptions
require 'safely'
require 'mail'

Safely::Backtrace.trace_directory = "#{File.dirname(__FILE__)}/../../log/"
Safely::Backtrace.enable!

Safely::Strategy::Mail.recipient = "miguel.godoy@me.com"
Safely::Strategy::Mail.sender = "miguelgodoyg@gmail.com"
Safely::Strategy::Mail.subject_prefix = "[SAFELY]"

Mail.defaults do
  delivery_method :smtp, {
    :address => 'smtp.gmail.com',
    :port => '587',
    :user_name => 'miguelgodoyg@gmail.com',
    :password => 'Mm16u3l4t1@@17##',
    :authentication => :plain,
    :enable_starttls_auto => true
  }
end