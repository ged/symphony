#!/usr/bin/env ruby

require 'laika' unless defined?( LAIKA )
require 'laika/exceptions'

# GroundControl -- a task scheduler and job queue for LAIKA IT systems
module LAIKA::GroundControl

	# Library version constant
	VERSION = '0.0.1'

	# Version-control revision constant
	REVISION = %q$Revision$

	# Load dependent features
	LAIKA.require_features( :db, :ldap )

	LAIKA::DB.register_model 'laika/groundcontrol/job'
	require 'laika/groundcontrol/queue'
	require 'laika/groundcontrol/task'


	# An exception class raised when there is a problem with locking in a GroundControl::Job.
	class LockingError < LAIKA::Exception; end

	# An exception class send to task children when they need to abort their task.
	class AbortTask < LAIKA::Exception; end


	### Return a default GroundControl job queue.
	def self::default_queue
		return LAIKA::GroundControl::Queue.default
	end


	# Register this feature as being present.
	LAIKA.register_feature( :groundcontrol )

end # module LAIKA::GroundControl

