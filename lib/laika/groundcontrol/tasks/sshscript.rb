#!/usr/bin/env ruby

require 'net/ssh'
require 'net/sftp'
require 'tmpdir'
require 'inversion'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl::Task )


# A task to execute a script on a remote host via SSH.
#
#   require 'laika'
#
#   LAIKA.require_features( :groundcontrol )
#   LAIKA.load_config( 'config.yml' )
#
#   queue = LAIKA::GroundControl.default_queue
#   queue.add( 'sshscript',
#              hostname: 'roke',
#              template: 'fbsd-inventory.rb',
#              key: "#{datadir}/laika-inventory/inventory.rsa",
#              attributes: { inventorykey: '0f2dbe12c982248662f3dafcab2aade1'} )
#
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
		# :logger                  => Loggability[ Net::SSH ],
		:paranoid                => false,
		:timeout                 => 10.seconds,
		# :verbose                 => :debug,
		:global_known_hosts_file => '/dev/null',
		:user_known_hosts_file   => '/dev/null',
	}


	### Create a new SSH task for the given +job+ and +queue+.
	def initialize( queue, job )
		super

		# required arguments
		@hostname   = self.options[:hostname] or raise ArgumentError, "no hostname specified"
		@template   = self.options[:template] or raise ArgumentError, "no script template specified"
		@key        = self.options[:key]      or raise ArgumentError, "no private key specified"

		# optional arguments
		@port       = self.options[:port] || 22
		@user       = self.options[:user] || 'root'
		@attributes = self.options[:attributes] || {}
	end


	######
	public
	######

	# The name of the host to connect to
	attr_reader :hostname

	# The path to the script template
	attr_accessor :template

	# The path to the SSH key to use for auth
	attr_reader :key

	# The SSH port to use
	attr_reader :port

	# The user to connect as
	attr_reader :user

	# Attributes that will be set on the script template.
	attr_reader :attributes


	### Load the script as an Inversion template, sending and executing
	### it on the remote host.
	def run
		fqdn = self.expand_hostname( self.hostname ).
			find {|hostname| self.ping(hostname, self.port) }

		unless fqdn
			self.log.debug "Unable to find an on-network host for %s:%d" %
				[ self.hostname, self.port ]
			return
		end

		remote_filename = self.make_remote_filename
		source = self.generate_script

		# Establish the SSH connection
		ssh_options = DEFAULT_SSH_OPTIONS.merge( :port => self.port, :keys => [self.key] )
		self.with_timeout do
			Net::SSH.start( fqdn, self.user, ssh_options ) do |conn|
				self.upload_script( conn, source, remote_filename )
				self.run_script( conn, remote_filename )
			end
		end
	end


	#########
	protected
	#########

	# Running script 'test_script' on 'roke.pg.laika.com:22' as 'inventory'

	### Return a human-readable description of details of the task.
	def description
		return "Running script '%s' on '%s:%d' as '%s'" % [
			File.basename( self.template ),
			self.hostname,
			self.port,
			self.user,
		]
	end


	### Generate a unique filename for the script on the remote host.
	def make_remote_filename
		template = self.template
		basename = File.basename( template, File.extname(template) )

		tmpname = Dir::Tmpname.make_tmpname( basename, Process.pid )

		return "/tmp/#{tmpname}"
	end


	### Generate a script by loading the script template, populating it with
	### attributes, and rendering it.
	def generate_script
		tmpl = Inversion::Template.load( self.template, TEMPLATE_OPTS )

		tmpl.attributes.merge!( self.attributes )
		tmpl.task   = self

		return tmpl.render
	end

	### Render the given +template+ as script source, then use the specified +conn+ object
	### to upload it.
	def upload_script( conn, source, remote_filename )
		self.log.debug "Uploading script (%d bytes) to %s:%s." %
			[ source.bytesize, self.hostname, remote_filename ]
		conn.sftp.file.open( remote_filename, "w", 0755 ) do |fh|
			fh.print( source )
		end
		self.log.debug "  done with the upload."
	end


	### Run the script on the remote host.
	def run_script( conn, remote_filename )
		output = conn.exec!( remote_filename )
		self.log.debug "Output was:\n#{output}"
		conn.exec!( "rm #{remote_filename}" )
	end

end # class LAIKA::GroundControl::Task::SSHScript

