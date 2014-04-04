# vim: set nosta noet ts=4 sw=4 ft=rspec:

require_relative '../helpers'
require 'symphony/intervalexpression'

#####################################################################
###	C O N T E X T S
#####################################################################

describe Symphony::IntervalExpression do

	let( :past ) { Time.at(1262376000) }

	it "can't be instantiated directly" do
		expect { described_class.new }.to raise_error( NoMethodError )
	end

	it "raises an exception if unable to parse the expression" do
		expect {
			described_class.parse( 'wut!' )
		}.to raise_error( Symphony::TimeParseError, /unable to parse/ )
	end

	it "normalizes the expression before attempting to parse it" do
		allow( Time ).to receive( :now ).and_return( past )
		parsed = described_class.parse( '\'";At  2014---01-01   14::00(' )
		expect( parsed.to_s ).to eq( 'at 2014-01-01 14:00' )
	end

	it "can parse the expression, offset from a different time" do
		parsed = described_class.parse( 'every 5 seconds ending in an hour', past )
		expect( parsed.starting ).to eq( past )
		expect( parsed.ending ).to eq( past + 3600 )
	end

	it "is comparable" do
		p1 = described_class.parse( 'at 2pm', past )
		p2 = described_class.parse( 'at 3pm', past )
		p3 = described_class.parse( 'at 2:00pm', past )

		expect( p1 ).to be < p2
		expect( p2 ).to be > p1
		expect( p1 ).to eq( p3 )
	end

	it "won't allow scheduling dates in the past" do
		expect {
			described_class.parse( 'on 1999-01-01' )
		}.to raise_error( Symphony::TimeParseError, /schedule in the past/ )
	end

	it "doesn't allow intervals of 0" do
		expect {
			described_class.parse( 'every 0 seconds' )
		}.to raise_error( Symphony::TimeParseError, /unable to parse/ )
	end


	context 'exact times and dates' do

		# stub for Time, tests are from this 'stuck' point:
		# 2010-01-01 12:00
		#
		before( :each ) do
			allow( Time ).to receive( :now ).and_return( past )
		end

		it 'at 2pm' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be
			expect( parsed.recurring ).to be_falsey
			expect( parsed.interval ).to be( 7200.0 )
		end

		it 'at 2:30pm' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 9000.0 )
		end

		it "pushes ambiguous times in today's past into tomorrow (at 11am)" do
			parsed = described_class.parse( 'at 11am' )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 82800.0 )
		end

		it 'on 2010-01-02' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 43200.0 )
		end

		it 'on 2010-01-02 12:00' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 86400.0 )
		end

		it 'on 2010-01-02 12:00:01' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 86401.0 )
		end

		it 'correctly timeboxes the expression' do
			parsed = described_class.parse( 'at 2pm' )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 7200.0 )
			expect( parsed.ending ).to be_nil
			expect( parsed.recurring ).to be_falsey
			expect( parsed.starting ).to eq( past )
		end

		it 'always sets a start time if one is not specified' do
			parsed = described_class.parse( 'at 2pm'  )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_falsey
			expect( parsed.starting ).to eq( past )
			expect( parsed.interval ).to be( 7200.0 )
		end
	end

	context 'one-shot intervals' do

		# stub for Time, tests are from this 'stuck' point:
		# 2010-01-01 12:00
		#
		before( :each ) do
			allow( Time ).to receive( :now ).and_return( past )
		end

		it 'in 30 seconds' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_falsey
			expect( parsed.interval ).to be( 30.0 )
		end

		it 'in 30 seconds from now' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 30.0 )
		end

		it 'in an hour from now' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 3600.0 )
		end

		it 'in a minute' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 60.0 )
		end

		it 'correctly timeboxes the expression' do
			parsed = described_class.parse( 'in 30 seconds' )
			expect( parsed.valid ).to be_truthy
			expect( parsed.interval ).to be( 30.0 )
			expect( parsed.ending ).to be_nil
			expect( parsed.recurring ).to be_falsey
			expect( parsed.starting ).to eq( past )
		end

		it 'always sets a start time if one is not specified' do
			parsed = described_class.parse( 'in 5 seconds'  )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_falsey
			expect( parsed.starting ).to eq( past )
			expect( parsed.interval ).to be( 5.0 )
		end

		it 'ignores end specifications for non-recurring run times' do
			parsed = described_class.parse( 'run at 2010-01-02 end at 2010-03-01' )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_falsey
			expect( parsed.starting ).to eq( past )
			expect( parsed.ending ).to be_falsey
			expect( parsed.interval ).to be( 43200.0 )
		end
	end

	context 'repeating intervals' do

		# stub for Time, tests are from this 'stuck' point:
		# 2010-01-01 12:00
		#
		before( :each ) do
			allow( Time ).to receive( :now ).and_return( past )
		end

		it 'every 500 milliseconds' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 0.5 )
		end

		it 'every 30 seconds' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 30.0 )
		end

		it 'once an hour' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 3600.0 )
		end

		it 'once a minute' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 60.0 )
		end

		it 'once per week' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 604800.0 )
		end

		it 'every day' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 86400.0 )
		end

		it 'every other day' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 172800.0 )
		end

		it 'always sets a start time if one is not specified' do
			parsed = described_class.parse( 'every 5 seconds'  )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past )
			expect( parsed.interval ).to be( 5.0 )
		end
	end

	context 'repeating intervals with only an expiration date' do

		# stub for Time, tests are from this 'stuck' point:
		# 2010-01-01 12:00
		#
		before( :each ) do
			allow( Time ).to receive( :now ).and_return( past )
		end

		it 'every day ending in 1 week' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 86400.0 )
			expect( parsed.ending ).to eq( past + 604800 )
		end

		it 'once a day finishing in a week from now' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 86400.0 )
			expect( parsed.ending ).to eq( past + 604800 )
		end

		it 'once a day until 2010-02-01' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 86400.0 )
			expect( parsed.ending ).to eq( past + 2635200 )
		end

		it 'once a day end on 2010-02-01 00:00:10' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.interval ).to be( 86400.0 )
			expect( parsed.ending ).to eq( past + 2635210 )
		end

		it 'always sets a start time if one is not specified' do
			parsed = described_class.parse( 'every 5 seconds ending in 1 week'  )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past )
			expect( parsed.interval ).to be( 5.0 )
			expect( parsed.ending ).to eq( past + 604800 )
		end
	end

	context 'repeating intervals with only a start time' do

		# stub for Time, tests are from this 'stuck' point:
		# 2010-01-01 12:00
		#
		before( :each ) do
			allow( Time ).to receive( :now ).and_return( past )
		end

		it "won't allow explicit start times with non-recurring run times" do
			expect {
				described_class.parse( 'start at 2010-02-01 run at 2010-02-01' )
			}.to raise_error( Symphony::TimeParseError, /use 'at \[datetime\]' instead/ )
		end

		it 'starting in 5 minutes, run once a second' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 300 )
			expect( parsed.interval ).to be( 1.0 )
		end

		it 'starting in a day execute every 3 minutes' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 86400 )
			expect( parsed.interval ).to be( 180.0 )
		end

		it 'start at 2010-01-02 execute every 1 minute' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 43200 )
			expect( parsed.interval ).to be( 60.0 )
		end

		it 'always sets a start time if one is not specified' do
			parsed = described_class.parse( 'every 5 seconds'  )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past )
			expect( parsed.interval ).to be( 5.0 )
		end
	end

	context 'intervals with start and end times' do

		# stub for Time, tests are from this 'stuck' point:
		# 2010-01-01 12:00
		#
		before( :each ) do
			allow( Time ).to receive( :now ).and_return( past )
		end

		it 'beginning in 1 hour from now run every 5 seconds ending on 2010-01-02' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 3600 )
			expect( parsed.interval ).to be( 5.0 )
			expect( parsed.ending ).to eq( past + 43200 )
		end

		it 'starting in 1 hour, run every 5 seconds and finish at 3pm' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 3600 )
			expect( parsed.interval ).to be( 5.0 )
			expect( parsed.ending ).to eq( past + 3600 * 3 )
		end

		it 'begin in an hour run every 5 seconds and then stop at 3pm' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 3600 )
			expect( parsed.interval ).to be( 5.0 )
			expect( parsed.ending ).to eq( past + 3600 * 3 )
		end

		it 'start at 2010-01-02 10:00 and then run each minute for the next 6 days' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.valid ).to be_truthy
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 43200 + 36000 )
			expect( parsed.interval ).to be( 60.0 )
			expect( parsed.ending ).to eq( Time.parse('2010-01-02 10:00') + 86400 * 6 )
		end
	end

	context 'intervals with a count' do

		# stub for Time, tests are from this 'stuck' point:
		# 2010-01-01 12:00
		#
		before( :each ) do
			allow( Time ).to receive( :now ).and_return( past )
		end

		it "won't allow count multipliers without an interval nor an end date" do
			expect {
				described_class.parse( 'run 10 times' )
			}.to raise_error( Symphony::TimeParseError, /end date or interval is required/ )
		end

		it '10 times a minute for 2 days' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.multiplier ).to be( 10 )
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past )
			expect( parsed.interval ).to be( 6.0 )
			expect( parsed.ending ).to eq( past + 86400 * 2 )
		end

		it 'run 45 times every hour' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.multiplier ).to be( 45 )
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past )
			expect( parsed.interval ).to be( 80.0 )
			expect( parsed.ending ).to be_nil
		end

		it 'start at 2010-01-02 run 12 times and end on 2010-01-03' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.multiplier ).to be( 12 )
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 43200 )
			expect( parsed.interval ).to be( 7200.0 )
			expect( parsed.ending ).to eq( past + 86400 + 43200 )
		end

		it 'starting in an hour from now run 6 times a minute for 2 hours' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.multiplier ).to be( 6 )
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 3600 )
			expect( parsed.interval ).to be( 10.0 )
			expect( parsed.ending ).to eq( past + 3600 * 3 )
		end

		it 'beginning a day from now, run 30 times per minute and finish in 2 weeks' do |example|
			parsed = described_class.parse( example.description )
			expect( parsed.multiplier ).to be( 30 )
			expect( parsed.recurring ).to be_truthy
			expect( parsed.starting ).to eq( past + 86400 )
			expect( parsed.interval ).to be( 2.0 )
			expect( parsed.ending ).to eq( past + 1209600 + 86400 )
		end
	end

	context "when checking if it's okay to run" do

		it 'returns true if the interval is within bounds' do
			parsed = described_class.parse( 'at 2pm' )
			expect( parsed.fire? ).to be_truthy
		end

		it 'returns nil if the ending (expiration) date has passed' do
			allow( Time ).to receive( :now ).and_return( past )
			parsed = described_class.parse( 'every minute' )
			parsed.instance_variable_set( :@ending, past - 30 )
			expect( parsed.fire? ).to be_nil
		end

		it 'returns false if the starting window has yet to occur' do
			parsed = described_class.parse( 'starting in 2 hours run each minute' )
			expect( parsed.fire? ).to be_falsey
		end
	end
end

