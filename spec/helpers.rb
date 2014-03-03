#!/usr/bin/ruby
# coding: utf-8

# SimpleCov test coverage reporting; enable this using the :coverage rake task
require 'simplecov' if ENV['COVERAGE']

require 'loggability'
require 'loggability/spechelpers'
require 'configurability'
require 'configurability/behavior'

require 'rspec'

Loggability.format_with( :color ) if $stdout.tty?


### RSpec helper functions.
module Loggability::SpecHelpers
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
end

# vim: set nosta noet ts=4 sw=4:

