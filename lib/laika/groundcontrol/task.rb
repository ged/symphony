#!/usr/bin/env ruby

require 'timeout'
require 'loggability'
require 'pluginfactory'

require 'laika' unless defined?( LAIKA )
require 'laika/mixins'
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )


# Task logic for GroundControl. A task is the subclassable unit of work that the
# gcworkerd actually instantiates and runs when a job is fetched. A Job is a request
# for the execution of a Task with a specific configuration.
#
# To create a new Task, subclass LAIKA::GroundControl::Task, and provide an implementation
# of the #run method. The #run method should contain all of the actual work of the task.
# Additional callbacks are available for {setting up the task}[rdoc-ref:on_startup],
# {handling exceptions}[rdoc-ref:on_error], {handling successful completion}[rdoc-ref:on_completion],
# and {handling task shutdown}[rdoc-ref:on_shutdown].
#
# You can also override the #description method to provide a description of the task
# for human consumption, such as in a list of tasks in the shell or a web interface.
#
#   require 'net/http'
#   require 'timeout'
#   require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl::Task )
#
#   class LAIKA::GroundControl::Task::HttpCheck < LAIKA::GroundControl::Task
#
#       def initialize( queue, job )
#           super
#           opts = self.job.task_options.shift || {}
#           @host = opts[:host]
#       end
#
#       attr_reader :host
#
#       def run
#           Net::HTTP.get( self.host, '/' )
#       end
#
#       def on_error( exception )
#           msg = "WWW service on %s is down: %s" % [ self.host, exception.message ]
#           self.queue.add( :notification,
#                           recipients: 'it-alerts@lists.laika.com',
#                           message: msg )
#       end
#
#   end
#
class LAIKA::GroundControl::Task
	extend Loggability,
	       PluginFactory
	include LAIKA::AbstractClass


	# Loggability API -- log to LAIKA's logger
	log_to :laika


	# The number of seconds to wait for a connection attempt
	DEFAULT_TIMEOUT = 5.seconds


	### PluginFactory API -- set the directory/directories that will be search when trying to
	### load tasks by name.
	def self::derivative_dirs
		['laika/groundcontrol/tasks']
	end


	### Create a new instance of the task for the given +job+ from the specified +queue+.
	def initialize( queue, job )
		@queue   = queue
		@job     = job
		@options = job.task_options || {}
		@timeout = self.options[:timeout] || DEFAULT_TIMEOUT
	end


	# The LAIKA::GroundControl::Queue the task's Job was queued in.
	attr_reader :queue

	# The LAIKA::GroundControl::Job the task belongs to
	attr_reader :job

	# The task options given to the job
	attr_reader :options

	# The number of seconds to wait before timing out when pinging
	attr_reader :timeout


	#
	# :section:
	#

	### Stringify the task as a description.
	def to_s
		class_desc = self.class.name.scan( /((?:\b|[A-Z])[^A-Z]+)/ ).
			flatten.map{|c| c.sub( '::', '' )}.join( ' ' )
		detail_desc = self.description
		return "%s%s" % [ class_desc, detail_desc ? ": #{detail_desc}" : '' ]
	end



	#
	# :section: Task API
	# These are the methods you will likely be interested in overriding when writing your
	# own task type. You're only _required_ to implement #run.
	#

	### Task API -- callback called when the task first starts up, before it is run. This should
	### only be used to provide any additional preparation for the gcworkerd child that the
	### Worker object doesn't handle itself, such as file descriptor cleanup, switching users,
	### setting resource restrictions, etc.
	def on_startup
	end


	##
	# Task API -- the main logic of the Task goes here.
	pure_virtual :run


	### Task API -- callback called if the task aborts on a StandardError. If the task is
	### aborted with a LAIKA::GroundControl::AbortTask, the task's job is automatically
	### re-added to the queue it came from. If you don't want this to happen, just don't
	### super().
	def on_error( exception )
		if exception.is_a?( LAIKA::GroundControl::AbortTask )
			self.log.warn "Task aborted by the runner; re-queueing job %s" % [ self.job ]
			self.queue.re_add( self.job )
		else
			self.log.error "%p while running: %s: %s" %
				[ exception.class, self.job, exception.message ]
		end
	end


	### Task API -- callback called if the task completes normally.
	def on_completion
	end


	### Task API -- callback called after the task is completely finished with its run, just
	### before it exits.
	def on_shutdown
		self.job.destroy
	end


	#########
	protected
	#########

	### Provide details for the human-readable description. By default, just returns
	### +nil+, which will mean the string will only contain the description derived from
	### the task class.
	def description
		return nil
	end


	### Wrap a block in a timeout check, failing it if it takes longer than the
	### number of seconds in the task's timeout.
	def with_timeout
		Timeout.timeout( self.timeout ) do
			yield
		end
	rescue Timeout::Error
		self.log.error "Timeout waiting for response from #{hostname}"
		return false
	end


	### Check service availability of a +hostname+ at +port+ before trying to have
	### a conversation with it.
	def ping( hostname, port )
		tcp = nil

		self.log.debug "Pinging #{hostname}:#{port}..."
		val = self.with_timeout do
			tcp = TCPSocket.new( hostname, port )
		end
		self.log.debug "  success!"

		return val

	rescue Errno::ECONNREFUSED => err
		self.log.error "Connection refused on port #{port} by #{hostname}"
		return false

	ensure
		# Prevent FD leak
		tcp.close if tcp
	end


	### Expand the given +hostname+ into an Array of one or more FQDNs, either preserving it
	### as-is if it was already an FQDN, or expanding it into every possible matching FQDN
	### from LDAP if not.
	def expand_hostname( hostname )
		hosts = LAIKA::Host.find( hostname )
		return Array( hosts ).map( &:fqdn )
	end


	#######
	private
	#######

	### Abort the task and requeue it, using the the specified message in logs
	### and any reporting mechanism.
	def abort( message )
		raise LAIKA::GroundControl::AbortTask, message
	end


end # class LAIKA::GroundControl::Queue

