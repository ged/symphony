#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift( 'lib' )

require 'yajl'
require 'symphony'
require 'sys/proctable'

Loggability.level = :debug
Loggability.format_with( :color )

Symphony.load_config( 'etc/config.yml' )

# Get the configured exchange
exchange = Symphony::Queue.amqp_exchange

loop do
	processes = Sys::ProcTable.ps.map( &:to_h )
	exchange.publish( Yajl.dump(processes), routing_key: 'sys.proctable',
		content_type: 'application/json' )

	sleep 2
end

