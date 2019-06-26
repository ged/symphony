#!/usr/bin/env ruby

require 'pathname'
require 'tmpdir'
require 'symphony/task' unless defined?( Symphony::Task )
require 'symphony/metrics'

# A spike to test out various task execution outcomes.
class Simulator < Symphony::Task
	prepend Symphony::Metrics

	# Simulate processing all events
	subscribe_to '#'

	# Fetch 100 events at a time
	prefetch 10

	# Keep the queue around even when the task isn't running
	persistent true

	# Only allow 2 seconds for work to complete before rejecting or retrying.
	# timeout 2.0, action: :retry


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

		sleep rand( 0.0 .. 2.0 )

		val = Random.rand
		case
		when val < 0.05
			$stderr.puts "Simulating an error in the task (reject)."
			raise "OOOOOPS!"
		when val < 0.10
			$stderr.puts "Simulating a soft failure in the task (reject+requeue)."
			return false
		when val < 0.15
			$stderr.puts "Simulating a timeout case"
			sleep( self.class.timeout + 1 ) if self.class.timeout
		else
			$stderr.puts "Simulating a successful task run (accept)"
			puts( payload.inspect )
			return true
		end

		true
	end


end # class Simulator

