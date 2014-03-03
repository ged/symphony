#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'groundcontrol/task'

describe GroundControl::Task do

	before( :all ) do
		GroundControl::Queue.configure
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

	end

end

