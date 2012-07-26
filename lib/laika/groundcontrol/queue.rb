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
		self.log.debug "Fetching next job for queue %s" % [ self.name ]
		job = nil

		begin
			LAIKA::GroundControl::Job.db.transaction( :rollback => :reraise ) do
				job = self.dataset.filter( locked_at: nil ).limit( 1 ).for_update.first or
					raise Sequel::Rollback, "no pending jobs"
				self.log.debug "  got job: %s" % [ job ]
				job.locked_at = Time.now
				job.save
			end
		rescue Sequel::Rollback => err
			self.log.debug "  rollback (%s): waiting for notification" % [ err.message ]
			self.wait_for_notification
			retry
		end

		self.log.debug "  returning with job: %p" % [ job ]
		return job
	rescue ::Exception => err
		self.log.error "%p! %s" % [ err.class, err.message ]
	end


	### Wait for a notification from PostgreSQL that the queue has been updated. If +poll+ is true,
	### notifications will be waited for in a loop, and the block called for each one received. If
	### +timeout+ is specified, this method will return +timeout+ seconds after it was called if no
	### notifications arrive.
	def wait_for_notification( poll=false, timeout=nil, &block )
		db = LAIKA::GroundControl::Job.db

		options = {
			:after_listen => self.method( :start_waiting ),
			:loop         => poll,
			:timeout      => timeout,
		}
		block ||= Proc.new {|*| self.log.info "Got a notification!" }

		db.listen( self.name, options, &block )

		# :TODO: Does this need to drain other notifications?
	end


	#########
	protected
	#########

	### Callback for notification wait state. Called after the LISTEN, but before the
	### thread blocks waiting for notification.
	def start_waiting( conn )
		self.log.info "Waiting for the next job on %p." % [ conn ]
	end


end # class LAIKA::GroundControl::Queue

