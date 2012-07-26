#!/usr/bin/env ruby

require 'laika'

# A little sketch of how GroundControl's API should work.

LAIKA.require_features( :groundcontrol )
LAIKA.load_config( '../../etc/config.yml' )

queue = LAIKA::GroundControl.default_queue

while job = queue.next
	puts "Gathering stuff from #{job.arguments}"
	system 'ping', '-c1', job.arguments
end

