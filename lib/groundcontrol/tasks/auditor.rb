#!/usr/bin/env ruby

require 'pathname'
require 'tmpdir'
require 'groundcontrol/task' unless defined?( GroundControl::Task )


# A spike to log events
class Auditor < GroundControl::Task

	# Audit all events
	subscribe_to '#'

	### Create a new Pinger task for the given +job+ and +queue+.
	def initialize( queue )
		super
		@logdir = Pathname( Dir.tmpdir )
		@logfile = @logdir + 'events.log'
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
		msg = "%s %s" % [ metadata, payload ]
		puts( msg )
		@log.puts( msg )
	end


end # class Auditor

