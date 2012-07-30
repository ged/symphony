#!/usr/bin/env ruby

require 'pluginfactory'

require 'laika' unless defined?( LAIKA )
require 'laika/mixins'
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )


# Task logic for GroundControl. A task is the subclassable unit of work that the
# gcworkerd actually instantiates and runs when a job is fetched.
class LAIKA::GroundControl::Task
	include PluginFactory,
	        LAIKA::AbstractClass


	### PluginFactory API -- set the directory/directories that will be search when trying to
	### load tasks by name.
	def self::derivative_dirs
		['laika/groundcontrol/tasks']
	end


	### Create a new instance of the task for the given +job+ from the specified +queue+.
	def initialize( queue, job )
        @queue  = queue
        @job    = job
	end


	# The LAIKA::GroundControl::Queue the task's Job was queued in.
	attr_reader :queue

	# The LAIKA::GroundControl::Job the task belongs to
	attr_reader :job


	### Task API -- callback called when the task first starts up, before it is run. 
	pure_virtual :on_startup


	### Task API -- the main logic of the Task goes here.
	pure_virtual :run


	### Task API -- callback called if the task aborts on an exception. If the task is
	### aborted with a LAIKA::GroundControl::AbortTask, the task's job is automatically
	### re-added to the queue it came from. If you don't want this to happen, just don't
	### super().
	def on_error( exception )
		if exception.is_a?( LAIKA::GroundControl::AbortTask )
			self.log.warn "Task aborted by the runner; re-queueing job %s" % [ self.job ]
			self.queue.re_add( self.job )
		else
			self.log.error "%p while running: %s: %s" % [ exception.class, self.job, exception.message ]
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


	### Provide details for the human-readable description. By default, just returns
	### +nil+, which will mean the string will only contain the description derived from 
	### the task class.
	def description
		return nil
	end


	### Stringify the task as a description.
	def to_s
		class_desc = self.class.name.scan( /((?:\b|[A-Z])[^A-Z]+)/ ).join( ' ' )
		detail_desc = self.description
		return "%s%s" % [ class_desc, detail_desc ? ": #{detail_desc}" : '' ]
	end		

end # class LAIKA::GroundControl::Queue

