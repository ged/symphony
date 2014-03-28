#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'symphony/task'

describe Symphony::Task do

	before( :all ) do
		Symphony::Queue.configure
	end

	before( :each ) do
		Symphony::Queue.reset
		allow( Bunny ).to receive( :new ).and_return( amqp_session )
	end

	after( :each ) do
		# reset signal handlers
		Symphony::Task::SIGNALS.each do |sig|
			Signal.trap( sig, :DFL )
		end
	end


	let( :amqp_session ) { double('amqp_session') }
	let( :channel ) { double('amqp channel') }
	let( :consumer ) { double('bunny consumer', channel: channel) }


	it "cancels the AMQP consumer when it receives a TERM signal" do
		queue = described_class.queue
		queue.consumer = consumer
		task = described_class.new( queue )

		expect( queue.consumer ).to receive( :cancel )

		task.handle_signal( :TERM )
	end


	it "cancels the AMQP consumer when it receives an INT signal" do
		queue = described_class.queue
		queue.consumer = consumer
		task = described_class.new( queue )

		expect( queue.consumer ).to receive( :cancel )

		task.handle_signal( :INT )
	end


	it "closes the AMQP session when it receives a second TERM signal" do
		queue = described_class.queue
		queue.consumer = consumer
		task = described_class.new( queue )
		task.shutting_down = true

		expect( queue.consumer.channel ).to receive( :close )

		task.handle_signal( :TERM )
	end


	context "a concrete subclass" do

		before( :each ) do
			@task_class = Class.new( described_class ) do
				def self::name; 'ACME::TestingTask'; end
			end
		end


		it "raises an exception if run without specifying any subscriptions" do
			expect { @task_class.run }.to raise_error( ScriptError, /no subscriptions/i )
		end


		it "can set an explicit queue name" do
			@task_class.queue_name( 'happy.fun.queue' )
			expect( @task_class.queue_name ).to eq( 'happy.fun.queue' )
		end


		it "can retry on timeout instead of rejecting" do
			@task_class.timeout_action( :retry )
			expect( @task_class.timeout_action ).to eq( :retry )
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


		it "raises an error if an invalid work model is declared " do
			expect {
				@task_class.work_model( :lazy )
			}.to raise_error( /unknown work_model/i )
		end


	end

end

