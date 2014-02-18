#!/usr/bin/ruby -*- ruby -*-

require 'loggability'
require 'pathname'

$LOAD_PATH.unshift( 'lib' )

begin
	require 'groundcontrol'

	Loggability.level = :debug
	Loggability.format_with( :color )

	GroundControl.load_config( 'etc/config.yml' )

rescue Exception => e
	$stderr.puts "Ack! groundcontrol libraries failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end


