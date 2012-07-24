#!/usr/bin/ruby -*- ruby -*-

require 'pathname'

basedir = Pathname.new( __FILE__ ).expand_path.dirname
parentdir = basedir.parent
laikabasedir = parentdir + 'laika-base'

libdir = basedir + "lib"
baselibdir = laikabasedir + 'lib'

$stderr.puts "Including #{libdir} and #{baselibdir} in $LOAD_PATH" if $DEBUG
$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
$LOAD_PATH.unshift( baselibdir.to_s ) unless $LOAD_PATH.include?( baselibdir.to_s )

begin
	require 'laika'

	$stderr.puts "Loading laika-groundcontrol..."
	LAIKA.require_features :groundcontrol

	require 'configurability'
	require 'configurability/config'
	require 'logger'

	LAIKA.logger.level = $DEBUG ? Logger::DEBUG : Logger::INFO
	LAIKA.logger.formatter = LAIKA::ColorLogFormatter.new( LAIKA.logger )
	Configurability.logger = LAIKA.logger

	etcdir = parentdir + 'etc'
	configfile = etcdir + 'config.yml'
	config = Configurability::Config.load( configfile )
	config.install
rescue => e
	$stderr.puts "Ack! laika-groundcontrol libraries failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end

