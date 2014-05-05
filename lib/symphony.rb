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
	VERSION = '0.7.0'

	# Version-control revision constant
	REVISION = %q$Revision$


	# The name of the environment variable to check for config file overrides
	CONFIG_ENV = 'SYMPHONY_CONFIG'

	# The path to the default config file
	DEFAULT_CONFIG_FILE = 'etc/config.yml'


	# Loggability API -- set up symphony's logger
	log_as :symphony


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


	require 'symphony/mixins'
	require 'symphony/queue'
	require 'symphony/task'

end # module Symphony

