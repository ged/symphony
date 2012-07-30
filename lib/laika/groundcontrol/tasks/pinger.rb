#!/usr/bin/env ruby

require 'socket'
require 'timeout'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl )


# Queueing logic for GroundControl jobs.
class LAIKA::GroundControl::Task::Pinger

	# The default port
	DEFAULT_PORT = 'echo'

	# The number of seconds to wait for a connection attempt
	DEFAULT_TIMEOUT = 15.seconds


	### Create a new Pinger task for the given +job+ and +queue+.
	def initialize( queue, job )
		super

		args = self.job.task_arguments

		@hostname = args.shift or
			raise ArgumentError, "no hostname specified"
		@port     = Socket.getservbyname( args.shift || DEFAULT_PORT )
		@timeout  = Integer( args.shift || DEFAULT_TIMEOUT )
	end


	# The hostname and port to ping, and the number of seconds to wait before timing out
	attr_reader :hostname, :port, :timeout



	#
	# Task API
	#	

	### Do the ping.
	def run
		tcp = nil
		Timeout.timeout( self.timeout ) do
			tcp = TCPSocket.new( self.hostname, self.port )
		end
	ensure
		tcp.close if tcp
	end


end # class LAIKA::GroundControl::Queue

