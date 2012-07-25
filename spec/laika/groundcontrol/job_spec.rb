#!/usr/bin/env rspec

BEGIN {
	require 'pathname'
	invdir = Pathname( __FILE__ ).dirname.parent.parent.parent
	basedir = invdir.parent

	libdir = invdir + 'lib'
	dbdir = basedir + 'laika-db'

	$LOAD_PATH.unshift( invdir.to_s ) unless $LOAD_PATH.include?( invdir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
	$LOAD_PATH.unshift( dbdir.to_s ) unless $LOAD_PATH.include?( dbdir.to_s )
}

require 'rspec'

require 'spec/lib/groundcontrolhelpers'
require 'spec/lib/groundcontrolconstants'
require 'spec/lib/dbhelpers'

require 'laika'
require 'laika/groundcontrol'
require 'laika/featurebehavior'


describe 'LAIKA::GroundControl::Job' do
	
	before( :all ) do
		setup_logging( :fatal )
		setup_test_database()
		LAIKA::GroundControl::Job.create_schema!( :groundcontrol ) # Workaround for Sequel bug
		LAIKA::GroundControl::Job.create_table!
	end

	after( :all ) do
		LAIKA::GroundControl::Job.drop_table
		LAIKA::GroundControl::Job.drop_schema( :groundcontrol )
		cleanup_test_database()
	end

	it "requires a method name" do
		job = LAIKA::GroundControl::Job.new
		job.should_not be_valid()
		job.errors.should have( 1 ).member
		job.errors[:method_name].should include {|thing| thing =~ /present/i }
	end

	it "is valid if it has a method name" do
		job = LAIKA::GroundControl::Job.new( :method_name => 'flying_monkies' )
		job.should be_valid()
		job.errors.should be_empty
	end

	it "stringifies correctly" do
		job = LAIKA::GroundControl::Job.create( :method_name => 'flying_monkies' )
		job.to_s.should =~ /flying_monkies \[default\] @#{job.created_at}/i
	end

	it "stringifies correctly after being locked" do
		job = LAIKA::GroundControl::Job.create( :method_name => 'flying_monkies' )
		job.locked_at = Time.now
		job.to_s.should =~ /flying_monkies \[default\] @#{job.created_at} \(in progress\)/i
	end

end

