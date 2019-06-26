# -*- ruby -*-
#encoding: utf-8

require 'rusage'
require 'metriks'
require 'metriks/reporter/logger'
require 'metriks/reporter/proc_title'

require 'symphony' unless defined?( Symphony )


# Metrics for Symphony Tasks.
module Symphony::Metrics

	#
	# Instance methods
	#

	### Set up metrics and reporters on creation.
	def initialize( * )
		super

		@metriks_registry = Metriks::Registry.new
		@job_timer = @metriks_registry.timer( 'job.duration' )
		@job_counter = @metriks_registry.meter( 'job.count' )

		@rusage_gauge = @metriks_registry.gauge('job.rusage') { Process.rusage.to_h }

		@log_reporter = Metriks::Reporter::Logger.new(
			logger: Loggability[ Symphony ],
			registry: @metriks_registry,
			prefix: self.class.name )
		@proc_reporter = Metriks::Reporter::ProcTitle.new(
			prefix: self.procname,
			registry: @metriks_registry,
			on_error: lambda {|ex| self.log.error(ex) } )

		@proc_reporter.add( 'jobs' ) do
			@job_counter.count
		end
		@proc_reporter.add( 'jobs', '/sec' ) do
			@job_counter.one_minute_rate
		end
	end


	##
	# The Metriks::Registry that tracks all metrics for this job
	attr_reader :metriks_registry

	##
	# The job timer metric
	attr_reader :job_timer

	##
	# The job counter metric
	attr_reader :job_counter


	### Set up metrics on startup.
	def start
		@log_reporter.start
		@proc_reporter.start

		super
	end


	### Reset metrics on restart.
	def restart
		self.metriks_registry.clear
		super
	end


	### Add metrics to the task's work block.
	def work( payload, metadata )
		self.job_counter.mark
		self.job_timer.time do
			super
		end
	end

end # module Symphony::Metrics

