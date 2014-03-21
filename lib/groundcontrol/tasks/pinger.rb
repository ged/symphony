#!/usr/bin/env ruby

require 'socket'
require 'timeout'
require 'groundcontrol/task' unless defined?( GroundControl::Task )


### A proof-of-concept task to determine ssh availability of a host.
class GroundControl::Task::Pinger < GroundControl::Task

	# The topic key to subscribe to
	subscribe_to 'monitor.availability.port',
	             'host.ping'

	# Send success/failure back to the queue on job completion.  Then true, the
	# work isn't considered complete until receiving a success ack.  When false,
	# a worker simply consuming the task is sufficient.
	acknowledge false # default: true

	# Timeout for performing work.  NOT to be confused with the message TTL
	# during queue lifetime.
	timeout 10.minutes # default: no timeout

	# Whether the task should exit after doing its work
	work_model :oneshot # default: :longlived


	# The default port
	DEFAULT_PORT = 'ssh'


	### Create a new Pinger task for the given +job+ and +queue+.
	def initialize
		super
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
	def work( payload, metadata )
		return ping( payload['hostname'], payload['port'] )
	end


end # class GroundControl::Task::Pinger

