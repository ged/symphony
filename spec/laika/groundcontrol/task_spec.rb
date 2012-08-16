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


describe LAIKA::GroundControl::Task do

	before( :all ) do
		setup_logging( :fatal )
		setup_test_database()
	end

	after( :each ) do
		LAIKA::GroundControl::Job.truncate
	end

	after( :all ) do
		cleanup_test_database()
	end


	it "is an abstract class" do
		expect { described_class.new }.to raise_error( NoMethodError, /private method/i )
	end


	it "provides a default error handler that re-queues the job if it aborts" do
		subclass = Class.new( described_class )
		queue = mock( "gc queue" )
		job = double( "gc job", task_options: {} )

		queue.should_receive( :re_add ).with( job )

		exception = LAIKA::GroundControl::AbortTask.new( "Testing." )
		subclass.new( queue, job ).on_error( exception )
	end


	context "a subclass" do

		before( :each ) do
			@subclass = Class.new( described_class ) do
				def self::name; "DoSomeStuff"; end
			end
			@queue = double( "gc queue" )
			@job = double( "gc job", task_options: {} )
		end

		it "needs to override run" do
			expect {
				@subclass.new( @queue, @job ).run
			}.to raise_error( NotImplementedError, /#run/i )
		end


		it "stringifies with a human-readable description" do
			@subclass.new( @queue, @job ).to_s.should == "Do Some Stuff"
		end


		it "provides an extension point for subclasses to override their descriptions" do
			@subclass.class_eval do
				def description; "ping host 'breznev'"; end
			end

			@subclass.new( @queue, @job ).to_s.should == "Do Some Stuff: ping host 'breznev'"
		end

	end

end

