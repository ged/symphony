#!/usr/bin/env ruby

require 'laika' unless defined?( LAIKA )

# GroundControl -- a task scheduler and job queue for LAIKA IT systems
module LAIKA::GroundControl

	# Library version constant
	VERSION = '0.0.1'

	# Version-control revision constant
	REVISION = %q$Revision$

	# Load dependent features
	LAIKA.require_features( :db )

	LAIKA::DB.register_model 'laika/groundcontrol/job'
	require 'laika/groundcontrol/queue'


	### Return a default GroundControl job queue.
	def self::default_queue
		return LAIKA::GroundControl::Queue.new
	end


	# Register this feature as being present.
	LAIKA.register_feature( :groundcontrol )

end # module LAIKA::GroundControl

