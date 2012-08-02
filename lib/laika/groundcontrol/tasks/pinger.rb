#!/usr/bin/env ruby

require 'socket'
require 'timeout'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl::Task )


### A proof-of-concept task to determine the network availability of a host.
class LAIKA::GroundControl::Task::Pinger < LAIKA::GroundControl::Task

	extend Loggability
	log_to :laika


	# The default port
	DEFAULT_PORT = 'echo'

	# The number of seconds to wait for a connection attempt
	DEFAULT_TIMEOUT = 5.seconds


	### Create a new Pinger task for the given +job+ and +queue+.
	def initialize( queue, job )
		super

		args = Array( self.job.task_arguments )

		@hostname = args.shift or
			raise ArgumentError, "no hostname specified"
		@port     = Socket.getservbyname( args.shift || DEFAULT_PORT )
		@timeout  = Integer( args.shift || DEFAULT_TIMEOUT )

		@unavailable = nil
	end


	# The hostname and port to ping, and the number of seconds to wait before timing out
	attr_reader :hostname, :port, :timeout

	# The current state of the host on network -- nil (if available) or
	# the Exception object responsible for the unavailability
	attr_reader :unavailable


	#
	# Task API
	#

	### Do the ping.
	def run
		tcp = nil
		Timeout.timeout( self.timeout ) do
			tcp = TCPSocket.new( self.hostname, self.port )
		end

	rescue Errno::ECONNREFUSED
		# fallthrough

	rescue => err
		@unavailable = err

	ensure
		tcp.close if tcp
	end


	### Report on what we found
	def on_completion
		if self.unavailable.nil?
			self.log.warn "Host '%s' is available!" % [ self.hostname ]
		else
			self.log.warn "Host '%s' is NOT available: %s" % [
				self.hostname,
				self.unavailable.message
			]
		end
	end

end # class LAIKA::GroundControl::Task::Pinger

