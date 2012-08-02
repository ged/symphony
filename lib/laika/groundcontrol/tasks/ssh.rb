#!/usr/bin/env ruby

require 'open3'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl )


### A base SSH class for connecting to remote hosts, running commands,
### and collecting output.
class LAIKA::GroundControl::Task::SSH < LAIKA::GroundControl::Task

	extend Loggability, Configurability
	log_to :laika
	config_key :task_ssh

	# The default path to the ssh binary.
	@path = '/usr/bin/ssh'

	# Default ssh behavior arguments.
	@ssh_args = [
		'-e', 'none',
		'-T',
		'-x',
		'-o', 'CheckHostIP=no',
		'-o', 'KbdInteractiveAuthentication=no',
		'-o', 'StrictHostKeyChecking=no'
	]

	class << self
		attr_accessor :path, :ssh_args
	end

	### Configurability API
	def self::configure( config )
		return unless config
		self.path = config[:path] if config[:path]
	end


	### Create a new SSH task for the given +job+ and +queue+.
	def initialize( queue, job )
		super
		opts = self.job.task_arguments

		# required arguments
		@hostname = opts[:hostname] or raise ArgumentError, "no hostname specified"
		@command  = opts[:command]  or raise ArgumentError, "no command specified"

		# optional arguments
		@port = opts[:port] || 22
		@user = opts[:user] || 'root'
		@key  = opts[:key]

		@output = nil
		@return_value = nil
	end


	# The hostname to connect to.
	attr_reader :hostname

	# The command to run on the remote host.
	attr_reader :command

	# A public key that's expected to be installed on the remote
	# host(s).
	attr_reader :key

	# Overrides the default SSH port should the remote host not be
	# listening on the default port.
	attr_reader :port

	# Connect to the remote host as this user. Defaults to 'root'.
	attr_reader :user


	### Call ssh and capture output.
	def run
		@return_value = self.spawn do |stdin, stdout, _|
			@output = self.run_command( stdin, stdout, self.command )
		end
	end


	### Emit the output from the remote ssh call
	def on_completion
		self.log.info "Remote exited with %d, output: %s" % [ @return_value.exitstatus, @output ]
	end


	#########
	protected
	#########

	### Call ssh and yield the remote IO objects to the caller,
	### cleaning up afterwards.
	def spawn
		raise LocalJumpError, "no block given" unless block_given?
		return_value = nil

		cmd = []
		cmd << self.class.path
		cmd << self.class.ssh_args
		cmd << '-p' << self.port.to_s
		cmd << '-i' << self.key if self.key
		cmd << '-l' << self.user
		cmd << self.hostname

		cmd.flatten!
		self.log.debug "Running SSH command with: %p" % [ cmd ]

		Open3.popen3( *cmd ) do |stdin, stdout, stderr, thread|
			yield( stdin, stdout, stderr )
			return_value = thread.value
		end

		return return_value
	end

	### Sends a command and closes remote half of the pipe
	def run_command( stdin, stdout, command )
		stdin.puts( command )
		stdin.close
		return stdout.read
	end

end # class LAIKA::GroundControl::Task::SSH

