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
		@real_taskclasses = LAIKA::GroundControl::Task.derivatives.dup

		setup_test_database()
	end

	before( :each ) do
		LAIKA::GroundControl::Job.truncate
		LAIKA::GroundControl::Task.derivatives.clear
	end

	after( :all ) do
		cleanup_test_database()
		LAIKA::GroundControl::Task.derivatives.replace( @real_taskclasses )
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

	it "can fetch an instance of the task it's supposed to run" do
		taskclass = nil
		job = LAIKA::GroundControl::Job.create( :task_name => 'assetcataloger' )
		LAIKA::GroundControl::Task.should_receive( :require ).
			with( 'laika/groundcontrol/tasks/assetcataloger_task' ).
			and_return {
				taskclass = Class.new( LAIKA::GroundControl::Task ) {
					def self::name; "AssetCataloger"; end
				}
				LAIKA::GroundControl::Task.derivatives[ 'assetcataloger' ] = taskclass
			}

		klass = job.task_class
		klass.should be( taskclass )

	end

end

