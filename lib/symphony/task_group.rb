# -*- ruby -*-
#encoding: utf-8

require 'set'
require 'pluggability'

require 'symphony' unless defined?( Symphony )

# A group for managing groups of tasks.
class Symphony::TaskGroup
	extend Pluggability,
	       Loggability


	# Log to the Symphony logger
	log_to :symphony

	# Pluggability API -- set the directory/directories that will be search when trying to
	# load tasks by name.
	plugin_prefixes 'symphony/task_group'


	### Set up a new task group.
	def initialize( task_class, max_workers )
		@task_class         = task_class
		@max_workers        = max_workers
		@workers            = Set.new
		@last_child_started = Time.now
		@throttle           = 0
		@queue              = nil
	end


	######
	public
	######

	##
	# The set of worker PIDs
	attr_reader :workers

	##
	# The maximum number of workers the group will keep running
	attr_accessor :max_workers

	##
	# The Class of the task the worker runs
	attr_reader :task_class

	##
	# The Time that the last child started
	attr_reader :last_child_started


	### Start a new Symphony::Task and return its PID.
	def start_worker( exit_on_idle=false )
		self.log.debug "Starting a %p." % [ task_class ]
		task_class.before_fork

		pid = Process.fork do
			task_class.after_fork
			task_class.run( exit_on_idle )
		end or raise "No PID from forked %p worker?" % [ task_class ]

		Process.setpgid( pid, 0 )

		self.log.info "Adding %p worker %p" % [ task_class, pid ]
		self.workers << pid
		@last_child_started = Time.now

		return pid
	end


	### Stop a worker from the task group.
	def stop_worker
		pid = self.workers.first
		self.signal_processes( :TERM, pid )
	end


	### Stop all of the task group's workers.
	def stop_all_workers
		self.signal_processes( :TERM, *self.workers )
	end


	### Send a SIGHUP to all the group's workers.
	def restart_workers
		self.signal_processes( :HUP, *self.workers )
	end


	### Scale workers up or down based on the task group's work model.
	### This method needs to return an array of pids that were started, otherwise
	### nil.
	def adjust_workers
		raise NotImplementedError, "%p needs to provide an implementation of #adjust_workers" % [
			self.class
		]
	end


	### Handle the exit of the child with the specified +pid+. The +status+ is the
	### Process::Status returned by waitpid.
	def on_child_exit( pid, status )
		self.workers.delete( pid )
		self.adjust_throttle( status.success? ? -1 : 1 )
	end


	### Returns +true+ if the group of tasks is throttled (i.e., should wait to start any more
	### children).
	def throttled?
		# Return unless the throttle period has lapsed
		unless self.throttle_seconds < (Time.now - self.last_child_started)
			self.log.warn "Not starting children: throttled for %0.2f seconds" %
				[ self.throttle_seconds ]
			return true
		end

		return false
	end


	### Return the number of seconds between child startup times.
	def throttle_seconds
		return 0 unless @throttle.nonzero?
		return Math.log( @throttle ) * Symphony.throttle_factor
	end


	### Add +adjustment+ to the throttle value, ensuring that it doesn't go
	### below zero.
	def adjust_throttle( adjustment=1 )
		self.log.debug "Adjusting worker throttle by %d" % [ adjustment ]
		@throttle += adjustment
		@throttle = 0 if @throttle < 0
		@throttle = Symphony.throttle_max if @throttle > Symphony.throttle_max
	end


	#########
	protected
	#########

	### Send the specified +signal+ to the process associated with +pid+, handling
	### harmless errors.
	def signal_processes( signal, *pids )
		self.log.debug "Signalling processes: %p" % [ pids ]

		# Do them one at a time, as Process.kill will abort on the first error if you
		# pass more than one pid.
		pids.each do |pid|
			begin
				Process.kill( signal, pid )
			rescue Errno::ESRCH => err
				self.log.error "%p when trying to %s worker %d: %s" %
					[ err.class, signal, pid, err.message ]
			end
		end
	end

end # class Symphony::TaskGroup

