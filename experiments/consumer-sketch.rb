#!/usr/bin/env ruby

require 'loggability'
require 'laika'
require 'net/ping/tcp'

$stderr.sync = false

# A little sketch of how GroundControl's API should work.

LAIKA.require_features( :groundcontrol )
LAIKA.load_config( '../../etc/config.yml' )

if $VERBOSE
	Loggability.level = :debug
	Loggability.format_with( :color )
end

queue = LAIKA::GroundControl.default_queue
pinger = Net::Ping::TCP.new( nil, 22 )

running = true

Signal.trap( :TERM ) { running = false }
Signal.trap( :INT ) { running = false }

while (job = queue.next) && running

	task_type = job.task_name
	task = task_type.new( job.arguments )
	task.run( queue, job )

end

