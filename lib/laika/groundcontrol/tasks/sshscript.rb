#!/usr/bin/env ruby

require 'net/ssh'
require 'net/sftp'
require 'tmpdir'
require 'inversion'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl::Task )


### A class to stream and execute a script on a remote host via SSH.
class LAIKA::GroundControl::Task::SSHScript < LAIKA::GroundControl::Task
	extend Loggability,
	       LAIKA::MethodUtilities

	# Loggability API -- Log to LAIKA's logger
	log_to :laika


	# Template config
	TEMPLATE_OPTS = {
		:ignore_unknown_tags => false,
		:on_render_error     => :propagate,
		:strip_tag_lines     => true
	}

	# The defaults to use when connecting via SSH
	DEFAULT_SSH_OPTIONS = {
		:auth_methods            => [ "publickey" ],
		:compression             => true,
		:config                  => false,
		:keys_only               => true,
		:logger                  => Loggability[ Net::SSH ],
		:paranoid                => false,
		:timeout                 => 10.seconds,
		:verbose                 => Loggability[ Net::SSH ].level,
		:global_known_hosts_file => '/dev/null',
		:user_known_hosts_file   => '/dev/null',
	}


	### Create a new SSH task for the given +job+ and +queue+.
	def initialize( queue, job )
		super
		opts = self.job.task_arguments

		# :TODO: Script arguments?
		# required arguments
		@hostname = opts[:hostname] or raise ArgumentError, "no hostname specified"
		@script   = opts[:script]   or raise ArgumentError, "no script template specified"
		@key      = opts[:key]      or raise ArgumentError, "no private key specified"

		# optional arguments
		@port            = opts[:port] || 22
		@user            = opts[:user] || 'root'
		@attributes      = opts[:attributes] || {}

		# Runtime state
		@ssh_conn        = nil
		@remote_filename = nil
	end


	######
	public
	######

	# The name of the host to connect to
	attr_reader :hostname

	# The rendered script string.
	attr_accessor :script

	# The path to the SSH key to use for auth
	attr_reader :key

	# The SSH port to use
	attr_reader :port

	# The user to connect as
	attr_reader :user

	# Attributes that will be set on the script template.
	attr_reader :attributes

	# The Net::SSH::Session object used by the task
	attr_accessor :ssh_conn

	# The remote filename the script will be written to
	attr_accessor :remote_filename


	### Find and 'compile' the script template, and connect to the remote host.
	def on_startup
		taskname = self.class.name.sub( /.*::/, '' ).downcase + 
			'-' + self.hostname.sub( /\..*/, '' ) + '-'
		self.remote_filename = Dir::Tmpname.make_tmpname( taskname, 'script' )

		# Load the script template and render it into the script to run
		self.script = Inversion::Template.load( self.script, TEMPLATE_OPTS )
		self.script.attributes.merge!( self.attributes )
		self.script.task_arguments = self.job.task_arguments
		self.script.job = self.job.to_s
		self.script.queue = self.job.queue_name

		# Establish the SSH connection
		ssh_options = DEFAULT_SSH_OPTIONS.merge( :port => self.port, :keys => [self.key] )
		self.ssh_conn = Net::SSH.start( self.hostname, self.user, ssh_options )
	end


	### Load the script as an Inversion template, sending and executing
	### it on the remote host.
	def run
		self.upload_script( self.ssh_conn, self.script, self.remote_filename )
		self.run_script( self.ssh_conn, self.remote_filename )
	end


	### Close the ssh connection.
	def on_shutdown
		self.ssh_conn.close if self.ssh_conn && !self.ssh_conn.closed?
		super
	end


	#########
	protected
	#########

	### Render the given +template+ as script source, then use the specified +conn+ object
	### to upload it.
	def upload_script( conn, template, remote_filename )
		source = template.render

		self.log.debug "Uploading script (%d bytes) to %s:%s." %
			[ source.bytesize, self.hostname, remote_filename ]
		conn.sftp.file.open( remote_filename, "w", 0755 ) do |fh|
			fh.print( source )
		end
		self.log.debug "  done with the upload."
	end


	### Run the script on the remote host.
	def run_script( conn, remote_filename )
		output = conn.exec!( './' + remote_filename )
		self.log.debug "Output was:\n#{output}"
		conn.exec!( "rm #{remote_filename}" )
	end

end # class LAIKA::GroundControl::Task::SSHScript

