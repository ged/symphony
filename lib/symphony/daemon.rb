# -*- ruby -*-
#encoding: utf-8

require 'configurability'
require 'loggability'

require 'symphony' unless defined?( Symphony )
require 'symphony/task'
require 'symphony/signal_handling'

# A daemon which manages startup and shutdown of one or more Workers
# running Tasks as they are published from a queue.
class Symphony::Daemon
	extend Loggability,
	       Configurability,
	       Symphony::MethodUtilities

	include Symphony::SignalHandling


	# Loggability API -- log to the symphony logger
	log_to :symphony

	# Configurability API -- use the 'worker_daemon' section of the config
	config_key :symphony


	# Default configuration
	CONFIG_DEFAULTS = {
		throttle_max:    16,
		throttle_factor: 1,
		tasks: []
	}

	# Signals we understand
	QUEUE_SIGS = [
		:QUIT, :INT, :TERM, :HUP, :CHLD,
		# :TODO: :WINCH, :USR1, :USR2, :TTIN, :TTOU
	]



	#
	# Class methods
	#

	##
	# The maximum throttle factor caused by failing workers
	singleton_attr_accessor :throttle_max

	##
	# The factor which controls how much incrementing the throttle factor
	# affects the pause between workers being started.
	singleton_attr_accessor :throttle_factor

	##
	# The Array of Symphony::Task classes that are configured to run
	singleton_attr_accessor :tasks


	### Get the daemon's version as a String.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, Symphony::VERSION ]
		if include_buildnum
			rev = Symphony::REVISION[/: ([[:xdigit:]]+)/, 1] || '0'
			vstring << " (build %s)" % [ rev ]
		end
		return vstring
	end


	### Configurability API -- configure the daemon.
	def self::configure( config=nil )
		config = self.defaults.merge( config || {} )

		self.throttle_max    = config[:throttle_max]
		self.throttle_factor = config[:throttle_factor]

		self.tasks = self.load_configured_tasks( config[:tasks] )
	end


	### Load the tasks with the specified +task_names+ and return them
	### as an Array.
	def self::load_configured_tasks( task_names )
		return task_names.map do |task_name|
			Symphony::Task.get_subclass( task_name )
		end
	end


	### Start the daemon.
	def self::run( args )
		Loggability.format_with( :color ) if $stdout.tty?

		# Turn on debugging if it's enabled
		Loggability.level = :debug if $DEBUG

		# Now load the config file
		Symphony.load_config( args.shift )

		# Re-enable debug-level logging if the config reset it
		Loggability.level = :debug if $DEBUG

		# And start the daemon
		self.new.run
	end


	#
	# Instance methods
	#

	### Create a new Daemon instance.
	def initialize
		# Process control
		@tasks               = self.class.tasks

		@running_tasks       = {}
		@running             = false
		@shutting_down       = false
		@throttle            = 0
		@last_child_started  = Time.now

		self.set_up_signal_handling
	end


	######
	public
	######

	# The Hash of PIDs to task class
	attr_reader :running_tasks

	# A self-pipe for deferred signal-handling
	attr_reader :selfpipe

	# The Symphony::Queue that jobs will be fetched from
	attr_reader :queue

	# The Configurability::Config object for the current configuration.
	attr_reader :config


	### Returns +true+ if the daemon is still running.
	def running?
		return @running
	end


	### Returns +true+ if the daemon is shutting down.
	def shutting_down?
		return @shutting_down
	end


	### Set up the daemon and start running.
	def run
		self.log.info "Starting task daemon"

		# Become session leader if we can
		if Process.euid.zero?
			sid = Process.setsid
			self.log.debug "  became session leader of new session: %d" % [ sid ]
		end

		# Set up traps for common signals
		self.set_signal_traps( *QUEUE_SIGS )

		# Listen for new jobs and handle them as they come in
		self.run_tasks

		# Restore the default signal handlers
		self.reset_signal_traps( *QUEUE_SIGS )

		exit
	end


	### The main loop of the daemon -- wait for signals, children dying, or jobs, and
	### take appropriate action.
	def run_tasks
		@running = true

		self.log.debug "Starting supervisor loop..."
		while self.running?
			self.start_missing_children unless self.shutting_down?
			self.wait_for_signals
			self.reap_children
		end

	rescue => err
		self.log.fatal "%p in job-handler loop: %s" % [ err.class, err.message ]
		self.log.debug { '  ' + err.backtrace.join("\n  ") }

	ensure
		self.log.info "Done running tasks."
		@running = false
		self.stop
	end


	### Shut the daemon down gracefully.
	def stop
		self.log.warn "Stopping."
		@shutting_down = true

		self.ignore_signals( *QUEUE_SIGS )

		self.log.warn "Stopping children."
		3.times do |i|
			self.reap_children
			sleep( 1 )
			self.kill_children
			sleep( 1 )
			break if self.running_tasks.empty?
			sleep( 1 )
		end unless self.running_tasks.empty?

		# Give up on our remaining children.
		Signal.trap( :CHLD, :IGNORE )
		if !self.running_tasks.empty?
			self.log.warn "  %d workers remain: sending KILL" % [ self.running_tasks.length ]
			self.kill_children( :KILL )
		end
	end


	### Reload the configuration.
	def reload_config
		self.log.warn "Reloading config %p" % [ self.config ]
		self.config.reload
	end


	#########
	protected
	#########

	### Handle signals.
	def handle_signal( sig )
		self.log.debug "Handling signal %s in PID %d" % [ sig, Process.pid ]
		case sig
		when :INT, :TERM
			if @running
				self.log.warn "%s signal: graceful shutdown" % [ sig ]
				@running = false
			else
				self.ignore_signals
				self.log.warn "%s signal: forceful shutdown" % [ sig ]
				self.kill_children( :KILL )
				exit!( 255 )
			end

		when :HUP
			self.log.warn "Hangup signal."
			self.reload_config

		when :CHLD
			self.log.warn "Got SIGCHLD."
			# Just need to wake up, nothing else necessary

		else
			self.log.warn "Unhandled signal %s" % [ sig ]
		end

	end


	### Start any tasks which aren't already running
	def start_missing_children
		missing_tasks = self.class.tasks - self.running_tasks.values
		return if missing_tasks.empty?

		# Return unless the throttle period has lapsed
		unless self.throttle_seconds < (Time.now - @last_child_started)
			self.log.info "Not starting children: throttled for %0.2f seconds" %
				[ self.throttle_seconds ]
			return
		end

		self.log.debug "Starting %d tasks out of %d" % [ missing_tasks.size, self.class.tasks.size ]
		missing_tasks.each do |task_class|
			pid = self.start_worker( task_class )
			self.log.debug "  started task %p at pid %d" % [ task_class, pid ]
			self.running_tasks[ pid ] = task_class
		end

		@last_child_started = Time.now
	end


	### Return the number of seconds between child startup times.
	def throttle_seconds
		return 0 unless @throttle.nonzero?
		return Math.log( @throttle ) * self.class.throttle_factor
	end


	### Add +adjustment+ to the throttle value, ensuring that it doesn't go
	### below zero.
	def adjust_throttle( adjustment=1 )
		self.log.debug "Adjusting worker throttle by %d" % [ adjustment ]
		@throttle += adjustment
		@throttle = 0 if @throttle < 0
		@throttle = self.class.throttle_max if @throttle > self.class.throttle_max
	end


	### Kill all current children with the specified +signal+. Returns +true+ if the signal was
	### sent to one or more children.
	def kill_children( signal=:TERM )
		return false if self.running_tasks.empty?

		self.log.info "Sending %s signal to %d task pids: %p." %
			 [ signal, self.running_tasks.length, self.running_tasks.keys ]
		Process.kill( signal, *self.running_tasks.keys )

		return true
	rescue Errno::ESRCH
		self.log.debug "Ignoring signals to unreaped children."
	end


	### Start a new Symphony::Task and return its PID.
	def start_worker( task_class )
		return if self.shutting_down?
		self.log.debug "Starting a %p." % [ task_class ]
		return Process.fork do
			self.reset_signal_traps( *QUEUE_SIGS )
			@selfpipe.each {|_,io| io.close }.clear
			task_class.run
		end
	end


	### Clean up after any children that have died.
	def reap_children( *pids )
		self.log.debug "Reaping children."

		if pids.empty?
			self.reap_any_child
		else
			self.log.debug "  waiting on pids: %p" % [ pids ]
			pids.each do |pid|
				self.reap_specific_child( pid )
			end
		end
	rescue Errno::ECHILD => err
		self.log.debug "No more children to reap."
	end


	### Reap any children that have died within the caller's process group
	### and remove them from the Hash of running tasks.
	def reap_any_child
		self.log.debug "  no pids; waiting on any child in this process group"

		pid, status = Process.waitpid2( -1, Process::WNOHANG|Process::WUNTRACED )
		self.log.debug "  waitpid2 returned: [ %p, %p ]" % [ pid, status ]
		while pid
			self.adjust_throttle( status.success? ? -1 : 1 )
			self.log.debug "Child %d exited: %p." % [ pid, status ]
			self.running_tasks.delete( pid )

			pid, status = Process.waitpid2( -1, Process::WNOHANG|Process::WUNTRACED )
			self.log.debug "  waitpid2 returned: [ %p, %p ]" % [ pid, status ]
		end
	end


	### Wait on the child associated with the given +pid+, deleting it from the
	### running tasks Hash if successful.
	def reap_specific_child( pid )
		spid, status = Process.waitpid2( pid )
		if spid
			self.log.debug "Child %d exited: %p." % [ spid, status ]
			self.running_tasks.delete( spid )
			self.adjust_throttle( status.success? ? -1 : 1 )
		else
			self.log.debug "Child %d no reapy." % [ pid ]
		end
	end


end # class Symphony::Daemon
