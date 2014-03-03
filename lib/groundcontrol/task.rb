# -*- ruby -*-
#encoding: utf-8

require 'sysexits'
require 'pluggability'
require 'loggability'

require 'yajl'
require 'yaml'

require 'groundcontrol' unless defined?( GroundControl )


# A task is the subclassable unit of work that GroundControl loads when it starts up.
class GroundControl::Task
	extend Loggability,
	       Pluggability

	# Signal to reset to defaults for the child
	SIGNALS = [ :QUIT, :INT, :TERM, :HUP, :USR1, :USR2, :WINCH ]


	# Loggability API -- log to groundcontrol's logger
	log_to :groundcontrol

	# Pluggability API -- set the directory/directories that will be search when trying to
	# load tasks by name.
	plugin_prefixes 'groundcontrol/tasks'


	### Fetch the GroundControl::Queue for this task, creating it if necessary.
	def self::queue
		unless @queue
			@queue = GroundControl::Queue.new( self )
		end
		return @queue
	end


	### Create a new Task object and listen for work. Exits with the code returned
	### by #start when it's done.
	def self::run
		exit self.new( self.queue ).start
	end


	### Return a normalized name for this task's queue.
	def self::queue_name
		name = self.name || "anonymous task %d" % [ self.object_id ]
		return name.gsub( /\W+/, '.' ).downcase
	end


	### Set up one or more topic key patterns to use when binding the Task's queue
	### to the exchange.
	def self::subscribe_to( *routing_keys )
		unless routing_keys.empty?
			@routing_keys = routing_keys
		end

		return @routing_keys
	end


	### Inheritance hook -- set some defaults on subclasses.
	def self::inherited( subclass )
		super

		subclass.instance_variable_set( :@routing_keys, [] )
	end


	### Create a worker that will listen on the specified +queue+ for a job.
	def initialize( queue )
		@queue = queue
		@signal_handler = nil
	end


	######
	public
	######

	# The queue that the task consumes messages from 
	attr_reader :queue


	### Set up the task and start handling messages.
	def start
		self.set_signal_traps( *SIGNALS )
		self.start_signal_handler
		self.start_handling_messages
		self.stop_signal_handler
		self.reset_signal_traps( *SIGNALS )

		return :success
	rescue Exception => err
		self.log.fatal "%p in %p: %s" % [ err.class, self.class, err.message ]
		self.log.debug { '  ' + err.backtrace.join("  \n") }

		return :software
	end


	### Start the thread that will deliver signals once they're put on the queue.
	def start_signal_handler
		@signal_handler = Thread.new do
			loop { self.wait_for_signals }
		end
	end


	### Stop the signal handler thread.
	def stop_signal_handler
		@signal_handler.exit if @signal_handler
	end


	### Handle signals; called by the signal handler thread with a signal from the
	### queue.
	def handle_signal( sig )
		self.log.debug "Handling signal %s" % [ sig ]
		case sig
		when :TERM
			self.on_terminate
		when :INT
			self.on_interrupt
		when :HUP
			self.on_hangup
		when :CHLD
			self.on_child_exit
		else
			self.log.warn "Unhandled signal %s" % [ sig ]
		end
	end


	### Start consuming messages from the queue, calling #work for each one.
	def start_handling_messages
		# TODO: Handle oneshot work model
		self.queue.each_message do |payload, metadata|
			work_payload = self.preprocess_payload( payload, metadata )
			self.work( work_payload, metadata )
		end
	end


	### Do any necessary pre-processing on the raw +payload+ according to values in
	### the given +metadata+.
	def preprocess_payload( payload, metadata )
		work_payload = case metadata[:content_type]
			when 'application/json', 'text/javascript'
				Yajl.parse( payload )
			when 'application/x-yaml', 'text/x-yaml'
				YAML.load( payload )
			else
				payload
			end

		return work_payload
	end


	### Do work based on the given message +payload+ and +metadata+.
	def work( payload, metadata )
		raise NotImplementedError,
			"%p doesn't implement required method #work" % [ self.class ]
	end


	### Handle a termination signal.
	def on_terminate
		self.queue.close
	end

end # class GroundControl::Task

