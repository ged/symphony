#!/usr/bin/ruby
# coding: utf-8

# SimpleCov test coverage reporting; enable this using the :coverage rake task
require 'simplecov' if ENV['COVERAGE']

require 'loggability'
require 'loggability/spechelpers'
require 'configurability'
require 'configurability/behavior'
require 'timecop'

require 'symphony'
require 'symphony/task'
require 'rspec'

Loggability.format_with( :color ) if $stdout.tty?


### RSpec helper functions.
module Symphony::SpecHelpers

	class TestTask < Symphony::Task

		# Don't ever really try to handle messages.
		def start_handling_messages
		end
	end


	class DummySession

		class Queue
			def initialize( channel )
				@channel = channel
			end
			attr_reader :channel
			def name
				return 'dummy_queue_name'
			end
			def subscribe_with( * )
			end
		end
		class Channel
			def initialize
				@queue = nil
				@exchange = nil
			end
			def queue( name, opts={} )
				return @queue ||= DummySession::Queue.new( self )
			end
			def topic( * )
				return @exchange ||= DummySession::Exchange.new
			end
			def prefetch( * )
			end
			def number
				return 1
			end
			def close; end
		end

		class Exchange
		end

		def initialize
			@channel = nil
		end

		def start
			return true
		end

		def create_channel
			return @channel ||= DummySession::Channel.new
		end

		def close; end
	end

end


### Mock with RSpec
RSpec.configure do |config|
	config.run_all_when_everything_filtered = true
	config.filter_run :focus
	config.order = 'random'
	config.expect_with( :rspec )
	config.mock_with( :rspec ) do |mock|
		mock.syntax = :expect
	end

	config.include( Loggability::SpecHelpers )
	config.include( Symphony::SpecHelpers )
end

# vim: set nosta noet ts=4 sw=4:

