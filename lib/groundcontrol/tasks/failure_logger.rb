#!/usr/bin/env ruby

require 'objspace'
require 'pathname'
require 'tmpdir'
require 'groundcontrol/task' unless defined?( GroundControl::Task )
require 'groundcontrol/metrics'


# Log events that get published to the dead-letter queue
class FailureLogger < GroundControl::Task
	prepend GroundControl::Metrics

	# Audit all events
	subscribe_to '#'

	# Connect to a specific queue
	queue_name '_failures'


	### Set up the output device. By default it's STDERR, but it can be anything
	### that responds to #<<.
	def initialize( * )
		super
		@output = $stderr
		$stderr.sync = true
	end


	######
	public
	######

	#
	# Task API
	#

	# Log the failure
	# :headers=>{
	#    "x-death"=>[{
	#       "reason"=>"rejected",
	#       "queue"=>"auditor",
	#       "time"=>2014-03-12 18:55:10 -0700,
	#       "exchange"=>"events",
	#       "routing-keys"=>["some.stuff"]
	#    }]
	# }
	def work( payload, metadata )
		self.log_failure( payload, metadata )
		return true
	end


	### Log one or more +deaths+ of the failed event.
	def log_failure( payload, metadata )
		raise "No headers; not a dead-lettered message?" unless
			metadata[:properties] &&
			metadata[:properties][:headers]
		deaths = metadata[:properties][:headers]['x-death'] or
			raise "No x-death header; not a dead-lettered message?"

		message = self.log_prefix( payload, metadata )
		message << self.log_deaths( deaths )
		message << self.log_payload( payload, metadata )

		@output << message << "\n"
	end


	### Return a logging message prefix based on the specified +routing_key+ and
	### +deaths+.
	def log_prefix( payload, metadata )
		return "[%s]: " % [ Time.now.strftime('%Y-%m-%d %H:%M:%S.%4N') ]
	end


	### Return a logging message part based on the specified message +payload+.
	def log_payload( payload, metadata )
		return " -- %0.2fKB %s payload: %p" % [
			ObjectSpace.memsize_of(payload) / 1024.0,
			metadata[:content_type],
			payload,
		]
	end


	### Return a logging message part based on the specified +deaths+.
	###
	### deaths - An Array of Hashes derived from the 'x-death' headers of the message
	###
	def log_deaths( deaths )
		message = ''
		deaths.each do |death|
			message << " %s-{%s}->%s (%s)" % [
				death['exchange'],
				death['routing-keys'].join(','),
				death['queue'],
				death['reason'],
			]
		end

		return message
	end

end # class FailureLogger

