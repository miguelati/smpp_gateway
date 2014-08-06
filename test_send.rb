#!/usr/bin/env ruby
#require 'benchmark'
require 'optparse'
require 'date'
require 'amqp'
require 'uri'
require 'cgi'
require 'yaml'
require 'json'

require "#{File.dirname(__FILE__)}/lib_source/amqp_helper"

class OptparseReceiver

  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }

  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = {}

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: receiver [options]"

      opts.separator ""
      opts.separator "Specific options:"
      
      opts.on('-t', '--to TO', "Number that receive the message") do |value|
        options[:to] = value
      end
      
      opts.on('-m', '--msg MSG', "Message to send") do |value|
        options[:msg] = value
      end
      
      opts.on('-q', '--queue QUEUE', "Message to send") do |value|
        if value.nil? || value == ""
          options[:queue] = 'com.smpp_gateway.turnos.sender'
        else
          options[:queue] = value
        end
      end

      opts.separator ""
      opts.separator "Common options:"

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      # Another typical switch to print the version.
      opts.on_tail("--version", "Show version") do
        puts '1.0'
        exit
      end
    end

    opt_parser.parse!(args)
    options
  end  # parse()

end


options = OptparseReceiver.parse(ARGV);

$amq = YAML::load(File.open("#{File.dirname(__FILE__)}/config/amqp.yml"))
#$amq = $amq['production'].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
$amq = $amq['development'].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

num = options[:to].split(",")

body = []
num.each do |cel|
  body << {cellphone: cel, message: options[:msg]}
end

message = {body: (body * 500), type: "2"}

if options[:queue] != ""
  EventMachine.run do
    helper = AmqpHelper.new($amq)
    
    begin
      helper.publish(message.to_json, :routing_key => options[:queue], :persistent => true) do |connection|
        connection.close {
          puts "se envió bien!"
          EventMachine.stop { exit }
        }
      end
    end
  end
end