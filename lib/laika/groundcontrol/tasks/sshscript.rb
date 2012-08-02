#!/usr/bin/env ruby

require 'inversion'
require 'laika/groundcontrol/task' unless defined?( LAIKA::GroundControl )
require 'laika/groundcontrol/tasks/ssh' unless defined?( LAIKA::GroundControl::Task::SSH )


### A class to stream and execute a script on a remote host via SSH.
class LAIKA::GroundControl::Task::SSHScript < LAIKA::GroundControl::Task::SSH

	extend Loggability
	log_to :laika

	# Default options for script templates
	@template_opts = {
		:ignore_unknown_tags => false,
		:on_render_error     => :propagate,
		:strip_tag_lines     => true
	}

	class << self
		attr_accessor :template_opts
	end


	### Create a new SSH task for the given +job+ and +queue+.
	def initialize( queue, job )
		super
		opts = self.job.task_arguments

		# :TODO: Script arguments?

		# optional arguments
		@attributes = opts[:attributes] || {}
	end

	# Attributes that will be set on the script template.
	attr_reader :attributes

	# The rendered script string.
	attr_reader :script


	### Find and 'compile' the script template.
	def on_startup
		@command = Inversion::Template.load( self.command, self.class.template_opts )
		@command.attributes.merge!( self.attributes )
		@script = @command.render

	rescue RuntimeError => err
		self.log.error "Error with template: %s" % [ err.message ]

	rescue Inversion::ParseError => err
		self.log.error "Unable to parse script template (retrying): %s" % [ err.message ]
		raise LAIKA::GroundControl::AbortTask
	end


	### Load the script as an Inversion template, sending and executing
	### it on the remote host.
	def run
		self.log.warn @script
		# @return_value = self.spawn do |stdin, stdout, _|
		#     @output = self.send_and_execute( stdin, stdout, self.script )
		# end
	end


	def on_completion
	end


	#########
	protected
	#########

	###

end # class LAIKA::GroundControl::Task::SSHScript

