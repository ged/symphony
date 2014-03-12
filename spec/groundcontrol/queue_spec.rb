#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'groundcontrol/queue'

describe GroundControl::Queue do


	before( :all ) do
		described_class.configure( broker_uri: 'amqp://example.com/%2Ftesty' )
	end

	before( :each ) do
		described_class.reset
	end


	it_should_behave_like "an object with Configurability"


	it "can build a Hash of AMQP options from its configuration" do
		expect( described_class.amqp_session_options ).to include({
			heartbeat: :server,
			logger:    Loggability[ GroundControl ],
		})
	end


	context "bunny interaction" do


		it "can build a new Bunny session using the loaded configuration" do
			clowney = double( "Bunny session" )
			expect( Bunny::Session ).to receive( :new ).
				with( described_class.broker_uri, described_class.amqp_session_options ).
				and_return( clowney )

			expect( described_class.amqp_session ).to be( clowney )
		end

		it "doesn't recreate the bunny session across multiple calls" do
			bunny = double( "Bunny session" )
			expect( Bunny::Session ).to receive( :new ).
				once.
				with( described_class.broker_uri, described_class.amqp_session_options ).
				and_return( bunny )

			expect( described_class.amqp_session ).to be( bunny )
			expect( described_class.amqp_session ).to be( bunny )
		end

		it "can open a channel on the Bunny session" do
			bunny = double( "Bunny session" )
			channel = double( "Bunny channel" )
			expect( Bunny ).to receive( :new ).
				with( described_class.broker_uri, described_class.amqp_session_options ).
				and_return( bunny )
			expect( bunny ).to receive( :start )
			expect( bunny ).to receive( :create_channel ).and_return( channel )

			expect( described_class.amqp_channel ).to be( channel )
		end

		it "can fetch the configured exchange" do
			bunny = double( "Bunny session" )
			channel = double( "Bunny channel" )
			exchange = double( "GroundControl exchange" )
			expect( Bunny ).to receive( :new ).
				with( described_class.broker_uri, described_class.amqp_session_options ).
				and_return( bunny )
			expect( bunny ).to receive( :start )
			expect( bunny ).to receive( :create_channel ).and_return( channel )
			expect( channel ).to receive( :topic ).with( described_class.exchange, passive: true ).
				and_return( exchange )

			expect( described_class.amqp_exchange ).to be( exchange )
		end
	end


	context "instance" do

		before( :each ) do
			@testing_task_class = Class.new( GroundControl::Task )
			@bunny = double( "Bunny session" )
			@channel = double( "Bunny channel" )
			@exchange = double( "GroundControl exchange" )

			allow( Bunny ).to receive( :new ).
				with( described_class.broker_uri, described_class.amqp_session_options ).
				and_return( @bunny )
			allow( @bunny ).to receive( :start )
			allow( @bunny ).to receive( :create_channel ).and_return( @channel )
			allow( @channel ).to receive( :topic ).
				with( described_class.exchange, passive: true ).
				and_return( @exchange )
		end

		it "creates an auto-deleted queue for the task if one doesn't already exist" do
			@testing_task_class.subscribe_to 'tests.unit'
			queue = described_class.new( @testing_task_class )

			amqp_queue = double( "amqp queue" )
			allow( @exchange ).to receive( :name ).and_return( "exchange" )

			expected_exception = Bunny::NotFound.new( "oopsie! no queue!", @channel, :frame )
			expect( @channel ).to receive( :queue ).
				with( @testing_task_class.queue_name, passive: true ).
				and_raise( expected_exception )
			expect( @channel ).to receive( :open? ).and_return( false )
			expect( @channel ).to receive( :queue ).
				with( @testing_task_class.queue_name, auto_delete: true ).
				and_return( amqp_queue )
			expect( amqp_queue ).to receive( :bind ).
				with( @exchange, routing_key: 'tests.unit' )

			expect( queue.create_queue ).to be( amqp_queue )
		end

		it "re-uses the existing queue on the broker if it already exists" do
			@testing_task_class.subscribe_to 'tests.unit'
			queue = described_class.new( @testing_task_class )

			amqp_queue = double( "amqp queue" )
			allow( @exchange ).to receive( :name ).and_return( "exchange" )

			expect( @channel ).to receive( :queue ).
				with( @testing_task_class.queue_name, passive: true ).
				and_return( amqp_queue )

			expect( queue.create_queue ).to be( amqp_queue )
		end


		it "subscribes with ACKs enabled if the task it belongs to has acknowledgements set" do
			@testing_task_class.acknowledge( true )
			@testing_task_class.subscribe_to 'tests.unit'
			queue = described_class.new( @testing_task_class )

			amqp_queue = double( "amqp queue" )
			allow( @exchange ).to receive( :name ).and_return( "exchange" )

			expect( @channel ).to receive( :queue ).
				with( @testing_task_class.queue_name, passive: true ).
				and_return( amqp_queue )
			expect( amqp_queue ).to receive( :subscribe ).
				with( ack: true, block: true, consumer_tag: @testing_task_class.consumer_tag )

			queue.each_message { }
		end


		it "subscribes with ACKs disabled if the task it belongs to has acknowledgements unset" do
			@testing_task_class.acknowledge( false )
			@testing_task_class.subscribe_to 'tests.unit'
			queue = described_class.new( @testing_task_class )

			amqp_queue = double( "amqp queue" )
			allow( @exchange ).to receive( :name ).and_return( "exchange" )

			expect( @channel ).to receive( :queue ).
				with( @testing_task_class.queue_name, passive: true ).
				and_return( amqp_queue )
			expect( amqp_queue ).to receive( :subscribe ).
				with( ack: false, block: true, consumer_tag: @testing_task_class.consumer_tag )

			queue.each_message { }
		end


		it "yields the payload and metadata to the block passed to #each_message" do
			@testing_task_class.subscribe_to 'tests.unit'
			queue = described_class.new( @testing_task_class )
			delivery_info = double( "delivery info", delivery_tag: 128 )

			amqp_queue = double( "amqp queue" )
			allow( @exchange ).to receive( :name ).and_return( "exchange" )

			expect( @channel ).to receive( :queue ).
				with( @testing_task_class.queue_name, passive: true ).
				and_return( amqp_queue )
			expect( amqp_queue ).to receive( :subscribe ).
				and_yield( delivery_info, {content_type: 'text/plain'}, :payload )
			expect( @channel ).to receive( :acknowledge ).with( delivery_info.delivery_tag )

			queue.each_message do |payload, metadata|
				expect( payload ).to eq( :payload )
				expect( metadata ).to eq({
					content_type: 'text/plain',
					properties: {content_type: 'text/plain'},
					delivery_info: delivery_info
				})
			end
		end


		it "sets the consumer key to something useful when it subscribes"

	end

end

