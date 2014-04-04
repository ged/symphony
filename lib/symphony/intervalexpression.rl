# vim: set noet nosta sw=4 ts=4 ft=ragel :

%%{
	#
	# Generate the actual code like so:
	#    ragel -R -T1 -Ls inputfile.rl
	#

	machine interval_expression;

	########################################################################
	### A C T I O N S
	########################################################################

	action set_mark { mark = p }

	action set_valid   { event.instance_variable_set( :@valid, true ) }
	action set_invalid { event.instance_variable_set( :@valid, false ) }
	action recurring   { event.instance_variable_set( :@recurring, true ) }

	action start_time {
		time = event.send( :extract, mark, p - mark )
		event.send( :set_starting, time, :time )
	}

	action start_interval {
		interval = event.send( :extract, mark, p - mark )
		event.send( :set_starting, interval, :interval )
	}

	action execute_time {
		time = event.send( :extract, mark, p - mark )
		event.send( :set_interval, time, :time )
	}

	action execute_interval {
		interval = event.send( :extract, mark, p - mark )
		event.send( :set_interval, interval, :interval )
	}

	action execute_multiplier {
		multiplier = event.send( :extract, mark, p - mark ).sub( / times/, '' )
		event.instance_variable_set( :@multiplier, multiplier.to_i )
	}

	action ending_time {
		time = event.send( :extract, mark, p - mark )
		event.send( :set_ending, time, :time )
	}

	action ending_interval {
		interval = event.send( :extract, mark, p - mark )
		event.send( :set_ending, interval, :interval )
	}

	
	########################################################################
	### P R E P O S I T I O N S
	########################################################################

	recur_preposition    = ( 'every' | 'each' | 'per' | 'once' ' per'? ) @recurring;
	time_preposition     = 'at' | 'on';
	interval_preposition = 'in';


	########################################################################
	### T I M E  S P E C S
	########################################################################

	# 2014-05-01
	# 2014-05-01 15:00
	# 2014-05-01 15:00:30
	#
	fulldate = digit{4} '-' digit{2} '-' digit{2}
		( space+ digit{2} ':' digit{2} ( ':' digit{2} )? )?;

	# 10am
	# 2:45pm
	#
	time = digit{1,2} ( ':' digit{2} )? ( 'am' | 'pm' );

	# union of the above
	date_or_time = fulldate | time;

	# 20 seconds
	# 5 hours
	# 1 hour
	# an hour
	# a minute
	# other minute
	#
	interval =
		(
			((( 'a' | 'an' ) | [1-9][0-9]* ) space+) |
			( 'other' space+)
		)?
		( 'milli'? 'second' | 'minute' | 'hour' | 'day' | 'week' | 'month' | 'year' ) 's'?;


	########################################################################
	### A C T I O N   C H A I N S
	########################################################################

	start_time = date_or_time                         >set_mark %start_time;
	start_interval = interval                     >set_mark %start_interval;

	start_expression = ( (time_preposition space+)? start_time ) |
		( (interval_preposition space+)? start_interval );

	execute_time = date_or_time                     >set_mark %execute_time;
	execute_interval = interval                 >set_mark %execute_interval;
	execute_multiplier = ( digit+ space+ 'times' )
		>set_mark %execute_multiplier @recurring;

	execute_expression = (
		# regular dates and intervals
			( time_preposition space+ execute_time ) |
			( ( interval_preposition | recur_preposition ) space+ execute_interval )
		) | (
		# count + interval (10 times every minute)
			execute_multiplier space+ ( recur_preposition space+ )? execute_interval
		) |
		# count for 'timeboxed' intervals
			execute_multiplier;


	ending_time = date_or_time                       >set_mark %ending_time;
	ending_interval = interval                   >set_mark %ending_interval;

	ending_expression = ( (time_preposition space+)? ending_time ) |
		( (interval_preposition space+)? ending_interval );


	########################################################################
	### M A C H I N E S
	########################################################################

	Start = (
		start:      ( 'start' | 'begin' 'n'? ) 'ing'? space+  -> StartTime,
		StartTime:  start_expression                          -> Decorators,
		Decorators: ( ','? space+ 'from now' ','? )? space+   -> final
	);

	Interval = (
		start:
		SDecorators: ( ('run' | 'exec' 'ute'?) space+ )?     -> ExecuteTime,
		ExecuteTime: execute_expression                      -> EDecorators,
		EDecorators: ( space+ 'from now' )?                  -> final
	);

	Ending = (
		start: space+
			( 'for' ' the next'? | 'until' | ('end'|'finish'|'stop') 'ing'? )
			space+                                           -> EndingTime,
		EndingTime: ending_expression                        -> Decorators,
		Decorators: ( space+ 'from now' )?                   -> final
	);

	main := Start? Interval Ending? %set_valid @!set_invalid;

}%%


