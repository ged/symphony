#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'groundcontrol/queue'

describe GroundControl::Queue do


	before( :each ) do
		described_class.configure( broker_uri: 'amqp://example.com/%2Ftesty' )
		described_class.reset
	end


	it_should_behave_like "an object with Configurability"


	it "can build a Hash of AMQP options from its configuration" do
		expect( described_class.amqp_session_options ).to include({
			heartbeat: :server,
			logger:    Loggability[ GroundControl ],
		})
	end


	it "can use the Bunny-style configuration Hash" do
		described_class.configure( host: 'spimethorpe.com', port: 23456 )
		expect( described_class.amqp_session_options ).to include({
			host: 'spimethorpe.com',
			port: 23456,
			heartbeat: :server,
			logger:    Loggability[ GroundControl ],
		})
	end


	it "assumes Bunny-style configuration Hash if no broker uri is configured" do
		described_class.configure( host: 'spimethorpe.com', port: 23456 )
		described_class.broker_uri = nil

		expect( Bunny ).to receive( :new ).
			with( described_class.amqp_session_options )

		described_class.amqp_session
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

		let( :queue ) { described_class.for_task(testing_task_class) }

		let( :testing_task_class ) { Class.new(GroundControl::Task) }
		let( :session ) { double("Bunny session", :start => true ) }

		before( :each ) do
			allow( Bunny ).to receive( :new ).and_return( session )
			described_class.amqp[:exchange] = double( "AMQP exchange" )
			described_class.amqp[:channel] = double( "AMQP channel" )
		end


		it "creates an auto-deleted queue for the task if one doesn't already exist" do
			expect( described_class.amqp_channel ).to receive( :queue ).
				with( queue.name, passive: true ).
				and_raise( Bunny::NotFound.new("no such queue", described_class.amqp_channel, true) )
			expect( described_class.amqp_channel ).to receive( :open? ).
				and_return( false )

			# Channel is reset after queue creation fails
			new_channel = double( "New AMQP channel" )
			amqp_queue = double( "AMQP queue" )
			allow( described_class.amqp_session ).to receive( :create_channel ).
				and_return( new_channel )
			expect( new_channel ).to receive( :prefetch ).
				with( GroundControl::Queue::DEFAULT_PREFETCH )
			expect( new_channel ).to receive( :queue ).
				with( queue.name, auto_delete: true ).
				and_return( amqp_queue )

			expect( queue.create_amqp_queue ).to be( amqp_queue )
		end


		it "re-uses the existing queue on the broker if it already exists" do
			amqp_queue = double( "AMQP queue" )
			expect( described_class.amqp_channel ).to receive( :queue ).
				with( queue.name, passive: true ).
				and_return( amqp_queue )
			expect( described_class.amqp_channel ).to receive( :prefetch ).
				with( GroundControl::Queue::DEFAULT_PREFETCH )

			expect( queue.create_amqp_queue ).to be( amqp_queue )
		end


		it "subscribes to the message queue with a configured consumer to wait for messages" do
			amqp_queue = double( "AMQP queue", channel: described_class.amqp_channel )
			consumer = double( "Bunny consumer" )

			expect( described_class.amqp_channel ).to receive( :queue ).
				with( testing_task_class.queue_name, passive: true ).
				and_return( amqp_queue )
			expect( described_class.amqp_channel ).to receive( :prefetch ).
				with( GroundControl::Queue::DEFAULT_PREFETCH )

			expect( Bunny::Consumer ).to receive( :new ).
				with( described_class.amqp_channel, amqp_queue, queue.consumer_tag, false ).
				and_return( consumer )

			expect( consumer ).to receive( :on_delivery )
			expect( consumer ).to receive( :on_cancellation )

			expect( amqp_queue ).to receive( :subscribe_with ).with( consumer, block: true )
			expect( described_class.amqp_channel ).to receive( :close )
			expect( session ).to receive( :close )

			queue.wait_for_message {}
		end


		it "raises if wait_for_message is called without a block"
		it "sets up the queue and consumer to only run once if waiting in one-shot mode"

		it "creates a consumer with acknowledgements enabled if it has acknowledgements enabled" do
			amqp_channel = double( "AMQP channel" )
			amqp_queue = double( "AMQP queue", channel: amqp_channel )
			consumer = double( "Bunny consumer" )

			# Ackmode argument is actually 'no_ack'
			expect( Bunny::Consumer ).to receive( :new ).
				with( amqp_channel, amqp_queue, queue.consumer_tag, false ).
				and_return( consumer )
			expect( consumer ).to receive( :on_delivery )
			expect( consumer ).to receive( :on_cancellation )

			expect( queue.create_consumer(amqp_queue) ).to be( consumer )
		end


		it "creates a consumer with acknowledgements disabled if it has acknowledgements disabled" do
			amqp_channel = double( "AMQP channel" )
			amqp_queue = double( "AMQP queue", channel: amqp_channel )
			consumer = double( "Bunny consumer" )

			# Ackmode argument is actually 'no_ack'
			queue.instance_variable_set( :@acknowledge, false )
			expect( Bunny::Consumer ).to receive( :new ).
				with( amqp_channel, amqp_queue, queue.consumer_tag, true ).
				and_return( consumer )
			expect( consumer ).to receive( :on_delivery )
			expect( consumer ).to receive( :on_cancellation )

			expect( queue.create_consumer(amqp_queue) ).to be( consumer )
		end


		it "it acknowledges the message if acknowledgements are set and the task returns a true value" do
			channel = double( "amqp channel" )
			queue.consumer = double( "bunny consumer", channel: channel )
			delivery_info = double( "delivery info", delivery_tag: 128 )

			expect( channel ).to receive( :acknowledge ).with( delivery_info.delivery_tag )

			queue.handle_message( delivery_info, {content_type: 'text/plain'}, :payload ) do |*|
				true
			end
		end


		it "it rejects the message if acknowledgements are set and the task returns a false value" do
			channel = double( "amqp channel" )
			queue.consumer = double( "bunny consumer", channel: channel )
			delivery_info = double( "delivery info", delivery_tag: 128 )

			expect( channel ).to receive( :reject ).with( delivery_info.delivery_tag, true )

			queue.handle_message( delivery_info, {content_type: 'text/plain'}, :payload ) do |*|
				false
			end
		end


		it "it permanently rejects the message if acknowledgements are set and the task raises" do
			channel = double( "amqp channel" )
			queue.consumer = double( "bunny consumer", channel: channel )
			delivery_info = double( "delivery info", delivery_tag: 128 )

			expect( channel ).to receive( :reject ).with( delivery_info.delivery_tag, false )

			queue.handle_message( delivery_info, {content_type: 'text/plain'}, :payload ) do |*|
				raise "Uh-oh!"
			end
		end


	end

end

