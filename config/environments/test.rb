# This is the same context as the environment.rb file, it is only
# loaded afterwards and only in the test environment
Mongoid.load!("#{File.dirname(__FILE__)}/../mongoid.yml", :test)