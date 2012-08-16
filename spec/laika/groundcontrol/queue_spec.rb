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


	it "is able to add a job to the default queue" do
		q = described_class.new
		q.add( 'poke the skunk' )
		q.jobs.should have( 1 ).member
		q.jobs.first.should be_frozen()
	end

	it "ensures that its name is a valid SQL identifier" do
		expect {
			described_class.new( "something that's not an identifier" )
		}.to raise_error( ArgumentError, /invalid identifier/i )
	end

	it "is able to add a job object to the default queue" do
		q = described_class.new
		job = LAIKA::GroundControl::Job.new( :task_name => 'poke the porcupine' )
		q.add( job )
		q.jobs.should have( 1 ).member
		q.jobs.first.should be_frozen()
	end


	it "is able to add a job to a named queue" do
		q = described_class.new( 'john_denver' )
		job = LAIKA::GroundControl::Job.new( :task_name => 'more cowbell' )
		q.add( job )
		q.jobs.should have( 1 ).member
		q.jobs.first.should be_frozen()
		q.jobs.first.queue_name.should == q.name
	end


	it "can lock and fetch a job for execution" do
		q = described_class.new( 'denver_omelette' )
		q.add( "clean homesar's room" )
		job = q.next
		job.locked_at.should_not be_nil()
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
		job.task_name.should == 'are you sleeping?'
		job.locked_at.should_not be_nil()
	end

	it "can return a list of jobs belonging to itself" do
		q = described_class.new

		q.jobs.should be_empty()

		q.add( 'test_monkey' )

		q.jobs.should have( 1 ).member
		q.jobs.first.should be_frozen()
	end


	it "can re-add a job" do
		q = described_class.new
		q.add( 'test_monkey', hammer: false, spacecraft: true )

		job = q.next

		newjob = q.re_add( job )

		newjob.should_not be( job )
		newjob.id.should_not == job.id
		newjob.locked_at.should be_nil()
		newjob.task_name.should == job.task_name
		newjob.task_options.should == job.task_options
	end

end

