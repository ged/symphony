#!/usr/bin/env ruby
#encoding: utf-8

$LOAD_PATH.unshift( 'lib' )

require 'yajl'
require 'groundcontrol'
require 'sys/proctable'

Loggability.level = :debug
Loggability.format_with( :color )

GroundControl.load_config( 'etc/config.yml' )

# Get the configured exchange
exchange = GroundControl::Queue.amqp_exchange

loop do
	processes = Sys::ProcTable.ps.map( &:to_h )
	exchange.publish( Yajl.dump(processes), routing_key: 'sys.proctable',
		content_type: 'application/json' )

	sleep 2
end