require 'symphony' unless defined?( Symphony )
require 'time'

### Parse natural English expressions of times and intervals.
###
###  in 30 minutes
###  once an hour
###  every 15 minutes for 2 days
###  starting on 2014-05-01
###  at 2014-04-01 14:00:25
###  at 2pm
###  starting at 2pm once a day
###  start in 1 hour from now run every 5 seconds end at 11:15pm
###  every other hour
###  once a day ending in 1 week
###  10 times a minute for 2 days
###  run 45 times every hour
###  start at 2010-01-02 run 12 times and end on 2010-01-03
###  starting in an hour from now run 6 times a minute for 2 hours
###  beginning a day from now, run 30 times per minute and finish in 2 weeks
###
class Symphony::IntervalExpression
	include Comparable
	extend Loggability
	log_to :symphony

	# Ragel accessors are injected as class methods/variables for some reason.
	%% write data;

	# The generic parse exception class.
	class Symphony::TimeParseError < ArgumentError; end


	########################################################################
	### C L A S S   M E T H O D S
	########################################################################

	### Parse a schedule expression +exp+.
	###
	### Parsing defaults to Time.now(), but if passed a +time+ object,
	### all contexual times (2pm) are relative to it.  If you know when
	### an expression was generated, you can 'reconstitute' an interval
	### object this way.
	###
	def self::parse( exp, time=nil )

		# Normalize the expression before parsing
		#
		exp = exp.downcase.
			gsub( /(?:[^[a-z][0-9][\-:]\s]+)/, '' ).  # : - a-z 0-9 only
			gsub( /(?:and|then)/, '' ).               # remove common decorator words
			gsub( /\s+/, ' ' ).                       # collapse whitespace
			gsub( /([:\-])+/, '\1' )                  # collapse multiple - or : chars

		event = new( exp, time || Time.now )
		data  = event.instance_variable_get( :@data )

		# Ragel interface variables
		#
		key    = ''
		mark   = 0
		%% write init;
		eof = pe
		%% write exec;

		# Attach final time logic and sanity checks.
		event.send( :finalize )

		return event
	end


	########################################################################
	### I N S T A N C E   M E T H O D S
	########################################################################

	### Instantiate a new TimeExpression, provided an +expression+ string
	### that describes when this event will take place in natural english,
	### and a +base+ Time to perform calculations against.
	###
	private_class_method :new
	def initialize( expression, base ) # :nodoc:
		@exp  = expression
		@data = expression.to_s.unpack( 'c*' )
		@base = base

		@valid      = false
		@recurring  = false
		@starting   = nil
		@interval   = nil
		@multiplier = nil
		@ending     = nil
	end


	######
	public
	######

	# Is the schedule expression parsable?
	attr_reader :valid

	# Does this event repeat?
	attr_reader :recurring

	# The valid start time for the schedule (for recurring events)
	attr_reader :starting

	# The valid end time for the schedule (for recurring events)
	attr_reader :ending

	# The interval to wait before the event should be acted on.
	attr_reader :interval

	# An optional interval multipler for expressing counts.
	attr_reader :multiplier


	### If this interval is on a stack somewhere and ready to
	### fire, is it okay to do so based on the specified
	### expression criteria?
	###
	### Returns +true+ if it should fire, +false+ if it should not
	### but could at a later attempt, and +nil+ if the interval has
	### expired.
	###
	def fire?
		now = Time.now

		# Interval has expired.
		return nil if self.ending && now > self.ending

		# Interval is not yet in its current time window.
		return false if self.starting - now > 0

		# Looking good.
		return true
	end


	### Just return the original event expression.
	###
	def to_s
		return @exp
	end


	### Inspection string.
	###
	def inspect
		return ( "<%s:0x%08x valid:%s recur:%s expression:%p " +
					"starting:%p interval:%p ending:%p>" ) % [
			self.class.name,
			self.object_id * 2,
			self.valid,
			self.recurring,
			self.to_s,
			self.starting,
			self.interval,
			self.ending
		]
	end


	### Comparable interface, order by interval, 'soonest' first.
	###
	def <=>( other )
		return self.interval <=> other.interval
	end


	#########
	protected
	#########

	### Given a +start+ and +ending+ scanner position,
	### return an ascii representation of the data slice.
	###
	def extract( start, ending )
		slice = @data[ start, ending ]
		return '' unless slice
		return slice.pack( 'c*' )
	end


	### Parse and set the starting attribute, given a +time_arg+
	### string and the +type+ of string (interval or exact time)
	###
	def set_starting( time_arg, type )
		start = self.get_time( time_arg, type )
		@starting = start
		return @starting
	end


	### Parse and set the interval attribute, given a +time_arg+
	### string and the +type+ of string (interval or exact time)
	###
	### Perform consistency and sanity checks before returning an
	### integer representing the amount of time needed to sleep before
	### firing the event.
	###
	def set_interval( time_arg, type )
		interval = nil
		if self.starting && type == :time
			raise Symphony::TimeParseError, "That doesn't make sense, just use 'at [datetime]' instead"
		else
			interval = self.get_time( time_arg, type )
			interval = interval - @base
		end

		@interval = interval
		return @interval
	end


	### Parse and set the ending attribute, given a +time_arg+
	### string and the +type+ of string (interval or exact time)
	###
	### Perform consistency and sanity checks before returning a
	### Time object.
	###
	def set_ending( time_arg, type )
		ending = nil

		# Ending dates only make sense for recurring events.
		#
		if self.recurring

			# Make the interval an offset of the start time, instead of now.
			#
			# This is the contextual difference between:
			#   every minute until 6 hours from now (ending based on NOW)
			#   and
			#   starting in a year run every minute for 1 month (ending based on start time)
			#
			if self.starting && type == :interval
				diff = self.parse_interval( time_arg )
				ending = self.starting + diff

			# (offset from now)
			#
			else
				ending = self.get_time( time_arg, type )
			end

			# Check the end time is after the start time.
			#
			if self.starting && ending < self.starting
				raise Symphony::TimeParseError, "recurring event ends after it begins"
			end

		else
			self.log.debug "Ignoring ending date, event is not recurring."
		end

		@ending = ending
		return @ending
	end


	### Perform finishing logic and final sanity checks before returning
	### a parsed object.
	###
	def finalize
		raise Symphony::TimeParseError, "unable to parse expression" unless self.valid

		# Ensure start time is populated.
		#
		# TODO: This will be required for future modulus
		# (run every other day) feature.
		#
		@starting = @base unless self.starting

		# Alter the interval if a multiplier was specified.
		#
		if self.multiplier
			if self.ending

				# Regular 'count' style multipler with end date.
				# (run 10 times a minute for 2 days)
				# Just divide the current interval by the count.
				#
				if self.interval
					@interval = self.interval.to_f / self.multiplier

				# Timeboxed multiplier (start [date] run 10 times end [date])
				# Evenly spread the interval out over the time window.
				#
				else
					diff = self.ending - self.starting
					@interval = diff.to_f / self.multiplier
				end

			# Regular 'count' style multipler (run 10 times a minute)
			# Just divide the current interval by the count.
			#
			else
				raise Symphony::TimeParseError, "An end date or interval is required" unless self.interval
				@interval = self.interval.to_f / self.multiplier
			end
		end
	end


	### Given a +time_arg+ string and a type (:interval or :time),
	### dispatch to the appropriate parser.
	###
	def get_time( time_arg, type )
		time = nil

		if type == :interval
			secs = self.parse_interval( time_arg )
			time = @base + secs if secs
		end

		if type == :time
			time = self.parse_time( time_arg )
		end

		raise Symphony::TimeParseError, "unable to parse time" if time.nil?
		return time
	end


	### Parse a +time_arg+ string (anything parsable buy Time.parse())
	### into a Time object.
	###
	def parse_time( time_arg )
		time = Time.parse( time_arg, @base ) rescue nil

		# Generated date is in the past.
		#
		if time && @base > time

			# Ensure future dates for ambiguous times (2pm)
			time = time + 1.day if time_arg.length < 8

			# Still in the past, abandon all hope.
			raise Symphony::TimeParseError, "attempt to schedule in the past" if @base > time
		end

		self.log.debug "Parsed %p (time) to: %p" % [ time_arg, time ]
		return time
	end


	### Parse a +time_arg+ interval string ("30 seconds") into an
	### Integer.
	###
	def parse_interval( interval_arg )
		duration, span = interval_arg.split( /\s+/ )

		# catch the 'a' or 'an' case (ex: "an hour")
		duration = 1 if duration.index( 'a' ) == 0

		# catch the 'other' case, ie: 'every other hour'
		duration = 2 if duration == 'other'

		# catch the singular case (ex: "hour")
		unless span
			span = duration
			duration = 1
		end

		use_milliseconds = span.sub!( 'milli', '' )
		interval = duration.to_i.send( span.to_sym )

		# milliseconds
		interval = duration.to_f / 1000 if use_milliseconds

		self.log.debug "Parsed %p (interval) to: %p" % [ interval_arg, interval ]
		return interval
	end

end # class TimeExpression

