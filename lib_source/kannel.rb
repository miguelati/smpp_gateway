module Server
	module Validations
		def self.included(base)
			base.class_eval do
				include ActiveModel::Validations
			end
		end

		def validate!
			if invalid?
				message = "Invalid #{friendly_naem}: #{full_messages}"
				raise ArgumentError.new(message)
			end

			true
		end

		def friendly_name
			self.class.model_name.human
		end

		def full_message
			errors.full_messages.to_sentence
		end
	end

	class Configuration
		include Validations

		attr_accessor 	:username,
						:password,
						:url,
						:dlr_callback_url,
						:dlr_mask,
						:verify_ssl_peer,
						:smsc
		validates :username, presence: true
		validates :password, presence: true
		validates :url, presence: true

		def initialize(attributes={})
			attributes = attributes.with_indifferent_access

			self.username = attributes[:username]
			self.password = attributes[:password]
			self.url = attributes[:url]
			self.dlr_callback_url = attributes[:dlr_callback_url]
			self.dlr_mask = attributes[:dlr_mask]
			self.verify_ssl_peer = attributes[:verify_ssl_peer]
			self.smsc = attributes[:smsc]
		end

		def as_query
			query = {username: username, password: password}
			query[:"dlr-mask"] = dlr_mask if dlr_mask
			query[:"dlr-url"] = dlr_callback_url if dlr_callback_url
			query[:smsc] = smsc if smsc
			query
		end
	end

	class Message
		include Validations

		attr_accessor :body, :from, :to

		validates :body, presence: true, length: {maximum: (160 * 4)}
		validates :from, presence: true
		validates :to, presence: true

		def initialize(attributes={})
			attributes = attributes.with_indifferent_access

			self.from = attributes[:from]
			self.to = attributes[:to]
			self.body = attributes[:body]
		end

		def as_query
			{from: from, to: to, text: body}
		end
	end

	class Response
		attr_accessor :duration

		def initialize(http, start=nil)
			@http = http
			@duration = compute_duration(start)
		end

		def status
			@http.code
		end

		def success?
			status == 202
		end

		def body
			@http.response
		end

		def error
			@http.error
		end

		def guid
			body.split(": ").last
		end

		private

		def compute_duration(start)
			start && ((Time.now.to_f - start.to_f) * 1000.0).round
		end
	end

	class Client
		attr_accessor :message, :configuration

		def initialize(message, configuration)
			self.message = message
			self.configuration = configuration
		end

		def deliver(&block)
			start = Time.now.to_f
			http = HTTParty.get(configuration.url, query: query)

			callback(http, start, message, &block)
		end

		private

		def options
			#TODO: falta verificar esto!
			{ssl: {verify_ssl_peer: configuration.verify_ssl_peer}}
		end

		def query
			query = {}
			query.merge!(configuration.as_query)
			query.merge!(message.as_query)
		end

		def callback(http, start, message, &block)
			response = Response.new(http, start)

			block.call(response) if block_given?
		end
	end

	class Kannel
		attr_accessor :configuration

		def initialize(configuration_options={})
			self.configuration = Configuration.new(configuration_options)
		end

		def send_sms(message_options, &block)
			configuration.validate!
			message = Message.new(message_options)
			message.validate!
			
			client = Client.new(message, configuration)
			client.deliver(&block)
		end
	end
end