# If you need to 'vendor your gems' for deploying your daemons, bundler is a
# great option. Update this Gemfile with any additional dependencies and run
# 'bundle install' to get them all installed. Daemon-kit's capistrano
# deployment will ensure that the bundle required by your daemon is properly
# installed.
#
# For more information on bundler, please visit http://gembundler.com

source 'https://rubygems.org'

# daemon-kit
gem 'daemon-kit', '~> 0.3.1'

# safely (http://github.com/kennethkalmer/safely)
gem 'safely'
# gem 'toadhopper' # For reporting exceptions to hoptoad
# gem 'mail' # For reporting exceptions via mail
gem 'amqp'
gem 'multi_json', '1.8.1'
gem "em-kannel"
gem 'celluloid'
gem 'mongoid', '~> 3.1.6'
gem 'activesupport', '~> 3.2'
gem 'timers'
gem 'rack'
gem "mongrel", "~> 1.2.0.pre2"
gem 'god'
gem 'rufus-scheduler', '~> 2.0.3'
gem 'rubysl'
gem 'simple_router'
gem 'httparty'
gem 'tzinfo', '~> 0.3.29'

group :development, :test do
  gem 'rake'
  gem 'rspec'
  gem 'guard', '~> 2.6.1'
  gem 'guard-shell'
end
