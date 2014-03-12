#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'groundcontrol/task'

describe GroundControl::Task do

	before( :all ) do
		GroundControl::Queue.configure
	end

	before( :each ) do
		GroundControl::Queue.reset
	end


	it "closes the AMQP session when it receives a TERM signal" do
		amqp_session = double( "amqp session" )
		allow( Bunny ).to receive( :new ).and_return( amqp_session )

		task = described_class.new( described_class.queue )

		expect( amqp_session ).to receive( :close )
		task.handle_signal( :TERM )
	end


	context "a concrete subclass" do

		before( :each ) do
			@task_class = Class.new( described_class ) do
				def self::name; 'ACME::TestingTask'; end
			end
		end


		it "provides a default name for its queue based on its name" do
			expect( @task_class.queue_name ).to eq( 'acme.testingtask' )
		end


		it "can declare a pattern to use when subscribing" do
			@task_class.subscribe_to( 'foo.test' )
			expect( @task_class.routing_keys ).to include( 'foo.test' )
		end


		it "has acknowledgements enabled by default" do
			expect( @task_class.acknowledge ).to eq( true )
		end


		it "can enable acknowledgements" do
			@task_class.acknowledge( true )
			expect( @task_class.acknowledge ).to eq( true )
		end


		it "can disable acknowledgements" do
			@task_class.acknowledge( false )
			expect( @task_class.acknowledge ).to eq( false )
		end


		it "can set a timeout" do
			@task_class.timeout( 10 )
			expect( @task_class.timeout ).to eq( 10 )
		end


		it "can declare a one-shot work model" do
			@task_class.work_model( :oneshot )
			expect( @task_class.work_model ).to eq( :oneshot )
		end


		it "can declare a long-lived work model" do
			@task_class.work_model( :longlived )
			expect( @task_class.work_model ).to eq( :longlived )
		end


		it "raises an error if a work model is declared " do
			@task_class.work_model( :longlived )
			expect( @task_class.work_model ).to eq( :longlived )
		end

	end

end

