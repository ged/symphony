#!/usr/bin/env ruby

require 'bunny'
require 'loggability'
require 'configurability'

require 'groundcontrol' unless defined?( GroundControl )
require 'groundcontrol/mixins'


# An object class that encapsulates queueing logic for GroundControl jobs.
class GroundControl::Queue
	extend Loggability,
	       Configurability,
	       GroundControl::MethodUtilities


	# Configurability defaults
	CONFIG_DEFAULTS = {
		broker_uri: 'amqp://gcworker@localhost:5672/%2F',
		exchange:   'groundcontrol',
		heartbeat:  'server',
	}


	# Loggability API -- set up groundcontrol's logger
	log_to :groundcontrol

	# Configurability API -- use the 'amqp' section of the config
	config_key :amqp



	##
	# The URL of the AMQP broker to connect to
	singleton_attr_accessor :broker_uri

	##
	# The name of the exchang to bind queues to.
	singleton_attr_accessor :exchange

	##
	# The options to pass to Bunny when setting up the session
	singleton_attr_accessor :session_opts


	### Configurability API -- install the 'groundcontrol' section of the config
	### when it's loaded.
	def self::configure( config=nil )
		config = self.defaults.merge( config || {} )

		self.broker_uri   = config.delete( :broker_uri )
		self.exchange     = config.delete( :exchange )
		self.session_opts = config
	end


	### Fetch a Hash of AMQP options.
	def self::amqp_session_options
		opts = self.session_opts.merge({
			logger: Loggability[ GroundControl ],
		})
		opts[:heartbeat] = opts[:heartbeat].to_sym if opts[:heartbeat].is_a?( String )

		return opts
	end


	### Clear any created Bunny objects
	def self::reset
		@session = nil
		self.amqp.clear
	end


	### Fetch the current session for AMQP connections.
	def self::amqp_session
		unless @session
			options = self.amqp_session_options
			@session = Bunny.new( self.broker_uri, options )
		end
		return @session
	end


	### Fetch a Hash that stores per-thread AMQP objects.
	def self::amqp
		Thread.current[:groundcontrol] ||= {}
		return Thread.current[:groundcontrol]
	end


	### Fetch the AMQP channel, creating one if necessary.
	def self::amqp_channel
		unless self.amqp[:channel]
			self.amqp_session.start
			channel = self.amqp_session.create_channel
			self.amqp[:channel] = channel
		end
		return self.amqp[:channel]
	end


	### Fetch the configured AMQP exchange, creating it first if necessary.
	def self::amqp_exchange
		unless self.amqp[:exchange]
			self.amqp[:exchange] = self.amqp_channel.topic( self.exchange, passive: true )
		end
		return self.amqp[:exchange]
	end

end # class GroundControl::Queue

