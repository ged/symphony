#!/usr/bin/ruby
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).expand_path.dirname.parent.parent
	parentdir = basedir.parent
	laikabasedir = parentdir + 'laika-base'

	libdir = basedir + "lib"
	baselibdir = laikabasedir + 'lib'

	$stderr.puts "Including #{libdir}, #{laikabasedir}, and #{baselibdir} in $LOAD_PATH" if $DEBUG
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
	$LOAD_PATH.unshift( laikabasedir.to_s ) unless $LOAD_PATH.include?( laikabasedir.to_s )
	$LOAD_PATH.unshift( baselibdir.to_s ) unless $LOAD_PATH.include?( baselibdir.to_s )
}

# SimpleCov test coverage reporting; enable this using the :coverage rake task
if ENV['COVERAGE']
	require 'simplecov'
	SimpleCov.start do
		add_filter 'spec'
		add_group "Needing tests" do |file|
			file.covered_percent < 90
		end
	end
end


require 'rspec'

require 'laika'

require 'spec/lib/basehelpers'
require 'spec/lib/baseconstants'
require 'spec/lib/groundcontrolconstants'


### RSpec helper functions for laika-ldap classes.
module LAIKA::GroundControlSpecHelpers

	# Any groundcontrol-specific setup methods go here

end

RSpec.configure do |config|
	include LAIKA::GroundControlTestConstants

	config.mock_with( :rspec )

	config.include( LAIKA::BaseSpecHelpers )
	config.include( LAIKA::GroundControlSpecHelpers )
	config.include( LAIKA::GroundControlTestConstants )

end

# vim: set nosta noet ts=4 sw=4:

