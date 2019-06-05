# -*- ruby -*-
#encoding: utf-8

require 'configurability'
require 'loggability'

require 'symphony' unless defined?( Symphony )
require 'symphony/task'
require 'symphony/signal_handling'
require 'symphony/task_group'

# A daemon which manages startup and shutdown of one or more Workers
# running Tasks as they are published from a queue.
class Symphony::Daemon
	extend Loggability

	include Symphony::SignalHandling


	# Loggability API -- log to the symphony logger
	log_to :symphony


	# Signals we understand
	QUEUE_SIGS = [
		:QUIT, :INT, :TERM, :HUP, :CHLD,
		# :TODO: :WINCH, :USR1, :USR2, :TTIN, :TTOU
	]


	#
	# Class methods
	#

	### Get the daemon's version as a String.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, Symphony::VERSION ]
		if include_buildnum
			rev = Symphony::REVISION[/: ([[:xdigit:]]+)/, 1] || '0'
			vstring << " (build %s)" % [ rev ]
		end
		return vstring
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
		@task_pids   = {}
		@task_groups = {}
		@running     = false

		self.set_up_signal_handling
	end


	######
	public
	######

	# The Hash of PID to task group
	attr_reader :task_pids

	# The Array of running task groups
	attr_reader :task_groups

	# A self-pipe for deferred signal-handling
	attr_reader :selfpipe

	# The Symphony::Queue that jobs will be fetched from
	attr_reader :queue


	### Returns +true+ if the daemon is still running.
	def running?
		return @running
	end


	### Set up the daemon and start running.
	def run
		self.log.info "Starting task daemon"

		# Set up traps for common signals
		self.set_signal_traps( *QUEUE_SIGS )

		# Listen for new jobs and handle them as they come in
		self.run_tasks

		# Restore the default signal handlers
		self.reset_signal_traps( *QUEUE_SIGS )
	end


	### The main loop of the daemon -- wait for signals, children dying, or jobs, and
	### take appropriate action.
	def run_tasks
		@running = true
		self.create_task_groups

		self.log.debug "Starting supervisor loop..."
		while self.running?
			self.tickle_task_groups
			if self.wait_for_signals( Symphony.scaling_interval )
				self.reap_children
			end
		end

	rescue => err
		self.log.fatal "%p in job-handler loop: %s" % [ err.class, err.message ]
		self.log.debug { '  ' + err.backtrace.join("\n  ") }

	ensure
		self.log.info "Done running tasks."
		self.stop
	end


	### Shut the daemon down gracefully.
	def stop
		self.log.warn "Stopping."
		@running = false

		self.ignore_signals( *QUEUE_SIGS )

		self.log.warn "Stopping children."
		3.times do |i|
			self.reap_children
			sleep( 1 )
			self.kill_children
			sleep( 1 )
			break if self.task_pids.empty?
			sleep( 1 )
		end unless self.task_pids.empty?

		# Give up on our remaining children.
		Signal.trap( :CHLD, :IGNORE )
		if !self.task_pids.empty?
			self.log.warn "  %d workers remain: sending KILL" % [ self.task_pids.length ]
			self.kill_children( :KILL )
		end
	end


	### Reload the configuration.
	def reload_config
		self.log.warn "Reloading config %p" % [ Symphony.config ]
		Symphony.config.reload

		# And start them up again using the new config.
		self.create_task_groups
	end


	#########
	protected
	#########

	### Handle signals.
	def handle_signal( sig )
		self.log.debug "Handling signal %s in PID %d" % [ sig, Process.pid ]
		case sig
		when :INT, :TERM, :QUIT
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
			self.log.info "Got SIGCHLD."
			# Just need to wake up, nothing else necessary

		else
			self.log.warn "Unhandled signal %s" % [ sig ]
		end

	end


	### Create task groups for each configured task.
	def create_task_groups
		old_task_groups = @task_groups || {}
		@task_groups = {}

		self.log.debug "Managing task groups: %p" % [ old_task_groups ]

		Symphony.load_configured_tasks.each do |task_class, max|
			# If the task is still configured, restart all of its workers
			if group = old_task_groups.delete( task_class )
				self.log.info "%p still configured; restarting its task group." % [ task_class ]
				self.restart_task_group( group, task_class, max )
				@task_groups[ task_class ] = group

			# If it's new, just start it up
			else
				self.log.info "Starting up new task group for %p" % [ task_class ]
				@task_groups[ task_class ] = self.start_task_group( task_class, max )
			end
		end

		# Any task classes remaining are no longer configured, so stop them.
		old_task_groups.each do |task_class, group|
			self.log.info "%p no longer configured; stopping its task group." % [ task_class ]
			self.stop_task_group( group )
		end
	end


	### Start a new task group for the given +task_class+ and +max+ number of workers.
	def start_task_group( task_class, max )
		self.log.info "Starting a task group for %p" % [ task_class ]
		Symphony::TaskGroup.create( task_class.work_model, task_class, max )
	end


	### Tell the specified task +group+ to restart with the specified +max+ number of workers.
	def restart_task_group( group, task_class, max )
		self.log.info "Restarting task group for %p" % [ task_class ]
		group.max_workers = max
		group.restart_workers
		end


	### Shut down the workers for the specified task group.
	def stop_task_group( group )
		self.log.info "Shutting down the task group for %p" % [ group.task_class ]
		group.stop_all_workers
	end


	### Tell the task groups to start or stop children based on their work model.
	def tickle_task_groups
		self.task_groups.each do |task_class, group|
			new_pids = group.adjust_workers or next
			new_pids.each do |pid|
				self.task_pids[ pid ] = group
			end
		end
	end


	### Kill all current children with the specified +signal+. Returns +true+ if the signal was
	### sent to one or more children.
	def kill_children( signal=:TERM )
		return false if self.task_pids.empty?

		self.log.info "Sending %s signal to %d task pids: %p." %
			 [ signal, self.task_pids.length, self.task_pids.keys ]
		self.task_pids.keys.each do |pid|
			begin
				Process.kill( signal, pid )
			rescue Errno::ESRCH => err
				self.log.error "%p when trying to %s child %d: %s" %
					[ err.class, signal, pid, err.message ]
			end
		end

		return true
	rescue Errno::ESRCH
		self.log.debug "Ignoring signals to unreaped children."
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
	rescue Errno::ECHILD
		self.log.debug "No more children to reap."
	end


	### Reap any children that have died within the caller's process group
	### and remove them from the Hash of running tasks.
	def reap_any_child
		self.log.debug "  no pids; waiting on any child in this process group"

		pid, status = Process.waitpid2( -1, Process::WNOHANG|Process::WUNTRACED )
		self.log.debug "  waitpid2 returned: [ %p, %p ]" % [ pid, status ]
		while pid
			self.notify_group( pid, status )
			self.task_pids.delete( pid )

			pid, status = Process.waitpid2( -1, Process::WNOHANG|Process::WUNTRACED )
			self.log.debug "  waitpid2 returned: [ %p, %p ]" % [ pid, status ]
		end
	end


	### Wait on the child associated with the given +pid+, deleting it from the
	### running tasks Hash if successful.
	def reap_specific_child( pid )
		pid, status = Process.waitpid2( pid )
		if pid
			self.notify_group( pid, status )
			self.task_pids.delete( pid )
		else
			self.log.debug "Child %d no reapy." % [ pid ]
		end
	end


	### Notify the task group the specified +pid+ belongs to that its child exited
	### with the specified +status+.
	def notify_group( pid, status )
		self.log.debug "Notifying group of reaped child %d: %p" % [ pid, status ]
		return unless self.running?

		group = self.task_pids[ pid ]
		group.on_child_exit( pid, status )
	end

end # class Symphony::Daemon
