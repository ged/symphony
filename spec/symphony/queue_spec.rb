#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'symphony/queue'

RSpec.describe Symphony::Queue do


	before( :each ) do
		described_class.configure( broker_uri: 'amqp://example.com/%2Ftesty' )
		described_class.reset
	end


	it_should_behave_like "an object with Configurability"


	it "can build a Hash of AMQP options from its configuration" do
		expect( described_class.amqp_session_options ).to include({
			heartbeat: :server,
			logger:    Loggability[ Bunny ],
		})
	end


	it "can use the Bunny-style configuration Hash" do
		described_class.configure( host: 'spimethorpe.com', port: 23456 )
		expect( described_class.amqp_session_options ).to include({
			host: 'spimethorpe.com',
			port: 23456,
			heartbeat: :server,
			logger:    Loggability[ Bunny ],
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
			exchange = double( "Symphony exchange" )
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

		let( :testing_task_class ) { Class.new(Symphony::Task) }
		let( :session ) { double("Bunny session", :start => true ) }

		before( :each ) do
			allow( Bunny ).to receive( :new ).and_return( session )
			described_class.amqp[:exchange] = double( "AMQP exchange", name: 'the_exchange' )
			described_class.amqp[:channel] = double( "AMQP channel" )
		end


		it "creates an auto-deleted queue for the task if one doesn't already exist" do
			testing_task_class.subscribe_to( 'floppy.rabbit.#' )
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
				with( Symphony::Queue::DEFAULT_PREFETCH )
			expect( new_channel ).to receive( :queue ).
				with( queue.name, auto_delete: true ).
				and_return( amqp_queue )
			expect( amqp_queue ).to receive( :bind ).
				with( described_class.amqp_exchange, routing_key: 'floppy.rabbit.#' )

			expect( queue.create_amqp_queue ).to be( amqp_queue )
		end


		it "re-uses the existing queue on the broker if it already exists" do
			amqp_queue = double( "AMQP queue" )
			expect( described_class.amqp_channel ).to receive( :queue ).
				with( queue.name, passive: true ).
				and_return( amqp_queue )
			expect( described_class.amqp_channel ).to receive( :prefetch ).
				with( Symphony::Queue::DEFAULT_PREFETCH )

			expect( queue.create_amqp_queue ).to be( amqp_queue )
		end


		it "re-binds to an existing queue if the task specifies that it should always re-bind" do
			testing_task_class.subscribe_to( 'floppy.rabbit.#' )
			testing_task_class.always_rebind( true )
			amqp_queue = double( "AMQP queue" )

			expect( described_class.amqp_channel ).to receive( :queue ).
				with( queue.name, passive: true ).
				and_return( amqp_queue )
			expect( described_class.amqp_channel ).to receive( :prefetch ).
				with( Symphony::Queue::DEFAULT_PREFETCH )

			expect( amqp_queue ).to receive( :bind ).
				with( described_class.amqp_exchange, routing_key: 'floppy.rabbit.#' )

			expect( queue.create_amqp_queue ).to be( amqp_queue )
		end


		it "subscribes to the message queue with a configured consumer to wait for messages" do
			amqp_queue = double( "AMQP queue", name: 'a queue', channel: described_class.amqp_channel )
			consumer = double( "Bunny consumer", channel: described_class.amqp_channel )

			expect( described_class.amqp_channel ).to receive( :queue ).
				with( testing_task_class.queue_name, passive: true ).
				and_return( amqp_queue )
			expect( described_class.amqp_channel ).to receive( :prefetch ).
				with( Symphony::Queue::DEFAULT_PREFETCH )

			expect( Bunny::Consumer ).to receive( :new ).
				with( described_class.amqp_channel, amqp_queue, queue.consumer_tag, false, false,
				      Symphony::Queue::CONSUMER_ARGS ).
				and_return( consumer )

			# Set up an artificial method to call the delivery callback that we can later
			# call ourselves
			expect( consumer ).to receive( :on_delivery ) do |&block|
				allow( consumer ).to receive( :deliver ) do
					delivery_info = double("delivery info", delivery_tag: 'mirrors!!!!' )
					properties = {:content_type => 'application/json'}
					payload = '{"some": "stuff"}'
					block.call( delivery_info, properties, payload )
				end
			end
			expect( consumer ).to receive( :on_cancellation )

			# When the queue subscription happens, call the hook we set up above to simulate
			# the delivery of AMQP messages
			expect( amqp_queue ).to receive( :subscribe_with ) do |*args|
				expect( args.first ).to be( consumer )
				expect( args.last ).to eq({ block: true })
				5.times { consumer.deliver }
			end

			expect( described_class.amqp_channel ).to receive( :acknowledge ).
				with( 'mirrors!!!!' ).
				exactly( 5 ).times
			expect( described_class.amqp_channel ).to receive( :close )
			expect( session ).to receive( :closed? ).and_return( false ).exactly( 5 ).times
			expect( session ).to receive( :close )

			count = 0
			queue.wait_for_message { count += 1 }
			expect( count ).to eq( 5 )
		end


		it "raises if wait_for_message is called without a block" do
			expect { queue.wait_for_message }.to raise_error( LocalJumpError, /no work/i )
		end


		it "sets up the queue and consumer to only run once if waiting in one-shot mode" do
			amqp_queue = double( "AMQP queue", name: 'a queue', channel: described_class.amqp_channel )
			consumer = double( "Bunny consumer", channel: described_class.amqp_channel )

			expect( described_class.amqp_channel ).to receive( :queue ).
				with( testing_task_class.queue_name, passive: true ).
				and_return( amqp_queue )
			expect( described_class.amqp_channel ).to receive( :prefetch ).with( 1 )

			expect( Bunny::Consumer ).to receive( :new ).
				with( described_class.amqp_channel, amqp_queue, queue.consumer_tag, false, false,
				      Symphony::Queue::CONSUMER_ARGS ).
				and_return( consumer )

			expect( consumer ).to receive( :on_delivery ) do |&block|
				allow( consumer ).to receive( :deliver ) do
					delivery_info = double("delivery info", delivery_tag: 'mirrors!!!!' )
					properties = {:content_type => 'application/json'}
					payload = '{"some": "stuff"}'
					block.call( delivery_info, properties, payload )
				end
			end
			expect( consumer ).to receive( :on_cancellation )

			expect( amqp_queue ).to receive( :subscribe_with ) do |*args|
				expect( args.first ).to be( consumer )
				expect( args.last ).to eq({ block: true })
				consumer.deliver
			end
			expect( described_class.amqp_channel ).to receive( :acknowledge ).
				with( 'mirrors!!!!' ).once
			expect( described_class.amqp_channel ).to receive( :close )
			expect( session ).to receive( :closed? ).and_return( false ).once
			expect( session ).to receive( :close )
			expect( consumer ).to receive( :cancel )

			count = 0
			queue.wait_for_message( true ) { count += 1 }
			expect( count ).to eq( 1 )
		end


		it "shuts down the consumer if the queues it's consuming from is deleted on the server" do
			amqp_queue = double( "AMQP queue", name: 'a queue', channel: described_class.amqp_channel )
			consumer = double( "Bunny consumer", channel: described_class.amqp_channel )

			expect( described_class.amqp_channel ).to receive( :queue ).
				with( testing_task_class.queue_name, passive: true ).
				and_return( amqp_queue )
			expect( described_class.amqp_channel ).to receive( :prefetch ).
				with( Symphony::Queue::DEFAULT_PREFETCH )

			expect( Bunny::Consumer ).to receive( :new ).
				with( described_class.amqp_channel, amqp_queue, queue.consumer_tag, false, false,
				      Symphony::Queue::CONSUMER_ARGS ).
				and_return( consumer )

			expect( consumer ).to receive( :on_delivery )
			expect( consumer ).to receive( :on_cancellation ) do |&block|
				allow( consumer ).to receive( :server_cancel ) do
					block.call
				end
			end

			expect( amqp_queue ).to receive( :subscribe_with ) do |*|
				consumer.server_cancel
			end
			expect( described_class.amqp_channel ).to receive( :close )
			expect( session ).to receive( :close )
			expect( consumer ).to receive( :cancel )

			queue.wait_for_message {}
			expect( queue ).to be_shutting_down()
		end


		it "creates a consumer with acknowledgements enabled if it has acknowledgements enabled" do
			amqp_channel = double( "AMQP channel" )
			amqp_queue = double( "AMQP queue", name: 'a queue', channel: amqp_channel )
			consumer = double( "Bunny consumer" )

			# Ackmode argument is actually 'no_ack'
			expect( Bunny::Consumer ).to receive( :new ).
				with( amqp_channel, amqp_queue, queue.consumer_tag, false, false,
				      Symphony::Queue::CONSUMER_ARGS ).
				and_return( consumer )
			expect( consumer ).to receive( :on_delivery )
			expect( consumer ).to receive( :on_cancellation )

			expect( queue.create_consumer(amqp_queue) ).to be( consumer )
		end


		it "creates a consumer with acknowledgements disabled if it has acknowledgements disabled" do
			amqp_channel = double( "AMQP channel" )
			amqp_queue = double( "AMQP queue", name: 'a queue', channel: amqp_channel )
			consumer = double( "Bunny consumer" )

			# Ackmode argument is actually 'no_ack'
			queue.instance_variable_set( :@acknowledge, false )
			expect( Bunny::Consumer ).to receive( :new ).
				with( amqp_channel, amqp_queue, queue.consumer_tag, true, false,
				      Symphony::Queue::CONSUMER_ARGS ).
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


		it "re-raises AMQP errors raised while handling a message" do
			channel = double( "amqp channel" )
			queue.consumer = double( "bunny consumer", channel: channel )
			delivery_info = double( "delivery info", delivery_tag: 128 )

			expect( channel ).to_not receive( :acknowledge )

			expect {
				queue.handle_message( delivery_info, {content_type: 'text/plain'}, :payload ) do |*|
					raise Bunny::Exception, 'something bad!'
				end
			}.to raise_error( Bunny::Exception, 'something bad!' )
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

