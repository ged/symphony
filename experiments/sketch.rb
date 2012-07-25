#!/usr/bin/env ruby

require 'laika'

# A little sketch of how GroundControl's API should work.

LAIKA.require_features( :groundcontrol, :inventory )

queue = LAIKA::GroundControl.default_queue
every( 24.hours ) do
	LAIKA::Netgroup[:workstations].hosts.each do |host|

		queue.add( LAIKA::Inventory::GathererJob, :macosx, host.fqdn )
	end
end



