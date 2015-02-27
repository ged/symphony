#!/usr/bin/env rspec -cfd

require_relative '../helpers'

require 'symphony/statistics'


describe Symphony::Statistics do


	let( :including_class ) do
		new_class = Class.new
		new_class.instance_exec( described_class ) do |mixin|
			include( mixin )
		end
	end

	let( :object_with_statistics ) { including_class.new }


	def make_samples( *counts )
		start = 1414002605.0
		offset = 0
		return counts.each_with_object([]) do |count, accum|
			accum << [ start + offset, count ]
			offset += 1
		end
	end


	it "can detect an upwards trend in a sample set" do
		samples = make_samples( 1, 2, 2, 3, 3, 3, 4 )

		object_with_statistics.sample_size = samples.size
		object_with_statistics.samples.concat( samples )

		expect( object_with_statistics.sample_values_increasing? ).to be_truthy
	end


	it "can detect a downwards trend in a sample set" do
		samples = make_samples( 4, 3, 3, 2, 2, 2, 1 )

		object_with_statistics.sample_size = samples.size
		object_with_statistics.samples.concat( samples )

		expect( object_with_statistics.sample_values_decreasing? ).to be_truthy
	end


	it "isn't fooled by transitory spikes" do
		samples = make_samples( 1, 2, 222, 3, 2, 3, 2 )

		object_with_statistics.sample_size = samples.size
		object_with_statistics.samples.concat( samples )

		expect( object_with_statistics.sample_values_increasing? ).to be_falsey
	end


	it "doesn't try to detect a trend with a sample set that's too small" do
		upward_samples = make_samples( 1, 2, 2, 3, 3, 3, 4 )
		object_with_statistics.samples.replace( upward_samples )
		expect( object_with_statistics.sample_values_increasing? ).to be_falsey

		downward_samples = make_samples( 4, 3, 3, 2, 2, 2, 1 )
		object_with_statistics.samples.replace( downward_samples )
		expect( object_with_statistics.sample_values_decreasing? ).to be_falsey
	end
end

