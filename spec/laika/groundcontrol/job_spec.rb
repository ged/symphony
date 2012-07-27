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
		LAIKA::GroundControl::Job.create_schema( :groundcontrol ) unless
			LAIKA::GroundControl::Job.schema_exists?( :groundcontrol )
		LAIKA::GroundControl::Job.create_table unless LAIKA::GroundControl::Job.table_exists?
	end

	before( :each ) do
		LAIKA::GroundControl::Job.truncate
	end

	after( :all ) do
		LAIKA::GroundControl::Job.truncate
		cleanup_test_database()
	end



	it "requires a task name" do
		job = LAIKA::GroundControl::Job.new
		job.should_not be_valid()
		job.errors.should have( 1 ).member
		job.errors[:task_name].should include {|thing| thing =~ /present/i }
	end

	it "requires a valid SQL identifier as its queue name" do
		job = LAIKA::GroundControl::Job.new( task_name: 'pinger',
		                                     queue_name: 'punch drunk monkeys' )
		job.should_not be_valid()
		job.errors.should have( 1 ).member
		job.errors[:queue_name].should include {|thing| thing =~ /identifier/i }
	end

	it "is valid if it has a task name" do
		job = LAIKA::GroundControl::Job.new( :task_name => 'pinger' )
		job.should be_valid()
		job.errors.should be_empty
	end

	it "stringifies correctly" do
		job = LAIKA::GroundControl::Job.create( :task_name => 'pinger' )
		job.to_s.should =~ /Pinger \[#{job.queue_name}\] @#{job.created_at}/i
	end

	it "can be locked inside of a transaction" do
		job = LAIKA::GroundControl::Job.create( :task_name => 'assetcataloger' )
		LAIKA::GroundControl::Job.db.transaction do
			job.lock
		end

		job.locked_at.should_not be_nil()
	end

	it "raises an exception if it's locked outside of a transaction" do
		job = LAIKA::GroundControl::Job.create( :task_name => 'assetcataloger' )

		expect {
			job.lock
		}.to raise_error( LAIKA::GroundControl::LockingError, /must be locked in a transaction/i )
	end

	it "raises an exception if it is locked twice" do
		job = LAIKA::GroundControl::Job.create( :task_name => 'assetcataloger' )

		expect {
			LAIKA::GroundControl::Job.db.transaction do
				job.lock
				job.lock
			end
		}.to raise_error( LAIKA::GroundControl::LockingError, /already locked/i )
	end
	
	it "stringifies correctly after being locked" do
		job = LAIKA::GroundControl::Job.create( :task_name => 'assetcataloger' )
		LAIKA::GroundControl::Job.db.transaction do
			job.lock
		end

		job.to_s.should =~ /AssetCataloger \[#{job.queue_name}\] @#{job.created_at} \(in progress\)/i
	end

	

end

