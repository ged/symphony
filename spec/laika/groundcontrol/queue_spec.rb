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
require 'laika/groundcontrol/queue'
require 'laika/featurebehavior'


describe LAIKA::GroundControl::Queue do

	before( :all ) do
		setup_logging( :fatal )
		setup_test_database()
		LAIKA::GroundControl::Job.create_schema!( :groundcontrol ) # Workaround for Sequel bug
		LAIKA::GroundControl::Job.create_table!
	end

	after( :each ) do
		LAIKA::GroundControl::Job.truncate
	end

	after( :all ) do
		LAIKA::GroundControl::Job.drop_table
		LAIKA::GroundControl::Job.drop_schema( :groundcontrol )
		cleanup_test_database()
	end


	it "is able to add a job to the default queue" do
		q = described_class.new
		q.add( 'poke the skunk' )
		q.jobs.should have( 1 ).member
		q.jobs.first.should be_frozen()
	end

	it "ensures that its name is a valid SQL identifier" do
		expect {
			described_class.new( "I'm not an identifier you moron." )
		}.should raise_error( ArgumentError, /invalid identifier/i )
	end

	it "is able to add a job object to the default queue" do
		q = described_class.new
		job = LAIKA::GroundControl::Job.new( :method_name => 'poke the porcupine' )
		q.add( job )
		q.jobs.should have( 1 ).member
		q.jobs.first.should be_frozen()
	end


	it "is able to add a job to a named queue" do
		q = described_class.new( 'john_denver' )
		job = LAIKA::GroundControl::Job.new( :method_name => 'more cowbell' )
		q.add( job )
		q.jobs.should have( 1 ).member
		q.jobs.first.should be_frozen()
		q.jobs.first.queue_name.should == q.name
	end


	it "can lock and fetch a job for execution" do
		q = described_class.new( 'denver_omelette' )
		q.add( "clean homesar's room" )
		job = q.next
		job.locked_at.should_not be_nil
	end

	it "blocks until it can fetch a job for execution" do
		q = described_class.new( 'denver_airport_aliens' )

		# Start a thread to collect the job
		thr = Thread.new do
			q.next
		end

		# Wait here until the thread is blocked, waiting on the next job.
		Thread.pass until thr.stop?

		q.add( 'are you sleeping?' )

		job = thr.value
		job.method_name.should == 'are you sleeping?'
		job.locked_at.should_not be_nil
	end

	it "can return a list of jobs belonging to itself" do
		q = described_class.new

		q.jobs.should be_empty()

		q.add( 'test_monkey' )

		q.jobs.should have( 1 ).member
		q.jobs.first.should be_frozen()
	end

end

