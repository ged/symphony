#!/usr/bin/env ruby

require 'socket'
require 'timeout'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl::Task )


### A proof-of-concept task to determine sh availability of a host.
class LAIKA::GroundControl::Task::Pinger < LAIKA::GroundControl::Task

	# The default port
	DEFAULT_PORT = 'ssh'


	### Create a new Pinger task for the given +job+ and +queue+.
	def initialize( queue, job )
		super

		@hostname = self.options[:hostname] or
			raise ArgumentError, "no hostname specified"
		@port     = Socket.getservbyname( self.options[:port] || DEFAULT_PORT )
	end


	######
	public
	######

	# The hostname to ping
	attr_reader :hostname

	# The (TCP) port to ping
	attr_reader :port

	# If there is a problem pinging the remote host, this is set to the exception
	# raised when doing so.
	attr_reader :problem


	#
	# Task API
	#

	### Do the ping.
	def run
		self.expand_hostname( self.hostname ).each do |host|
			if self.ping( host, self.port )
				puts "#{host}: OK"
			else
				puts "#{host}: NOT OK"
			end
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

