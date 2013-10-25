# If you need to 'vendor your gems' for deploying your daemons, bundler is a
# great option. Update this Gemfile with any additional dependencies and run
# 'bundle install' to get them all installed. Daemon-kit's capistrano
# deployment will ensure that the bundle required by your daemon is properly
# installed.
#
# For more information on bundler, please visit http://gembundler.com

source 'https://rubygems.org'

# daemon-kit
gem 'daemon-kit'

# safely (http://github.com/kennethkalmer/safely)
gem 'safely'
# gem 'toadhopper' # For reporting exceptions to hoptoad
# gem 'mail' # For reporting exceptions via mail
gem 'amqp'
gem 'multi_json', '1.8.1'
gem "em-kannel"
gem 'celluloid'
gem 'mongoid'
gem 'activesupport', '3.1.12'
gem 'rubysl-enumerator'
gem 'rubysl-rexml'

group :development, :test do
  gem 'rake'
  gem 'rspec' 
end