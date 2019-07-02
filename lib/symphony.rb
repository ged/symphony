#!/usr/bin/env ruby

require 'loggability'
require 'configurability'

# Symphony -- an evented asynchronous thingie.
#
# See the README for additional guidance.
#
module Symphony
	extend Loggability,
	       Configurability

	# Library version constant
	VERSION = '0.12.1'

	# Version-control revision constant
	REVISION = %q$Revision$


	# The name of the environment variable to check for config file overrides
	CONFIG_ENV = 'SYMPHONY_CONFIG'

	# The path to the default config file
	DEFAULT_CONFIG_FILE = 'etc/config.yml'


	# Loggability API -- set up symphony's logger
	log_as :symphony


	# Configurability API -- use the 'worker_daemon' section of the config
	config_key :symphony


	# Default configuration
	CONFIG_DEFAULTS = {
		throttle_max:     16,
		throttle_factor:  1,
		tasks:            [],
		scaling_interval: 0.1,
	}


	require 'symphony/mixins'
	require 'symphony/queue'
	require 'symphony/task'
	require 'symphony/task_group'
	extend Symphony::MethodUtilities

	##
	# The maximum throttle factor caused by failing workers
	singleton_attr_accessor :throttle_max
	self.throttle_max = CONFIG_DEFAULTS[:throttle_max]

	##
	# The factor which controls how much incrementing the throttle factor
	# affects the pause between workers being started.
	singleton_attr_accessor :throttle_factor
	self.throttle_factor = CONFIG_DEFAULTS[:throttle_factor]

	##
	# The Array of Symphony::Task classes that are configured to run
	singleton_attr_accessor :tasks
	self.tasks = CONFIG_DEFAULTS[:tasks]

	##
	# The maximum amount of time between task group process checks
	singleton_attr_accessor :scaling_interval
	self.scaling_interval = CONFIG_DEFAULTS[:scaling_interval]


	### Load the tasks with the specified +task_names+ and return them
	### as an Array.
	def self::load_configured_tasks
		task_config = self.tasks
		if task_config.respond_to?( :each_pair )
			return self.task_config_from_hash( task_config )
		else
			return self.task_config_from_array( task_config )
		end
	end


	### Return the Hash of +tasks+ as a Hash of Classes and the maximum number to
	### run.
	def self::task_config_from_hash( task_config )
		return task_config.each_with_object({}) do |(task_name, max), tasks|
			task_class = Symphony::Task.get_subclass( task_name )
			tasks[ task_class ] = max.to_i
		end
	end


	### Return the Array of +tasks+ as a Hash of Classes and the maximum number to
	### run.
	def self::task_config_from_array( task_config )
		return [] unless task_config
		return task_config.uniq.each_with_object({}) do |task_name, tasks|
			max = task_config.count( task_name )
			task_class = Symphony::Task.get_subclass( task_name )
			tasks[ task_class ] = max
		end
	end


	### Get the loaded config (a Configurability::Config object)
	def self::config
		Configurability.loaded_config
	end


	### Load the specified +config_file+, install the config in all objects with
	### Configurability, and call any callbacks registered via #after_configure.
	def self::load_config( config_file=nil, defaults=nil )
		config_file ||= ENV[ CONFIG_ENV ] || DEFAULT_CONFIG_FILE
		defaults    ||= Configurability.gather_defaults

		self.log.info "Loading config from %p with defaults for sections: %p." %
			[ config_file, defaults.keys ]
		config = Configurability::Config.load( config_file, defaults )
		config.install
	end


	### Configurability API -- configure the daemon.
	def self::configure( config=nil )
		config = self.defaults.merge( config || {} )

		self.throttle_max     = config[:throttle_max]
		self.throttle_factor  = config[:throttle_factor]
		self.scaling_interval = config[:scaling_interval]
		self.tasks            = config[:tasks]
	end

end # module Symphony

