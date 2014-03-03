#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'groundcontrol/queue'

describe GroundControl::Queue do


	before( :all ) do
		described_class.configure( broker_uri: 'amqp://example.com/%2Ftesty' )
	end


	it_should_behave_like "an object with Configurability"


	it "can build a Hash of AMQP options from its configuration" do
		expect( described_class.amqp_session_options ).to include({
			heartbeat: :server,
			logger:    Loggability[ GroundControl ],
		})
	end


	context "bunny interaction" do

		before( :each ) do
			described_class.reset
		end


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

			expected_exception = Bunny::NotFound.new( "oopsie! no queue!", @channel, :frame )
			expect( @channel ).to receive( :queue ).
				with( @testing_task_class.queue_name, passive: true ).
				and_raise( expected_exception )
			expect( @channel ).to receive( :queue ).
				with( @testing_task_class.queue_name, auto_delete: true ).
				and_return( queue )

			
		end


	end

end

