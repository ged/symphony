#!/usr/bin/env ruby

require 'laika' unless defined?( LAIKA )
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )


# Queueing logic for GroundControl jobs.
class LAIKA::GroundControl::Queue
	extend Loggability


	# Loggability API -- log to LAIKA's logger
	log_to :laika


	# The default queue name
	DEFAULT_NAME = '_default_'


	### Create a new LAIKA::GroundControl::Queue with the given +name+.
	def initialize( name=DEFAULT_NAME )
		raise ArgumentError, "invalid identifier" unless name =~ /^\w+$/
		@name = name
		@dataset = LAIKA::GroundControl::Job.filter( queue_name: self.name )
	end


	######
	public
	######

	# The name of the queue
	attr_accessor :name

	# The Sequel::Model dataset for the jobs in this queue
	attr_reader :dataset


	### Add the specified +job+ to the queue. The +job+ can be either a 
	### LAIKA::GroundControl::Job, or a string that can be used to instantate
	### one.
	def add( job )
		if job.respond_to?( :queue_name= )
			job.queue_name = self.name
		else
			job = LAIKA::GroundControl::Job.new( method_name: job, queue_name: self.name )
		end

		job.save
	end	


	### Return a (read-only) Array of jobs belonging to the Queue.
	def jobs
		return self.dataset.all.map( &:freeze )
	end


	### Fetch the next job from the queue, blocking until one is available if the queue
	### is empty.
	def next
		job = nil

		loop do
			break if job = self.dataset.filter( locked_at: nil ).limit( 1 ).for_update.first
			self.wait_for_notification
		end

		job.locked_at = Time.now
		job.save

		return job
	end


	### Callback for notification wait state. Called after the LISTEN, but before the
	### thread blocks waiting for notification.
	def start_waiting( conn )
		self.log.info "Waiting for the next job on %p." % [ conn ]
	end


	### Wait for a notification from PostgreSQL that the queue has been updated.
	def wait_for_notification
		db = LAIKA::GroundControl::Job.db
		db.listen( self.name, after_listen: self.method(:start_waiting) ) do |*|
			self.log.info "Got a notification!"
		end

		# :TODO: Does this need to drain other notifications?
	end


end # class LAIKA::GroundControl::Queue

