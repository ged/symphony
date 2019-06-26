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

		let( :task_class ) do
			Class.new( described_class ) do
				def self::name; 'ACME::TestingTask'; end
			end
		end
		let( :payload ) {{ "the" => "payload" }}
		let( :serialized_payload ) { Yajl.dump(payload) }
		let( :metadata ) {{ :content_type => 'application/json' }}
		let( :queue ) do
			obj = Symphony::Queue.for_task( task_class )
			# Don't really talk to AMQP for messages
			allow( obj ).to receive( :wait_for_message ) do |oneshot, &callback|
				callback.call( serialized_payload, metadata )
			end
			obj
		end


		it "puts the process into its own process group after a fork" do
			expect( Process ).to receive( :setpgrp ).with( no_args )
			task_class.after_fork
		end


		it "raises an exception if run without specifying any subscriptions" do
			expect { task_class.run }.to raise_error( ScriptError, /no subscriptions/i )
		end


		it "can set an explicit queue name" do
			task_class.queue_name( 'happy.fun.queue' )
			expect( task_class.queue_name ).to eq( 'happy.fun.queue' )
		end


		it "can set the number of messages to prefetch" do
			task_class.prefetch( 10 )
			expect( task_class.prefetch ).to eq( 10 )
		end


		it "can retry on timeout instead of rejecting" do
			task_class.timeout_action( :retry )
			expect( task_class.timeout_action ).to eq( :retry )
		end


		it "provides a default name for its queue based on its name" do
			expect( task_class.queue_name ).to eq( 'acme.testingtask' )
		end


		it "can declare a pattern to use when subscribing" do
			task_class.subscribe_to( 'foo.test' )
			expect( task_class.routing_keys ).to include( 'foo.test' )
		end


		it "has acknowledgements enabled by default" do
			expect( task_class.acknowledge ).to eq( true )
		end


		it "can enable acknowledgements" do
			task_class.acknowledge( true )
			expect( task_class.acknowledge ).to eq( true )
		end


		it "can disable acknowledgements" do
			task_class.acknowledge( false )
			expect( task_class.acknowledge ).to eq( false )
		end


		it "can set a timeout" do
			task_class.timeout( 10 )
			expect( task_class.timeout ).to eq( 10 )
		end


		it "can declare a one-shot work model" do
			task_class.work_model( :oneshot )
			expect( task_class.work_model ).to eq( :oneshot )
		end


		it "can declare a long-lived work model" do
			task_class.work_model( :longlived )
			expect( task_class.work_model ).to eq( :longlived )
		end


		it "raises an error if an invalid work model is declared " do
			expect {
				task_class.work_model( :lazy )
			}.to raise_error( /unknown work_model/i )
		end


		it "can specify that its queue should always rebind" do
			task_class.always_rebind( true )
			expect( task_class.always_rebind ).to be_truthy
		end


		context "an instance" do

			let( :task_class ) do
				Class.new( described_class ) do
					def self::name
						"TestTask"
					end
					def self::inspect
						"TestTask"
					end
					def initialize( * )
						super
						@received_messages = []
					end
					attr_reader :received_messages

					def work( payload, metadata )
						self.received_messages << [ payload, metadata ]
						true
					end
				end
			end

			let( :task ) { task_class.new(queue) }


			it "handles received messages by calling its work method" do
				expect( queue ).to receive( :wait_for_message ) do |oneshot, &callback|
					callback.call( serialized_payload, metadata )
				end

				task.start_handling_messages

				expect( task.received_messages ).to eq([ [payload, metadata] ])
			end


			it "sets its proctitle to a useful string" do
				expect( Process ).to receive( :setproctitle ).
					with( /ruby \d+\.\d+\.\d+: Symphony: TestTask \(longlived\) -> testtask/i )

				task.start
			end

		end


		context "an instance with a timeout" do

			let( :task_class ) do
				Class.new( described_class ) do
					timeout 0.2
					def initialize( * )
						super
						@received_messages = []
						@sleeptime = 0
					end
					attr_reader :received_messages
					attr_accessor :sleeptime

					def work( payload, metadata )
						self.received_messages << [ payload, metadata ]
						sleep( self.sleeptime )
						true
					end
				end
			end

			let( :task ) { task_class.new(queue) }


			it "returns true if the work completes before the timeout" do
				task.sleeptime = 0
				expect( task.start_handling_messages ).to be_truthy
			end


			it "raises a Timeout::Error if the work takes longer than the timeout" do
				task.sleeptime = task_class.timeout + 2
				expect {
					task.start_handling_messages
				}.to raise_error( Timeout::Error, /execution expired/ )
			end


			it "returns false if the work takes longer than the timeout and the timeout_action is set to :retry" do
				task_class.timeout_action( :retry )
				task.sleeptime = task_class.timeout + 2
				expect( task.start_handling_messages ).to be_falsey
			end

		end


		context "an instance with no #work method" do

			let( :task ) { task_class.new(queue) }

			it "raises an exception when told to do work" do
				expect {
					task.work( 'payload', {} )
				}.to raise_error( NotImplementedError, /#work/ )
			end

		end



	end



end

