#!/usr/bin/env ruby

gem 'sysexits' # Thanks Apple!

require 'sysexits'
require 'loggability'

require 'laika' unless defined?( LAIKA )
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )
require 'laika/groundcontrol/queue'


# Simple forking worker object for GroundControl Tasks. Used by the 'gcworkerd' daemon
# to provide execution logic for its children. It's not intended to be used by 
# user code.
class LAIKA::GroundControl::Worker
	extend Loggability
	include Sysexits

	# Loggability API -- log to the LAIKA logger
	log_to :laika


	# Signal to reset to defaults for the child
	SIGNALS = [ :QUIT, :INT, :TERM, :HUP ]


	### Fork and start a worker listening for work on the specified +queue+ (a
	### LAIKA::GroundControl::Queue). Returns the +pid+ of the worker process.
	def self::start( queue )
		# Parent
		if pid = Process.fork
			return pid

		# Child
		else
			status = EX_UNAVAILABLE

			# Run the worker, ensuring the child doesn't return to parent code
			# when finished.
			begin
				self.log.info "Worker %d starting up..." % [ Process.pid ]
				self.reset_file_descriptors
				self.set_signal_handlers

				status = self.new( queue ).run
			ensure
				self.log.debug "  exiting with status: %p" % [ status ]
				Sysexits.exit!( status )
			end
		end
	end


	### Reset any file descriptors inherited from the parent.
	def self::reset_file_descriptors

		# Reconnect so we aren't using the parent's connection
		LAIKA::DB.connection.synchronize do |conn|
			self.log.debug "Resetting connection %p (FD: %d)" % [ conn, conn.socket ]
			conn.reset
			self.log.debug "  reset. (FD: %d)" % [ conn.socket ]
		end

	end


	### Set signal handlers for the child.
	def self::set_signal_handlers

		# Use default signal handlers
		SIGNALS.each do |sig|
			Signal.trap( sig, :DEFAULT )
		end

	end


	### Create a worker that will listen on the specified +queue+ for a job.
	def initialize( queue )
		@queue     = queue
		@job       = nil
		@task      = nil
		@exit_code = :success
	end


	######
	public
	######

	# The queue that the worker watches for work.
	attr_reader :queue

	# The fetched job.
	attr_reader :job

	# The running task.
	attr_reader :task


	### Make the application name
	def set_app_name
		name = nil

		if t = self.task
			name = "GroundControl worker: %s" % [ t ]
		elsif j = self.job
			name = "GroundControl worker: prepping %s" % [ j ]
		else
			name = "GroundControl worker: waiting for a job"
		end

		LAIKA::DB.connection[ %{SET application_name TO ?}, name ]
		$0 = name
		self.log.info( name )
	end


	### Run the worker by waiting for a job, running the task the job specifies,
	### then exiting with a status that indicates the job's success or failure.
	def run
		self.set_app_name
		@job = self.wait_for_job

		self.set_app_name
		@task = @job.task_class.new( self.queue, @job )

		self.set_app_name
		self.run_task( @task )

		return @task.status

	rescue Interrupt
		self.log.info "Interrupted: shutting down."
		return :tempfail

	rescue Exception => err
		self.log.fatal "%p in worker %d: %s" % [ err.class, Process.pid, err.message ]
		self.log.debug { '  ' + err.backtrace.join("  \n") }
		@job.destroy unless @task

		return :software
	end


	### Wait for the next available job, returning it once one is acquired.
	def wait_for_job
		return self.queue.next
	end


	### Run the task
	def run_task( task )
		starttimes = Process.times
		task.on_startup
		task.run
	rescue StandardError => err
		self.log.error "%p while running %s: %s" % [ err.class, task, err.message ]
		self.log.debug { '  ' + err.backtrace.join("  \n") }
		task.on_error( err )
	else
		self.log.info "Ran %s successfully." % [ task ]
		task.on_completion
	ensure
		task.on_shutdown
		endtimes = Process.times
		self.log.info "  run times: user: %0.3f, system: %0.3f" % [
			endtimes.utime - starttimes.utime,
			endtimes.stime - starttimes.stime,
		]
	end


end # class LAIKA::GroundControl::Queue

