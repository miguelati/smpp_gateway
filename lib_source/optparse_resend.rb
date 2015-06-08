class OptparseResend

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

      opts.on('-t', '--to TO', "Id of message received") do |t|
        options[:to] = t
      end
      opts.on('-f', '--from FROM', 'Id of message received') do |f|
        options[:from] = f
      end
      opts.on('-a', '--application APPLICATION', 'Application to resend') do |m|
        options[:application] = m
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