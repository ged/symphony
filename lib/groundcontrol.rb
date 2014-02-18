#!/usr/bin/env ruby

require 'loggability'
require 'configurability'

# GroundControl -- an evented asynchronous thingie.
#
# See the README for additional guidance.
#
module GroundControl
	extend Loggability,
	       Configurability

	# Library version constant
	VERSION = '0.3.0'

	# Version-control revision constant
	REVISION = %q$Revision$


	# The name of the environment variable to check for config file overrides
	CONFIG_ENV = 'GROUNDCONTROL_CONFIG'

	# The path to the default config file
	DEFAULT_CONFIG_FILE = 'etc/config.yml'


	# Loggability API -- set up groundcontrol's logger
	log_as :groundcontrol


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


	require 'groundcontrol/mixins'
	require 'groundcontrol/queue'
	require 'groundcontrol/task'

end # module GroundControl

