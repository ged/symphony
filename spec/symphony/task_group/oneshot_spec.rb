#!/usr/bin/env rspec -cfd

require_relative '../../helpers'

require 'symphony/task_group/oneshot'


RSpec.describe Symphony::TaskGroup::Oneshot do

	let( :task ) do
		Class.new( Symphony::Task ) do
			extend Symphony::MethodUtilities

			singleton_attr_accessor :has_before_forked, :has_after_forked, :has_run

			def self::before_fork
				self.has_before_forked = true
			end
			def self::after_fork
				self.has_after_forked = true
			end
			def self::run
				self.has_run = true
			end
		end
	end

	let( :task_group ) do
		described_class.new( task, 2 )
	end


	it "starts workers for each of its worker slots" do
		allow( Process ).to receive( :setpgid )
		expect( Process ).to receive( :fork ).and_return( 11, 22 )
		expect( task_group.adjust_workers ).to eq([ 11, 22 ])
	end


	it "doesn't start workers if the max number of workers are already started" do
		expect( Process ).to_not receive( :fork )
		task_group.workers << 11 << 22
		expect( task_group.adjust_workers ).to be_nil
	end


	it "doesn't start anything if it's throttled" do
		# Simulate a child starting up and failing
		task_group.instance_variable_set( :@last_child_started, Time.now )
		task_group.adjust_throttle( 5 )

		expect( Process ).to_not receive( :fork )
		expect( task_group.adjust_workers ).to be_nil
	end
end

