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


	### Enqueue the specified +job+ in the given +queue+.
	def self::enqueue( queuename, job, *args )
		queue = LAIKA::GroundControl::Queue[ queuename ] or
			raise ArgumentError, "No such queue #{queuename}"
		queue.add( job )
	end


	# Register this feature as being present.
	LAIKA.register_feature( :groundcontrol )

end # module LAIKA::GroundControl

