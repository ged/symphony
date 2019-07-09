#!/usr/bin/env rspec -cfd

require_relative '../../helpers'

require 'symphony/task_group/longlived'

describe Symphony::TaskGroup::LongLived do

	FIRST_PID = 414

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

	let( :pid_generator ) do
		Enumerator.new do |generator|
			i = FIRST_PID
			loop do
				generator.yield( i )
				i += rand( 3 ) + 1
			end
		end
	end



	it "doesn't start anything if it's throttled" do
		# Simulate a child starting up and failing
		task_group.instance_variable_set( :@last_child_started, Time.now )
		task_group.adjust_throttle( 5 )

		expect( Process ).to_not receive( :fork )
		expect( task_group.adjust_workers ).to be_nil
	end


	context "when told to adjust its worker pool" do

		before( :each ) do
			allow( Process ).to receive( :fork ) { pid_generator.next }
		end


		it "starts an initial worker if it doesn't have any" do
			allow( Process ).to receive( :setpgid ).with( FIRST_PID, 0 )

			task_group.adjust_workers

			expect( task_group.workers ).to_not be_empty
			expect( task_group.workers ).to contain_exactly( FIRST_PID )
		end


		it "starts an additional worker if its work load is trending upward" do
			samples = [ 1, 2, 2, 3, 3, 3, 4 ]
			task_group.sample_size = samples.size

			allow( Process ).to receive( :setpgid )

			channel = double( Bunny::Channel )
			queue = double( Bunny::Queue )
			expect( Symphony::Queue ).to receive( :amqp_channel ).
				and_return( channel )
			expect( channel ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue )

			expect( queue ).to receive( :consumer_count ) do
				task_group.workers.size
			end.at_least( :once )
			expect( queue ).to receive( :message_count ).and_return( *samples )

			start = 1414002605
			start.upto( start + samples.size + 1 ) do |time|
				Timecop.freeze( time ) do
					task_group.adjust_workers
				end
			end

			expect( task_group.workers ).to include( FIRST_PID )
			expect( task_group.workers.length ).to eq( 2 )
		end


		it "starts an additional worker if its work load is holding steady at a non-zero value" do
			samples = [ 4, 4, 4, 5, 5, 4, 4 ]
			task_group.sample_size = samples.size - 3

			allow( Process ).to receive( :setpgid )

			channel = double( Bunny::Channel )
			queue = double( Bunny::Queue )
			expect( Symphony::Queue ).to receive( :amqp_channel ).
				and_return( channel )
			expect( channel ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue )

			expect( queue ).to receive( :consumer_count ) do
				task_group.workers.size
			end.at_least( :once )
			expect( queue ).to receive( :message_count ).and_return( *samples )

			start = 1414002605
			start.upto( start + samples.size + 1 ) do |time|
				Timecop.freeze( time ) do
					task_group.adjust_workers
				end
			end

			expect( task_group.workers.size ).to eq( 2 )
		end


		it "doesn't start a worker if it's already running the maximum number of workers" do
			samples = [ 1, 2, 2, 3, 3, 3, 4, 4, 4, 5 ]
			task_group.sample_size = samples.size - 3

			allow( Process ).to receive( :setpgid )

			channel = double( Bunny::Channel )
			queue = double( Bunny::Queue )
			expect( Symphony::Queue ).to receive( :amqp_channel ).
				and_return( channel )
			expect( channel ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue )

			expect( queue ).to receive( :consumer_count ) do
				task_group.workers.size
			end.at_least( :once )
			expect( queue ).to receive( :message_count ).and_return( *samples )

			start = 1414002605
			start.upto( start + samples.size + 1 ) do |time|
				Timecop.freeze( time ) do
					task_group.adjust_workers
				end
			end

			expect( task_group.workers.size ).to eq( 2 )
		end


		it "doesn't start anything if its work load is holding steady at zero" do
			samples = [ 0, 1, 0, 0, 0, 0, 1, 0, 0 ]
			task_group.sample_size = samples.size - 3

			allow( Process ).to receive( :setpgid )

			channel = double( Bunny::Channel )
			queue = double( Bunny::Queue )
			expect( Symphony::Queue ).to receive( :amqp_channel ).
				and_return( channel )
			expect( channel ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue )

			allow( queue ).to receive( :consumer_count ).and_return( 1 )
			expect( queue ).to receive( :message_count ).and_return( *samples )

			start = 1414002605
			start.upto( start + samples.size + 1 ) do |time|
				Timecop.freeze( time ) do
					task_group.adjust_workers
				end
			end

			expect( task_group.workers.size ).to eq( 1 )
		end


		it "doesn't start anything if its work load is trending downward" do
			samples = [ 4, 3, 3, 2, 2, 2, 1, 1, 0, 0 ]
			task_group.sample_size = samples.size

			allow( Process ).to receive( :setpgid )

			channel = double( Bunny::Channel )
			queue = double( Bunny::Queue )
			expect( Symphony::Queue ).to receive( :amqp_channel ).
				and_return( channel )
			expect( channel ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue )

			expect( queue ).to receive( :consumer_count ) do
				task_group.workers.size
			end.at_least( :once )
			expect( queue ).to receive( :message_count ).and_return( *samples )

			start = 1414002605
			start.upto( start + samples.size + 1 ) do |time|
				Timecop.freeze( time ) do
					task_group.adjust_workers
				end
			end

			expect( task_group.workers.size ).to eq( 1 )
		end


		it "reconnects if the message-count channel goes away" do
			samples = [ 4, 3, 3 ]
			task_group.sample_size = samples.size

			allow( Process ).to receive( :setpgid )

			channel1 = double( Bunny::Channel )
			channel2 = double( Bunny::Channel )
			queue1 = double( Bunny::Queue )
			queue2 = double( Bunny::Queue )

			expect( Symphony::Queue ).to receive( :amqp_channel ).
				twice.
				and_return( channel1, channel2 )

			expect( channel1 ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue1 )
			expect( queue1 ).to_not receive( :consumer_count )
			expect( queue1 ).to receive( :message_count ).
				and_raise( Bunny::ChannelAlreadyClosed.new("cannot use a closed channel!", channel1) )

			expect( channel2 ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue2 )
			expect( queue2 ).to receive( :consumer_count ) do
				task_group.workers.size
			end.at_least( :once )
			expect( queue2 ).to receive( :message_count ).and_return( *samples )

			start = 1414002605
			start.upto( start + samples.size + 2 ) do |time|
				Timecop.freeze( time ) do
					task_group.adjust_workers
				end
			end
		end


		it "reconnects if the message-count call times out" do
			samples = [ 4, 3, 3 ]
			task_group.sample_size = samples.size

			allow( Process ).to receive( :setpgid )

			channel1 = double( Bunny::Channel )
			channel2 = double( Bunny::Channel )
			queue1 = double( Bunny::Queue )
			queue2 = double( Bunny::Queue )

			expect( Symphony::Queue ).to receive( :amqp_channel ).
				twice.
				and_return( channel1, channel2 )

			expect( channel1 ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue1 )
			expect( queue1 ).to_not receive( :consumer_count )
			expect( queue1 ).to receive( :message_count ).
				and_raise( Timeout::Error.new )

			expect( channel2 ).to receive( :queue ).
				with( task.queue_name, passive: true, prefetch: 0 ).
				and_return( queue2 )
			expect( queue2 ).to receive( :consumer_count ) do
				task_group.workers.size
			end.at_least( :once )
			expect( queue2 ).to receive( :message_count ).and_return( *samples )

			start = 1414002605
			start.upto( start + samples.size + 2 ) do |time|
				Timecop.freeze( time ) do
					task_group.adjust_workers
				end
			end
		end

	end

end

