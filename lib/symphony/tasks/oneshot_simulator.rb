#!/usr/bin/env ruby

require 'pathname'
require 'tmpdir'
require 'symphony/task' unless defined?( Symphony::Task )
require 'symphony/metrics'

# A spike to test out various task execution outcomes.
class OneshotSimulator < Symphony::Task
	prepend Symphony::Metrics

	# Simulate processing all events
	subscribe_to '#'

	# Fetch 100 events at a time
	prefetch 100

	# Only allow 2 seconds for work to complete before rejecting or retrying.
	timeout 2.0, action: :retry

	# Run once per job
	work_model :oneshot



	######
	public
	######

	#
	# Task API
	#

	# Do the ping.
	def work( payload, metadata )
		if metadata[:properties][:headers] &&
		   metadata[:properties][:headers]['x-death']
			puts "Deaths! %p" % [ metadata[:properties][:headers]['x-death'] ]
		end

		val = Random.rand
		case
		when val < 0.1
			$stderr.puts "Simulating an error in the task (reject)."
			raise "OOOOOPS!"
		when val < 0.15
			$stderr.puts "Simulating a soft failure in the task (reject+requeue)."
			return false
		when val < 0.20
			$stderr.puts "Simulating a timeout case"
			sleep( self.class.timeout + 1 )
		else
			$stderr.puts "Simulating a successful task run (accept)"
			puts( payload.inspect )
			return true
		end
	end


end # class OneshotSimulator

