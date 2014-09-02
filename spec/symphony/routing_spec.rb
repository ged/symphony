#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'symphony'
require 'symphony/routing'


describe Symphony::Routing do

	let( :task_class ) do
		Class.new( Symphony::Task ) do
			include Symphony::Routing
			def self::name; 'ACME::TestingTask'; end
		end
	end


	it "allows registration of message handlers by event name" do
		called = false
		delivery_info = double( "AMQP delivery_info", routing_key: 'test.event.received' )

		task_class.on 'test.event.received' do |payload, metadata|
			called = true
		end

		expect( task_class.routing_keys ).to include( 'test.event.received' )

		instance = task_class.new( :queue )
		expect( instance.work([], delivery_info: delivery_info) ).to be_truthy
		expect( called ).to be_truthy
	end


	it "allows the same message handler for multiple events" do
		called_count = 0
		di1 = double( "AMQP delivery_info", routing_key: 'test.event.received' )
		di2 = double( "AMQP delivery_info", routing_key: 'another.event.received' )

		task_class.on 'test.event.received', 'another.event.received' do |payload, metadata|
			called_count += 1
		end

		expect(
			task_class.routing_keys
		).to include( 'test.event.received', 'another.event.received' )

		instance = task_class.new( :queue )
		expect( instance.work([], delivery_info: di1) ).to be_truthy
		expect( instance.work([], delivery_info: di2) ).to be_truthy

		expect( called_count ).to eq( 2 )
	end


	it "allows a Hash of options to be included with an event handler" do
		task_class.on 'test.event.with_options', scheduled: '2 times an hour' do |payload, metadata|
		end

		expect( task_class.routing_keys ).to include( 'test.event.with_options' )
		expect(
			task_class.route_options['test.event.with_options']
		).to include( scheduled: '2 times an hour' )
	end

end

