#!/usr/bin/env ruby

require 'pluginfactory'

require 'laika' unless defined?( LAIKA )
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )


# Task logic for GroundControl. A task is the subclassable unit of work that the
# gcworkerd actually instantiates and runs when a job is fetched.
class LAIKA::GroundControl::Task
	include PluginFactory


	### PluginFactory API -- set the directory/directories that will be search when trying to
	### load tasks by name.
	def self::derivative_dirs
		['laika/groundcontrol/tasks']
	end


	### Create a new instance of the task for the given +job+ from the specified +queue+.
	def initialize( queue, job )
		@arguments = job.task_arguments
	end




	
	def on_startup
	end

	def on_completion
	end

	def on_error
	end


end # class LAIKA::GroundControl::Queue

