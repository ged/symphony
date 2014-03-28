#!/usr/bin/env ruby

require 'shellwords'
require 'symphony/task' unless defined?( Symphony::Task )


### A base SSH class for connecting to remote hosts, running commands,
### and collecting output.
class Symphony::Task::SSH < Symphony::Task
	extend MethodUtilities

	### Create a new SSH task for the given +job+ and +queue+.
	def initialize( queue, job )
		super

		# The default path to the ssh binary.
		@path = self.options[:ssh_path] || '/usr/bin/ssh'

		# Default ssh behavior arguments.
		@ssh_args = self.options[:ssh_args] || [
			'-e', 'none',
			'-T',
			'-x',
			'-q',
			'-o', 'CheckHostIP=no',
			'-o', 'BatchMode=yes',
			'-o', 'StrictHostKeyChecking=no'
		]

		# required arguments
		@hostname = self.options[:hostname] or raise ArgumentError, "no hostname specified"
		@command  = self.options[:command]  or raise ArgumentError, "no command specified"

		# optional arguments
		@port = self.options[:port] || 22
		@user = self.options[:user] || 'root'
		@key  = self.options[:key]

		@output = nil
		@return_value = nil
	end

	# The default path to the ssh binary.
	attr_reader :path

	# Default ssh behavior arguments.
	attr_reader :ssh_args

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
		if @return_value
			self.log.info "Remote exited with %d, output: %s" % [ @return_value.exitstatus, @output ]
		end
	end


	#########
	protected
	#########

	### Call ssh and yield the remote IO objects to the caller,
	### cleaning up afterwards.
	def open_connection
		raise LocalJumpError, "no block given" unless block_given?

		fqdn = self.expand_hostname( self.hostname ).
			find {|hostname| self.ping(hostname, self.port) } or
			raise "Unable to find an on-network host for %s:%d" % [ self.hostname, self.port ]

		cmd = []
		cmd << self.path
		cmd += self.ssh_args
		cmd << '-p' << self.port.to_s
		cmd << '-i' << self.key if self.key
		cmd << '-l' << self.user
		cmd << fqdn
		cmd.flatten!
		self.log.debug "Running SSH command with: %p" % [ Shellwords.shelljoin(cmd) ]

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


end # class Symphony::Task::SSH

