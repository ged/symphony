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
		@queue = nil
	end


	######
	public
	######

	### If the number of workers is not at the maximum, start some.
	def adjust_workers
		self.sample_queue_status

		return nil if self.throttled?

		if self.needs_a_worker?
			self.log.info "Too few workers for (%s); spinning one up." % [ self.task_class.name ]
			pid = self.start_worker( !self.workers.empty? )
			return [ pid ]
		end

		@queue ||= self.get_message_counting_queue

		return nil
	end


	### Return +true+ if the task group should scale up by one.
	def needs_a_worker?
		return true if self.workers.empty?
		return false unless @queue


		# Calculate the number of workers across the whole broker
		if ( cc = @queue.consumer_count ) >= self.max_workers
			self.log.debug "%p: Already at max workers (%d)" % [ self.task_class, self.max_workers ]
			return false
		else
			self.log.debug "%p: Not yet at max workers (have %d)" % [ self.task_class, cc ]
		end

		self.log.debug "Mean jobcount is %0.2f" % [ self.mean_jobcount ]
		return self.mean_jobcount > 1 && !self.sample_values_decreasing?
	end


	### Add the current number of workers to the samples.
	def sample_queue_status
		return unless @queue

		count = @queue.message_count
		self.add_sample( count )

	rescue Bunny::ChannelAlreadyClosed => err
		self.log.debug "Unexpected queue state, resetting: "% [ err.message ]
		@queue = nil
	end


	### Overridden to grab a Bunny::Queue for monitoring when the first
	### worker starts.
	def start_worker( exit_on_idle=false )
		pid = super
		self.log.info "Start a new worker at pid %d" % [ pid ]

		return pid
	end


	### Get a queue for counting the number of messages in the queue for this
	### worker.
	def get_message_counting_queue
		channel = Symphony::Queue.amqp_channel
		queue = channel.queue( self.task_class.queue_name, passive: true, prefetch: 0 )

		return queue
	rescue Bunny::NotFound => err
		self.log.info "Child hasn't created the queue yet; deferring"
		Symphony::Queue.reset

		return nil
	end

end # class Symphony::TaskGroup::LongLived


