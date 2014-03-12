# -*- ruby -*-
#encoding: utf-8

require 'configurability'
require 'loggability'
require 'fcntl'
require 'trollop'

require 'groundcontrol' unless defined?( GroundControl )
require 'groundcontrol/worker'
require 'groundcontrol/task'


# The GroundControl worker daemon. Watches a GroundControl job queue, and runs the tasks
# contained in the jobs it fetches.
class GroundControl::Daemon
	extend Loggability,
	       Configurability

	include GroundControl::SignalHandling


	# Loggability API -- log to the groundcontrol logger
	log_to :groundcontrol

	# Configurability API -- use the 'worker_daemon' section of the config
	config_key :worker_daemon


	# Signals we understand
	QUEUE_SIGS = [
		:QUIT, :INT, :TERM, :HUP,
		# :TODO: :WINCH, :USR1, :USR2, :TTIN, :TTOU
	]

	# The maximum throttle value caused by failing workers
	THROTTLE_MAX = 16

	# The factor which controls how much incrementing the throttle factor
	# affects the pause between workers being started.
	THROTTLE_FACTOR = 2


	#
	# Class methods
	#

	### Get the daemon's version as a String.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, GroundControl::VERSION ]
		if include_buildnum
			rev = GroundControl::REVISION[/: ([[:xdigit:]]+)/, 1] || '0'
			vstring << " (build %s)" % [ rev ]
		end
		return vstring
	end


	### Start the daemon.
	def self::run( argv )
		Loggability.format_with( :color ) if $stdout.tty?

		progname = File.basename( $0 )
		opts = Trollop.options do
			banner "Usage: #{progname} OPTIONS"
			version self.version_string( true )

			opt :config, "The config file to load instead of the default",
				:type => :string
			opt :crew_size, "Number of workers to maintain.", :default => DEFAULT_CREW_SIZE
			opt :queue, "The name of the queue to monitor.", :default => '_default_'

			opt :debug, "Turn on debugging output."
		end

		# Turn on debugging if it's enabled
		if opts.debug
			$DEBUG = true
			Loggability.level = :debug
		end

		# Now load the config file
		GroundControl.load_config( opts.config )

		# Re-enable debug-level logging if the config reset it
		Loggability.level = :debug if opts.debug

		# And start the daemon
		self.new( opts ).run
	end


	#
	# Instance methods
	#

	### Create a new Daemon instance.
	def initialize( options )
		@options             = options
		@queue               = GroundControl::Queue.new( options.queue )

		# Process control
		@crew_size           = options.crew_size
		@crew_workers        = []
		@running             = false
		@shutting_down       = false
		@throttle            = 0
		@last_child_started  = Time.now

		self.set_up_signal_handling
	end


	######
	public
	######

	# The Array of PIDs of currently-running workers
	attr_reader :crew_workers

	# The maximum number of children to have running at any given time
	attr_reader :crew_size

	# A self-pipe for deferred signal-handling
	attr_reader :selfpipe

	# The GroundControl::Queue that jobs will be fetched from
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
		self.log.info "Starting worker supervisor"

		# Become session leader if we can
		if Process.euid.zero?
			sid = Process.setsid
			self.log.debug "  became session leader of new session: %d" % [ sid ]
		end

		# Set up traps for common signals
		self.set_signal_traps( *QUEUE_SIGS )

		# Listen for new jobs and handle them as they come in
		self.start_handling_jobs

		# Restore the default signal handlers
		self.reset_signal_traps( *QUEUE_SIGS )

		exit
	end


	### The main loop of the daemon -- wait for signals, children dying, or jobs, and
	### take appropriate action.
	def start_handling_jobs
		@running = true

		self.log.debug "Starting supervisor loop..."
		while self.running?
			self.start_missing_children unless self.shutting_down?

			timeout = self.throttle_seconds
			timeout = nil if timeout.zero?

			self.wait_for_signals
			self.reap_children
		end
		self.log.info "Supervisor job loop done."

	rescue => err
		self.log.fatal "%p in job-handler loop: %s" % [ err.class, err.message ]
		self.log.debug { '  ' + err.backtrace.join("\n  ") }

	ensure
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
			self.reap_children( *self.crew_workers )
			sleep( 1 )
			self.kill_children
			sleep( 1 )
			break if self.crew_workers.empty?
			sleep( 1 )
		end unless self.crew_workers.empty?

		# Give up on our remaining children.
		Signal.trap( :CHLD, :IGNORE )
		if !self.crew_workers.empty?
			self.log.warn "  %d workers remain: sending KILL" % [ self.crew_workers.length ]
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
		self.log.debug "Handling signal %s" % [ sig ]
		case sig
		when :INT, :TERM
			if @running
				self.log.warn "%s signal: immediate shutdown" % [ sig ]
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
			# Just need to wake up, nothing else necessary

		else
			self.log.warn "Unhandled signal %s" % [ sig ]
		end

	end


	### Fill out the work crew with new children if necessary
	def start_missing_children
		missing_count = self.crew_size - self.crew_workers.length
		return unless missing_count > 0

		# Return unless the throttle period has lapsed
		unless self.throttle_seconds < (Time.now - @last_child_started)
			self.log.info "Not starting children: throttled for %0.2f seconds" %
				[ self.throttle_seconds ]
			return
		end

		self.log.debug "Starting %d workers for a crew of %d" % [ missing_count, self.crew_size ]
		missing_count.times do |i|
			pid = self.start_worker
			self.log.debug "  started worker %d" % [ pid ]
			self.crew_workers << pid
		end

		@last_child_started = Time.now
	end


	### Return the number of seconds between child startup times.
	def throttle_seconds
		return 0 unless @throttle.nonzero?
		return Math.log( @throttle ) * THROTTLE_FACTOR
	end


	### Add +adjustment+ to the throttle value, ensuring that it doesn't go
	### below zero.
	def adjust_throttle( adjustment=1 )
		self.log.debug "Adjusting worker throttle by %d" % [ adjustment ]
		@throttle += adjustment
		@throttle = 0 if @throttle < 0
		@throttle = THROTTLE_MAX if @throttle > THROTTLE_MAX
	end


	### Kill all current children with the specified +signal+. Returns +true+ if the signal was
	### sent to one or more children.
	def kill_children( signal=:TERM )
		return false if self.crew_workers.empty?

		self.log.info "Sending %s signal to %d workers: %p." %
			 [ signal, self.crew_workers.length, self.crew_workers ]
		Process.kill( signal, *self.crew_workers )

		return true
	rescue Errno::ESRCH
		self.log.debug "Ignoring signals to unreaped children."
	end


	### Start a new GroundControl::Worker and return its PID.
	def start_worker
		return if self.shutting_down?
		self.log.debug "Starting a worker."
		return GroundControl::Worker.start( self.queue )
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
	### and remove them from the work crew.
	def reap_any_child
		self.log.debug "  no pids; waiting on any child in this process group"

		pid, status = Process.waitpid2( -1, Process::WNOHANG )
		while pid
			self.adjust_throttle( status.success? ? -1 : 1 )
			self.log.debug "Child %d exited: %p." % [ pid, status ]
			self.crew_workers.delete( pid )

			pid, status = Process.waitpid2( -1, Process::WNOHANG )
		end
	end


	### Wait on the child associated with the given +pid+, deleting it from the
	### crew workers if successful.
	def reap_specific_child( pid )
		spid, status = Process.waitpid2( pid )
		if spid
			self.log.debug "Child %d exited: %p." % [ spid, status ]
			self.crew_workers.delete( spid )
			self.adjust_throttle( status.success? ? -1 : 1 )
		else
			self.log.debug "Child %d no reapy." % [ pid ]
		end
	end


end # class GroundControl::Daemon