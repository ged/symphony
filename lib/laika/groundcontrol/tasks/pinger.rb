#!/usr/bin/env ruby

require 'timeout'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl )


# Queueing logic for GroundControl jobs.
class LAIKA::GroundControl::Task::Pinger

	# The number of seconds to wait for a connection attempt
	DEFAULT_TIMEOUT = 15.seconds


	#
	# Task API
	#	

	### Do the ping.
	def run( hostname, port, timeout=DEFAULT_TIMEOUT )
		tcp = nil
		Timeout.timeout( timeout ) do
			tcp = TCPSocket.new( hostname, port )
		end
	ensure
		tcp.close if tcp
	end


	### Handle any errors while pinging. On timeout, requeue.
	def on_error( exception, queue, job )
		case exception
		when Timeout::Timeout
			queue.add( job )
		end
	end


end # class LAIKA::GroundControl::Queue

