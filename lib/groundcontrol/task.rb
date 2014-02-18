# -*- ruby -*-
#encoding: utf-8

require 'sysexits'
require 'pluggability'
require 'loggability'

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


	### Fork and start a worker listening for work on the specified +queue+ (a
	### GroundControl::Queue). Returns the +pid+ of the worker process.
	def self::run
		exit self.new( self.queue ).start
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


	### Run the worker by waiting for a job, running the task the job specifies,
	### then exiting with a status that indicates the job's success or failure.
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


	### Start the thread that will delivery signals once they're put on the queue.
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

		
		# :TODO: Dispatch the mandatory signals, call hooks for optional ones.
	end


	### Start consuming messages from the queue, calling #run for each one.
	def start_handling_messages
		# :TODO: Everything else
	end

end # class GroundControl::Task

