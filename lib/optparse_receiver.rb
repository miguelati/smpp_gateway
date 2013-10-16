require 'optparse'
require 'date'
require 'pp'

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
      
      opts.on('-t', '--to TO', "Number that receive the message") do |t|
        options[:to] = t
      end
      opts.on('-f', '--from FROM', 'Number that send the message') do |f|
        options[:from] = f
      end
      opts.on('-m', '--message MESSAGE', 'Message sended by the from number') do |m|
        options[:message] = m
      end
      opts.on('-i', '--incoming INCOMING', 'Datetime from incoming the message') do |i|
        options[:incoming_at] = DateTime.parse(i)
      end
      opts.on('--delivery_report DELIVERY_REPORT', 'data from the delivery report') do |dr|
        options[:delivery_report] = dr
      end
      opts.on('--encoding ENCODING', 'type of encoding message') do |en|
        options[:encoding] = en
      end
      opts.on('--metadata METADATA', 'metadata sended in the smpp message') do |me|
        options[:metadata] = me
      end
      opts.on('--billing BILLING', 'billing data for the SMS') do |bi|
        options[:billing] = bi
      end
      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
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

end  # class OptparseExample