#!/usr/bin/env ruby

require 'pathname'
require 'tmpdir'
require 'groundcontrol/task' unless defined?( GroundControl::Task )


# A spike to log events
class Auditor < GroundControl::Task

	# Audit all events
	subscribe_to '#'

	#acknowledge false
	prefetch 1000

	queue_name 'foomanchoo'

	### Create a new Pinger task for the given +job+ and +queue+.
	def initialize( queue )
		super
		@logdir = Pathname( Dir.tmpdir )
		@logfile = @logdir + 'events.log'
		$stderr.puts "Logfile is: %s" % [ @logfile ]
		@log = @logfile.open( File::CREAT|File::APPEND|File::WRONLY, encoding: 'utf-8' )
	end


	######
	public
	######

	#
	# Task API
	#

	# Do the ping.
	def work( payload, metadata )
		return true
		val = Random.rand
		puts( payload.inspect )

		case
		when val < 0.33
			raise "OOOOOPS! %p" % [ payload['key'] ]
		when val < 0.66
			return false
		else
			@log.puts( payload['key'] )
			@log.flush
			return true
		end
	end


end # class Auditor

