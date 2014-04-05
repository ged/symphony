#!/usr/bin/env rspec -wfd
# vim: set nosta noet ts=4 sw=4:

require_relative '../helpers'

require 'symphony/mixins'

using Symphony::TimeRefinements

describe Symphony, 'mixins' do

	describe Symphony::MethodUtilities, 'used to extend a class' do

		let!( :extended_class ) do
			klass = Class.new
			klass.extend( Symphony::MethodUtilities )
			klass
		end

		it "can declare a class-level attribute reader" do
			extended_class.singleton_attr_reader :foo
			expect( extended_class ).to respond_to( :foo )
			expect( extended_class ).to_not respond_to( :foo= )
			expect( extended_class ).to_not respond_to( :foo? )
		end

		it "can declare a class-level attribute writer" do
			extended_class.singleton_attr_writer :foo
			expect( extended_class ).to_not respond_to( :foo )
			expect( extended_class ).to respond_to( :foo= )
			expect( extended_class ).to_not respond_to( :foo? )
		end

		it "can declare a class-level attribute reader and writer" do
			extended_class.singleton_attr_accessor :foo
			expect( extended_class ).to respond_to( :foo )
			expect( extended_class ).to respond_to( :foo= )
			expect( extended_class ).to_not respond_to( :foo? )
		end

		it "can declare a class-level alias" do
			def extended_class.foo
				return "foo"
			end
			extended_class.singleton_method_alias( :bar, :foo )

			expect( extended_class.bar ).to eq( 'foo' )
		end

		it "can declare an instance attribute predicate method" do
			extended_class.attr_predicate :foo
			instance = extended_class.new

			expect( instance ).to_not respond_to( :foo )
			expect( instance ).to_not respond_to( :foo= )
			expect( instance ).to respond_to( :foo? )

			expect( instance.foo? ).to eq( false )

			instance.instance_variable_set( :@foo, 1 )
			expect( instance.foo? ).to eq( true )
		end

		it "can declare an instance attribute predicate and writer" do
			extended_class.attr_predicate_accessor :foo
			instance = extended_class.new

			expect( instance ).to_not respond_to( :foo )
			expect( instance ).to respond_to( :foo= )
			expect( instance ).to respond_to( :foo? )

			expect( instance.foo? ).to eq( false )

			instance.foo = 1
			expect( instance.foo? ).to eq( true )
		end

	end


	describe "numeric constant methods" do

		SECONDS_IN_A_MINUTE    = 60
		SECONDS_IN_AN_HOUR     = SECONDS_IN_A_MINUTE * 60
		SECONDS_IN_A_DAY       = SECONDS_IN_AN_HOUR * 24
		SECONDS_IN_A_WEEK      = SECONDS_IN_A_DAY * 7
		SECONDS_IN_A_FORTNIGHT = SECONDS_IN_A_WEEK * 2
		SECONDS_IN_A_MONTH     = SECONDS_IN_A_DAY * 30
		SECONDS_IN_A_YEAR      = Integer( SECONDS_IN_A_DAY * 365.25 )

		it "can calculate the number of seconds for various units of time" do
			expect( 1.second ).to eq( 1 )
			expect( 14.seconds ).to eq( 14 )

			expect( 1.minute ).to eq( SECONDS_IN_A_MINUTE )
			expect( 18.minutes ).to eq( SECONDS_IN_A_MINUTE * 18 )

			expect( 1.hour ).to eq( SECONDS_IN_AN_HOUR )
			expect( 723.hours ).to eq( SECONDS_IN_AN_HOUR * 723 )

			expect( 1.day ).to eq( SECONDS_IN_A_DAY )
			expect( 3.days ).to eq( SECONDS_IN_A_DAY * 3 )

			expect( 1.week ).to eq( SECONDS_IN_A_WEEK )
			expect( 28.weeks ).to eq( SECONDS_IN_A_WEEK * 28 )

			expect( 1.fortnight ).to eq( SECONDS_IN_A_FORTNIGHT )
			expect( 31.fortnights ).to eq( SECONDS_IN_A_FORTNIGHT * 31 )

			expect( 1.month ).to eq( SECONDS_IN_A_MONTH )
			expect( 67.months ).to eq( SECONDS_IN_A_MONTH * 67 )

			expect( 1.year ).to eq( SECONDS_IN_A_YEAR )
			expect( 13.years ).to eq( SECONDS_IN_A_YEAR * 13 )
		end


		it "can calculate various time offsets" do
			starttime = Time.now

			expect( 1.second.after( starttime ) ).to eq( starttime + 1 )
			expect( 18.seconds.from_now ).to be_within( 10.seconds ).of( starttime + 18 )

			expect( 1.second.before( starttime ) ).to eq( starttime - 1 )
			expect( 3.hours.ago ).to be_within( 10.seconds ).of( starttime - 10800 )
		end
	end
end

