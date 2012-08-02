#!/usr/bin/env ruby

require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl::Task )


### A base SSH class for connecting to remote hosts, running commands,
### and collecting output.
class LAIKA::GroundControl::Task::SSH < LAIKA::GroundControl::Task
	extend Loggability,
	       Configurability,
	       LAIKA::MethodUtilities

	# Loggability API -- log to the laika logger
	log_to :laika

	# Configurability API -- configure via the 'task_ssh' section of the config
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


	# The path the the ssh binary
	singleton_attr_accessor :path

	# The arguments to the ssh binary
	singleton_attr_accessor :ssh_args


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

	# The key to use for authentication.
	attr_reader :key

	# The remote ssh port.
	attr_reader :port

	# Connect to the remote host as this user. Defaults to 'root'.
	attr_reader :user


	### Call ssh and capture output.
	def run
		@return_value = self.open_connection do |reader, writer|
			self.log.debug "Writing command #{self.command}..."
			writer.puts( self.command )
			self.log.debug "  closing child's writer."
			writer.close
			self.log.debug "  reading from child."
			reader.read
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
	def open_connection
		raise LocalJumpError, "no block given" unless block_given?

		cmd = []
		cmd << self.class.path
		cmd << self.class.ssh_args
		cmd << '-p' << self.port.to_s
		cmd << '-i' << self.key if self.key
		cmd << '-l' << self.user
		cmd << self.hostname

		cmd.flatten!
		self.log.debug "Running SSH command with: %p" % [ cmd ]

		parent_reader, child_writer = IO.pipe
		child_reader, parent_writer = IO.pipe

		pid = spawn( *cmd, :out => child_writer, :in => child_reader, :close_others => true )
		child_writer.close
		child_reader.close

		self.log.debug "Yielding back to the run block."
		@output = yield( parent_reader, parent_writer )
		self.log.debug "  run block done."

		pid, status = Process.waitpid2( pid )
		return status
	end

end # class LAIKA::GroundControl::Task::SSH

