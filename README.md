daemon-kit README
================

daemon-kit has generated a skeleton Ruby daemon for you to build on. Please read
through this file to ensure you get going quickly.

Message to test (RabbitMQ Message)
=================================
{"body":{"cellphone":"0981460196","message":"Test of bulk", "id": "123"},"type":"1", "expire_in":"10/04/2014 18:20:00"}
{"body":{"cellphone":"0981460196","message":"Test of bulk", "id": "123"},"type":"1"}
{"body":{"message":"HOla llega el mensaje","cellphone":"0981714008"},"type":"1"}
{"body":[
  {"cellphone":"0981460196","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0971222540","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0985300043","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0981714008","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0971303196","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0981495681","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0971717273","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0971443227","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0971856056","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0982192051","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"},
    {"cellphone":"0971789293","message":"Respondan ok este mensaje cuando reciban por favor. Gracias"}
],"type":"2"}

Directories
===========

bin/
  smpp_gateway - Stub executable to control your daemon with

config/
  Environment configuration files

lib/
  Place for your libraries

libexec/
  smpp_gateway.rb - Your daemon code

log/
  Log files based on the environment name

spec/
  rspec's home

tasks/
  Place for rake tasks

vendor/
  Place for unpacked gems and DaemonKit

tmp/
  Scratch folder

Rake Tasks
==========

Note that the Rakefile does not load the `config/environments.rb` file, so if you have
environment-specific tasks (such as tests), you will need to call rake with the environment:

    DAEMON_ENV=staging bundle exec rake -T

Logging
=======

One of the biggest issues with writing daemons are getting insight into what your
daemons are doing. Logging with daemon-kit is simplified as DaemonKit creates log
files per environment in log.

On all environments except production the log level is set to DEBUG, but you can
toggle the log level by sending the running daemon SIGUSR1 and SIGUSR2 signals.
SIGUSR1 will toggle between DEBUG and INFO levels, SIGUSR2 will blatantly set the
level to DEBUG.

Bundler
=======

daemon-kit uses bundler to ease the nightmare of dependency loading in Ruby 
projects. daemon-kit and its generators all create/update the Gemfile in the
root of the daemon. You can satisfy the project's dependencies by running
`bundle install` from within the project root.

For more information on bundler, please see http://github.com/carlhuda/bundler
