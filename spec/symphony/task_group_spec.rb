#!/usr/bin/env rspec -cfd

require_relative '../helpers'

describe Symphony::TaskGroup do

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
			def self::run( * )
				self.has_run = true
			end
		end
	end

	let( :task_group ) { described_class.new(task, 2) }


	it "can start and stop workers for its task" do
		pid = 17

		expect( task_group.workers ).to be_empty

		expect( Process ).to receive( :fork ) do |*args, &block|
			block.call
			pid
		end
		expect( Process ).to receive( :setpgid ).with( pid, 0 )
		task_group.start_worker

		expect( task_group.workers ).to_not be_empty
		expect( task_group.workers.size ).to eq( 1 )
		expect( task_group.workers.first ).to eq( pid )

		expect( Process ).to receive( :kill ).with( :TERM, task_group.workers.first )
		task_group.stop_worker

		status = double( Process::Status, :success? => true )
		task_group.on_child_exit( pid, status )
		expect( task_group.workers ).to be_empty
	end


	it "can stop all of its workers" do
		task_group.workers << 11 << 22 << 33 << 44
		expect( Process ).to receive( :kill ).with( :TERM, 11 )
		expect( Process ).to receive( :kill ).with( :TERM, 22 )
		expect( Process ).to receive( :kill ).with( :TERM, 33 )
		expect( Process ).to receive( :kill ).with( :TERM, 44 )
		task_group.stop_all_workers
	end


	it "can restart all of its workers" do
		task_group.workers << 11 << 22 << 33 << 44
		expect( Process ).to receive( :kill ).with( :HUP, 11 )
		expect( Process ).to receive( :kill ).with( :HUP, 22 )
		expect( Process ).to receive( :kill ).with( :HUP, 33 )
		expect( Process ).to receive( :kill ).with( :HUP, 44 )
		task_group.restart_workers
	end


	it "requires its concrete derivatives to overload #adjust_workers" do
		expect {
			task_group.adjust_workers
		}.to raise_error( NotImplementedError, /needs to provide/i )
	end


	it "provides a mechanism for throttling task startups" do
		expect( task_group ).to_not be_throttled
		expect( task_group.throttle_seconds ).to eq( 0 )

		# Simulate a child starting up and failing
		task_group.instance_variable_set( :@last_child_started, Time.now )
		task_group.adjust_throttle( 5 )

		expect( task_group ).to be_throttled
		expect( task_group.throttle_seconds ).to be > 0
	end

end

