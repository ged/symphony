#!/usr/bin/ruby -*- ruby -*-

require 'laika'
require 'loggability'
require 'pathname'

$LOAD_PATH.unshift( 'lib' )

begin
	require 'laika'

	Loggability.level = :debug
	Loggability.format_with( :color )

	LAIKA.load_config( '../etc/config.yml' )

	$stderr.puts "Loading laika-groundcontrol..."
	LAIKA.require_features( :db, :groundcontrol )

rescue Exception => e
	$stderr.puts "Ack! laika-groundcontrol libraries failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end


