#!/usr/bin/env ruby

require 'loggability'

require 'laika' unless defined?( LAIKA )
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )
require 'laika/groundcontrol/queue'


# Simple forking worker object for GroundControl Tasks.
class LAIKA::GroundControl::Worker
	extend Loggability

	# Loggability API -- log to the LAIKA logger
	log_to :laika


	### Fork and start a worker listening for work on the specified +queue+ (a
	### LAIKA::GroundControl::Queue). Returns the +pid+ of the worker process.
	def self::start( queue )
		# Parent
		if pid = Process.fork
			return pid

		# Child
		else
			# Reconnect so we aren't using the parent's connection
			LAIKA::DB.connection.synchronize do |conn|
				self.log.debug "Resetting connection %p (FD: %d)" % [ conn, conn.socket ]
				conn.reset
				self.log.debug "  reset. (FD: %d)" % [ conn.socket ]
			end

			LAIKA::GroundControl::WorkerDaemon::QUEUE_SIGS.each do |sig|
				Signal.trap( sig, :DEFAULT )
			end

			begin
				self.new( queue ).run
			ensure
				exit!
			end
		end
	end


	### Create a worker that will listen on the specified +queue+ for a job.
	def initialize( queue )
		@queue = queue
	end


	######
	public
	######

	# The queue that the worker watches for work.
	attr_reader :queue


	### Run the worker by waiting for a job, running the task the job specifies,
	### then exiting with a status that indicates the job's success or failure.
	def run
		job = self.wait_for_job
		task = job.task_class.new( self.queue, job )		
		self.run_task( task )
	rescue => err
		self.log.fatal "%p in worker %d: %s" % [ err.class, Process.pid, err.message ]
		exit!
	end


	### Wait 
	def wait_for_job
		self.log.info "Waiting for job"
		return self.queue.next
	end


	### Run the task
	def run_task( task )
		task.on_startup
		task.run
	rescue => err
		self.log.error "%p while running %s: %s" % [ err.class, task, err.message ]
		task.on_error( err )
	else
		self.log.info "Ran %s successfully." % [ task ]
		task.on_completion
	ensure
		task.on_shutdown
	end

end # class LAIKA::GroundControl::Queue

