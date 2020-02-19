#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'ostruct'
require 'symphony'
require 'symphony/routing'


RSpec.describe Symphony::Routing do

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


	it "sets an including Task to always rebind so updates are applied to existing queues" do
		expect( task_class.always_rebind ).to be_truthy
	end


	describe "route-matching" do

		let( :task_class ) do
			Class.new( Symphony::Task ) do
				include Symphony::Routing
				def initialize( * )
					super
					@run_data = Hash.new {|h,k| h[k] = [] }
				end
				attr_reader :run_data
			end
		end


		### Call the task's #work method with the same stuff Bunny would for the
		### given eventname
		def publish( eventname )
			delivery_info = OpenStruct.new( routing_key: eventname )
			properties = OpenStruct.new( content_type: 'application/json' )

			metadata = {
				delivery_info: delivery_info,
				properties: properties,
				content_type: properties.content_type,
			}

			payload = '[]'
			return task.work( payload, metadata )
		end


		context "for one-segment explicit routing keys (`simple`)" do

			let( :task ) do
				task_class.on( 'simple' ) {|*args| self.run_data[:simple] << args }
				task_class.new( :queue )
			end


			it "runs the job for routing keys that exactly match" do
				expect {
					publish( 'simple' )
				}.to change { task.run_data[:simple].length }.by( 1 )
			end


			it "doesn't run the job for routing keys which don't exactly match" do
				expect {
					publish( 'notsimple' )
				}.to_not change { task.run_data[:simple].length }
			end


			it "doesn't run the job for routing keys which contain additional segments" do
				expect {
					publish( 'simple.additional1' )
				}.to_not change { task.run_data[:simple_splat].length }
			end

		end


		context "for routing keys with one segment wildcard (`simple.*`)" do

			let( :task ) do
				task_class.on( 'simple.*' ) {|*args| self.run_data[:simple_splat] << args }
				task_class.new( :queue )
			end


			it "runs the job for routing keys with the same first segment and one additional segment" do
				expect {
					publish( 'simple.additional1' )
				}.to change { task.run_data[:simple_splat].length }
			end


			it "doesn't run the job for routing keys with only the same first segment" do
				expect {
					publish( 'simple' )
				}.to_not change { task.run_data[:simple_splat].length }
			end


			it "doesn't run the job for routing keys with a different first segment" do
				expect {
					publish( 'notsimple.additional1' )
				}.to_not change { task.run_data[:simple_splat].length }
			end


			it "doesn't run the job for routing keys which contain two additional segments" do
				expect {
					publish( 'simple.additional1.additional2' )
				}.to_not change { task.run_data[:simple_splat].length }
			end


			it "doesn't run the job for routing keys with a matching second segment" do
				expect {
					publish( 'prepended.simple.additional1' )
				}.to_not change { task.run_data[:simple_splat].length }
			end

		end


		context "for routing keys with two consecutive segment wildcards (`simple.*.*`)" do

			let( :task ) do
				task_class.on( 'simple.*.*' ) {|*args| self.run_data[:simple_splat_splat] << args }
				task_class.new( :queue )
			end


			it "runs the job for routing keys which contain two additional segments" do
				expect {
					publish( 'simple.additional1.additional2' )
				}.to change { task.run_data[:simple_splat_splat].length }
			end


			it "doesn't run the job for routing keys with the same first segment and one additional segment" do
				expect {
					publish( 'simple.additional1' )
				}.to_not change { task.run_data[:simple_splat_splat].length }
			end


			it "doesn't run the job for routing keys with only the same first segment" do
				expect {
					publish( 'simple' )
				}.to_not change { task.run_data[:simple_splat_splat].length }
			end


			it "doesn't run the job for routing keys with a different first segment" do
				expect {
					publish( 'notsimple.additional1' )
				}.to_not change { task.run_data[:simple_splat_splat].length }
			end


			it "doesn't run the job for routing keys with a matching second segment" do
				expect {
					publish( 'prepended.simple.additional1' )
				}.to_not change { task.run_data[:simple_splat_splat].length }
			end

		end


		context "for routing keys with bracketing segment wildcards (`*.simple.*`)" do

			let( :task ) do
				task_class.on( '*.simple.*' ) {|*args| self.run_data[:splat_simple_splat] << args }
				task_class.new( :queue )
			end


			it "runs the job for routing keys with a matching second segment" do
				expect {
					publish( 'prepended.simple.additional1' )
				}.to change { task.run_data[:splat_simple_splat].length }
			end


			it "doesn't run the job for routing keys which contain two additional segments" do
				expect {
					publish( 'simple.additional1.additional2' )
				}.to_not change { task.run_data[:splat_simple_splat].length }
			end


			it "doesn't run the job for routing keys with the same first segment and one additional segment" do
				expect {
					publish( 'simple.additional1' )
				}.to_not change { task.run_data[:splat_simple_splat].length }
			end


			it "doesn't run the job for routing keys with only the same first segment" do
				expect {
					publish( 'simple' )
				}.to_not change { task.run_data[:splat_simple_splat].length }
			end


			it "doesn't run the job for routing keys with a different first segment" do
				expect {
					publish( 'notsimple.additional1' )
				}.to_not change { task.run_data[:splat_simple_splat].length }
			end

		end


		context "for routing keys with a multi-segment wildcard (`simple.#`)" do

			let( :task ) do
				task_class.on( 'simple.#' ) {|*args| self.run_data[:simple_hash] << args }
				task_class.new( :queue )
			end


			it "runs the job for routing keys with the same first segment and one additional segment" do
				expect {
					publish( 'simple.additional1' )
				}.to change { task.run_data[:simple_hash].length }
			end


			it "runs the job for routing keys which contain two additional segments" do
				expect {
					publish( 'simple.additional1.additional2' )
				}.to change { task.run_data[:simple_hash].length }
			end


			it "runs the job for routing keys with only the same first segment" do
				expect {
					publish( 'simple' )
				}.to change { task.run_data[:simple_hash].length }
			end


			it "doesn't run the job for routing keys with a different first segment" do
				expect {
					publish( 'notsimple.additional1' )
				}.to_not change { task.run_data[:simple_hash].length }
			end


			it "doesn't run the job for routing keys with a matching second segment" do
				expect {
					publish( 'prepended.simple.additional1' )
				}.to_not change { task.run_data[:simple_hash].length }
			end

		end


		context "for routing keys with bracketing multi-segment wildcards (`#.simple.#`)" do

			let( :task ) do
				task_class.on( '#.simple.#' ) {|*args| self.run_data[:hash_simple_hash] << args }
				task_class.new( :queue )
			end


			it "runs the job for routing keys with the same first segment and one additional segment" do
				expect {
					publish( 'simple.additional1' )
				}.to change { task.run_data[:hash_simple_hash].length }
			end


			it "runs the job for routing keys which contain two additional segments" do
				expect {
					publish( 'simple.additional1.additional2' )
				}.to change { task.run_data[:hash_simple_hash].length }
			end


			it "runs the job for routing keys with only the same first segment" do
				expect {
					publish( 'simple' )
				}.to change { task.run_data[:hash_simple_hash].length }
			end


			it "runs the job for three-segment routing keys with a matching second segment" do
				expect {
					publish( 'prepended.simple.additional1' )
				}.to change { task.run_data[:hash_simple_hash].length }
			end


			it "runs the job for two-segment routing keys with a matching second segment" do
				expect {
					publish( 'prepended.simple' )
				}.to change { task.run_data[:hash_simple_hash].length }
			end


			it "doesn't run the job for routing keys with a different first segment" do
				expect {
					publish( 'notsimple.additional1' )
				}.to_not change { task.run_data[:hash_simple_hash].length }
			end

		end

	end

end

