# -*- ruby -*-
#encoding: utf-8

require 'set'
require 'symphony/task_group' unless defined?( Symphony::TaskGroup )
require 'symphony/statistics'


# A task group for the 'longlived' work model.
class Symphony::TaskGroup::LongLived < Symphony::TaskGroup
	include Symphony::Statistics


	### Create a LongLived task group for the specified +task_class+ that will
	### run a maximum of +max_workers+.
	def initialize( task_class, max_workers )
		super

		@queue              = nil
		@pids               = Set.new
		@started_one_worker = false
	end


	######
	public
	######

	# The PIDs of the child this task group manages
	attr_reader :pids


	### Return +true+ if the task group should scale up by one.
	def needs_a_worker?
		return true unless self.started_one_worker?
		return false unless @queue
		if ( cc = @queue.consumer_count ) >= self.max_workers
			self.log.debug "Already at max workers (%d)" % [ self.max_workers ]
			return false
		else
			self.log.debug "Not yet at max workers (have %d)" % [ cc ]
		end
		self.log.debug "Mean jobcount is %0.2f" % [ self.mean_jobcount ]
		return self.mean_jobcount > 1 && !self.sample_values_decreasing?
	end


	### Returns +true+ if the group has started at least one worker. Used to avoid
	### racing to start workers when one worker has started, but we haven't yet connected
	### to AMQP to get consumer count yet.
	def started_one_worker?
		return @started_one_worker
	end


	### If the number of workers is not at the maximum, start some.
	def adjust_workers
		self.sample_queue_status

		return nil if self.throttled?

		if self.needs_a_worker?
			self.log.info "Too few workers for (%s); spinning one up." % [ self.task_class.name ]
			pid = self.start_worker( @started_one_worker )
			self.pids.add( pid )
			return [ pid ]
		end

		return nil
	end


	### Add the current number of workers to the samples.
	def sample_queue_status
		return unless @queue
		self.add_sample( @queue.message_count )
	end


	### Overridden to grab a Bunny::Queue for monitoring when the first
	### worker starts.
	def start_worker( exit_on_idle=false )
		@started_one_worker = true

		pid = super
		self.log.info "Start a new worker at pid %d" % [ pid ]

		unless @queue
			begin
				channel = Symphony::Queue.amqp_channel
				@queue = channel.queue( self.task_class.queue_name, passive: true, prefetch: 0 )
				self.log.debug "  got the 0-prefetch queue"
			rescue Bunny::NotFound => err
				self.log.info "Child hasn't created the queue yet; deferring"
				Symphony::Queue.reset
			end
		end

		return pid
	end

end # class Symphony::TaskGroup::LongLived


