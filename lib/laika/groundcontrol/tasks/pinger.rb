#!/usr/bin/env ruby

require 'socket'
require 'timeout'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl::Task )


### A proof-of-concept task to determine the network availability of a host.
class LAIKA::GroundControl::Task::Pinger < LAIKA::GroundControl::Task

	# The default port
	DEFAULT_PORT = 'echo'

	# The number of seconds to wait for a connection attempt
	DEFAULT_TIMEOUT = 5.seconds


	### Create a new Pinger task for the given +job+ and +queue+.
	def initialize( queue, job )
		super

		opts = self.job.task_arguments.shift || {}

		@hostname = opts[:hostname] or
			raise ArgumentError, "no hostname specified"
		@port     = Socket.getservbyname( opts[:port] || DEFAULT_PORT )
		@timeout  = Integer( opts[:timeout] || DEFAULT_TIMEOUT )

		@problem = nil
	end


	######
	public
	######

	# The hostname to ping
	attr_reader :hostname

	# The (TCP) port to ping
	attr_reader :port

	# The number of seconds to wait before timing out when pinging
	attr_reader :timeout

	# If there is a problem pinging the remote host, this is set to the exception
	# raised when doing so.
	attr_reader :problem


	#
	# Task API
	#

	### Do the ping.
	def run
		tcp = nil
		Timeout.timeout( self.timeout ) do
			tcp = TCPSocket.new( self.hostname, self.port )
		end

	rescue Timeout::Error
		@problem = "timed out"

	rescue Errno::ECONNREFUSED => err
		@problem = "no ssh service"

	ensure
		tcp.close if tcp
	end


	### Report on what we found
	def on_completion
		if self.problem
			self.log.warn "Host '%s' is NOT available: %s" % [
				self.hostname,
				self.problem
			]

		else
			self.log.warn "Host '%s' is available!" % [ self.hostname ]
		end
	end



	#########
	protected
	#########

	### Return a human-readable description of the task.
	def description
		svcname = Socket.getservbyport( self.port )
		return "Pinging the %s port of %s" % [ svcname, self.hostname ]
	end

end # class LAIKA::GroundControl::Task::Pinger

