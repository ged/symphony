#!/usr/bin/env ruby

require 'bunny'
require 'loggability'
require 'configurability'

require 'symphony' unless defined?( Symphony )
require 'symphony/mixins'


# An object class that encapsulates queueing logic for Symphony jobs.
class Symphony::Queue
	extend Loggability,
	       Configurability,
	       Symphony::MethodUtilities


	# Configurability defaults
	CONFIG_DEFAULTS = {
		broker_uri:  nil,
		exchange:    'symphony',
		heartbeat:   'server',
	}

	# The default number of messages to prefetch
	DEFAULT_PREFETCH = 10


	# Loggability API -- set up symphony's logger
	log_to :symphony

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


	### Configurability API -- install the 'symphony' section of the config
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
			logger: Loggability[ Symphony ],
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
			if self.broker_uri
				self.log.info "Using the broker URI-style config"
				@session = Bunny.new( self.broker_uri, options )
			else
				self.log.info "Using the options hash-style config"
				@session = Bunny.new( options )
			end
		end
		return @session
	end


	### Fetch a Hash that stores per-thread AMQP objects.
	def self::amqp
		@symphony ||= {}
		return @symphony
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


	### Return a queue configured for the specified +task_class+.
	def self::for_task( task_class )
		args = [
			task_class.queue_name,
			task_class.acknowledge,
			task_class.consumer_tag,
			task_class.routing_keys,
			task_class.prefetch,
			task_class.persistent
		]
		return new( *args )
	end



	### Create a new Queue with the specified configuration.
	def initialize( name, acknowledge, consumer_tag, routing_keys, prefetch, persistent )
		@name          = name
		@acknowledge   = acknowledge
		@consumer_tag  = consumer_tag
		@routing_keys  = routing_keys
		@prefetch      = prefetch
		@persistent    = persistent

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

	# Whether or not to create a persistent queue
	attr_reader :persistent

	# The underlying Bunny::Queue this object manages
	attr_reader :amqp_queue

	# The Bunny::Consumer that is dispatching messages for the queue.
	attr_accessor :consumer

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
		self.consumer = self.create_consumer( amqp_queue, &work_callback )

		self.log.debug "Subscribing to queue with consumer: %p" % [ self.consumer ]
		amqp_queue.subscribe_with( self.consumer, block: true )
		amqp_queue.channel.close
		session.close
	end


	### Create the Bunny::Consumer that will dispatch messages from the broker.
	def create_consumer( amqp_queue, &work_callback )
		ackmode = self.acknowledge
		tag     = self.consumer_tag

		# Last argument is *no_ack*, so need to invert the logic
		self.log.debug "Creating consumer for the '%s' queue with tag: %s" %
			[ amqp_queue.name, tag ]
		cons = Bunny::Consumer.new( amqp_queue.channel, amqp_queue, tag, !ackmode )

		cons.on_delivery do |delivery_info, properties, payload|
			rval = self.handle_message( delivery_info, properties, payload, &work_callback )
			self.log.debug "Done with message %s. Session is %s" %
					[ delivery_info.delivery_tag, self.class.amqp_session.closed? ? "closed" : "open" ]
			cons.cancel if self.shutting_down?
		end

		cons.on_cancellation do
			self.log.warn "Consumer cancelled."
			self.shutdown
		end

		return cons
	end


	### Create the AMQP queue from the task class and bind it to the configured exchange.
	def create_amqp_queue( prefetch_count=DEFAULT_PREFETCH )
		exchange = self.class.amqp_exchange
		channel = self.class.amqp_channel

		begin
			queue = channel.queue( self.name, passive: true )
			channel.prefetch( prefetch_count )
			self.log.info "Using pre-existing queue: %s" % [ self.name ]
			return queue
		rescue Bunny::NotFound => err
			self.log.info "%s; using an auto-delete queue instead." % [ err.message ]
			channel = self.class.reset_amqp_channel
			channel.prefetch( prefetch_count )

			queue = channel.queue( self.name, auto_delete: !self.persistent )
			self.routing_keys.each do |key|
				self.log.info "  binding queue %s to the %s exchange with topic key: %s" %
					[ self.name, exchange.name, key ]
				queue.bind( exchange, routing_key: key )
			end

			return queue
		end
	end


	### Handle each subscribed message.
	def handle_message( delivery_info, properties, payload, &work_callback )
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


	### Return a human-readable representation of the Queue in a form suitable for debugging.
	def inspect
		return "#<%p:%#0x %s (%s) ack: %s, routing: %p, prefetch: %d>" % [
			self.class,
			self.object_id * 2,
			self.name,
			self.consumer_tag,
			self.acknowledge ? "yes" : "no",
			self.routing_keys,
			self.prefetch,
		]
	end


end # class Symphony::Queue

