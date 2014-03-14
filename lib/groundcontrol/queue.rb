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

		if (( uri = config.delete(:url) ))
			self.log.debug "Using the url+vhost style config"
			uri += '/' unless uri.end_with?( '/' )
			uri += config[:vhost].gsub('/', '%2F') if config[:vhost]
			self.broker_uri = uri.to_s
		elsif (( uri = config.delete(:broker_uri) ))
			self.log.debug "Using the broker_uri-style config"
			self.broker_uri = uri
		else
			self.log.warn "No broker config; looked for 'url' and 'broker_uri'"
		end

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
		@groundcontrol ||= {}
		return @groundcontrol
	end


	### Fetch the AMQP channel, creating one if necessary.
	def self::amqp_channel
		unless self.amqp[:channel]
			self.log.debug "Creating a new AMQP channel"
			self.amqp_session.start
			channel = self.amqp_session.create_channel
			self.amqp[:channel] = channel
		end
		return self.amqp[:channel]
	end


	### Close and remove the current AMQP channel, e.g., after an error.
	def self::reset_amqp_channel
		if self.amqp[:channel]
			self.log.info "Resetting AMQP channel."
			self.amqp[:channel].close if self.amqp[:channel].open?
			self.amqp.delete( :channel )
		end

		return self.amqp_channel
	end


	### Fetch the configured AMQP exchange interface object.
	def self::amqp_exchange
		unless self.amqp[:exchange]
			self.amqp[:exchange] = self.amqp_channel.topic( self.exchange, passive: true )
		end
		return self.amqp[:exchange]
	end


	### Create a new Queue with the specified configuration.
	def initialize( name, acknowledge, consumer_tag, routing_keys, prefetch )
		@name          = name
		@acknowledge   = acknowledge
		@consumer_tag  = consumer_tag
		@routing_keys  = routing_keys
		@prefetch      = prefetch

		@amqp_queue    = nil
		@shutting_down = false
	end


	######
	public
	######

	# The name of the queue
	attr_reader :name

	# Acknowledge mode
	attr_reader :acknowledge

	# The tag to use when setting up consumer
	attr_reader :consumer_tag

	# The Array of routing keys to use when binding the queue to the exchange
	attr_reader :routing_keys

	# The maximum number of un-acked messages to prefetch
	attr_reader :prefetch

	# The Bunny::Consumer that is dispatching messages for the queue.
	attr_reader :consumer

	##
	# The flag for shutting the queue down.
	attr_predicate_accessor :shutting_down


	### The main work loop -- subscribe to the message queue and yield the payload and
	### associated metadata when one is received.
	def wait_for_message( only_one=false, &work_callback )
		raise LocalJumpError, "no work_callback given" unless work_callback
		session = self.class.amqp_session

		self.shutting_down = only_one
		amqp_queue = self.create_amqp_queue( only_one ? 1 : self.prefetch )
		@consumer = self.create_consumer( amqp_queue, work_callback )

		amqp_queue.subscribe_with( @consumer, block: true )
		amqp_queue.channel.close
		session.close
	end


	### Create the Bunny::Consumer that will dispatch messages from the broker.
	def create_consumer( amqp_queue, work_callback )
		ackmode = self.acknowledge
		tag     = self.consumer_tag

		consumer = Bunny::Consumer.new( amqp_queue.channel, amqp_queue, tag, !ackmode )

		consumer.on_delivery do |delivery_info, properties, payload|
			rval = self.handle_message( delivery_info, properties, payload, work_callback )
			self.log.debug "Done with message %s. Session is %s" %
					[ delivery_info.delivery_tag, self.class.amqp_session.closed? ? "closed" : "open" ]
			consumer.cancel if self.shutting_down?
		end

		consumer.on_cancellation do 
			self.log.warn "Consumer cancelled."
			self.shutdown
		end

	end


	### Create the AMQP queue from the task class and bind it to the configured exchange.
	def create_amqp_queue( prefetch_count=10 )
		exchange = self.class.amqp_exchange
		channel = self.class.amqp_channel

		channel.prefetch( prefetch_count )

		begin
			queue = channel.queue( self.name, passive: true )
			self.log.info "Using pre-existing queue: %s" % [ self.name ]
			return queue
		rescue Bunny::NotFound => err
			self.log.info "%s; using an auto-delete queue instead." % [ err.message ]
			channel = self.class.reset_amqp_channel

			queue = channel.queue( self.name, auto_delete: true )
			self.routing_keys.each do |key|
				self.log.info "  binding queue %s to the %s exchange with topic key: %s" %
					[ self.name, exchange.name, key ]
				queue.bind( exchange, routing_key: key )
			end

			return queue
		end
	end


	### Handle each subscribed message.
	def handle_message( delivery_info, properties, payload, work_callback )
		metadata = {
			delivery_info: delivery_info,
			properties: properties,
			content_type: properties[:content_type],
		}
		rval = work_callback.call( payload, metadata )
		return self.ack_message( delivery_info.delivery_tag, rval )

	# Re-raise errors from AMQP
	rescue Bunny::Exception => err
		self.log.error "%p while handling a message: %s" % [ err.class, err.message ]
		self.log.debug "  " + err.backtrace.join( "\n  " )
		raise

	rescue => err
		self.log.error "%p while handling a message: %s" % [ err.class, err.message ]
		self.log.debug "  " + err.backtrace.join( "\n  " )
		return self.ack_message( delivery_info.delivery_tag, false, false )
	end


	### Signal a acknowledgement or rejection for a message.
	def ack_message( tag, success, try_again=true )
		return unless self.acknowledge

		channel = self.consumer.channel

		if success
			self.log.debug "ACKing message %s" % [ tag ]
			channel.acknowledge( tag )
		else
			self.log.debug "NACKing message %s %s retry" % [ tag, try_again ? 'with' : 'without' ]
			channel.reject( tag, try_again )
		end

		return success
	end


	### Close the AMQP session associated with this queue.
	def shutdown
		self.shutting_down = true
		self.consumer.cancel
	end


	### Forcefully halt the queue.
	def halt
		self.shutting_down = true
		self.consumer.channel.close
	end

end # class GroundControl::Queue

