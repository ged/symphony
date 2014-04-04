# -*- ruby -*-
#encoding: utf-8


module Symphony

	# A collection of methods for declaring other methods.
	#
	#   class MyClass
	#       extend Symphony::MethodUtilities
	#
	#       singleton_attr_accessor :types
	#       singleton_method_alias :kinds, :types
	#   end
	#
	#   MyClass.types = [ :pheno, :proto, :stereo ]
	#   MyClass.kinds # => [:pheno, :proto, :stereo]
	#
	module MethodUtilities

		### Creates instance variables and corresponding methods that return their
		### values for each of the specified +symbols+ in the singleton of the
		### declaring object (e.g., class instance variables and methods if declared
		### in a Class).
		def singleton_attr_reader( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_reader, sym )
			end
		end

		### Creates methods that allow assignment to the attributes of the singleton
		### of the declaring object that correspond to the specified +symbols+.
		def singleton_attr_writer( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_writer, sym )
			end
		end

		### Creates readers and writers that allow assignment to the attributes of
		### the singleton of the declaring object that correspond to the specified
		### +symbols+.
		def singleton_attr_accessor( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_accessor, sym )
			end
		end

		### Creates an alias for the +original+ method named +newname+.
		def singleton_method_alias( newname, original )
			singleton_class.__send__( :alias_method, newname, original )
		end


		### Create a reader in the form of a predicate for the given +attrname+.
		def attr_predicate( attrname )
			attrname = attrname.to_s.chomp( '?' )
			define_method( "#{attrname}?" ) do
				instance_variable_get( "@#{attrname}" ) ? true : false
			end
		end


		### Create a reader in the form of a predicate for the given +attrname+
		### as well as a regular writer method.
		def attr_predicate_accessor( attrname )
			attrname = attrname.to_s.chomp( '?' )
			attr_writer( attrname )
			attr_predicate( attrname )
		end

	end # module MethodUtilities


	### A collection of methods to add to Numeric for convenience (stolen from
	### ActiveSupport)
	module NumericConstantMethods

		### Append features to the including +mod+.
		def self::append_features( mod )
			constants.each do |c|
				self.const_get( c ).send( :append_features, mod )
			end
			super
		end

		### Time constants
		module Time

			### Number of seconds (returns receiver unmodified)
			def seconds
				return self
			end
			alias_method :second, :seconds

			### Returns number of seconds in <receiver> minutes
			def minutes
				return self * 60
			end
			alias_method :minute, :minutes

			### Returns the number of seconds in <receiver> hours
			def hours
				return self * 60.minutes
			end
			alias_method :hour, :hours

			### Returns the number of seconds in <receiver> days
			def days
				return self * 24.hours
			end
			alias_method :day, :days

			### Return the number of seconds in <receiver> weeks
			def weeks
				return self * 7.days
			end
			alias_method :week, :weeks

			### Returns the number of seconds in <receiver> fortnights
			def fortnights
				return self * 2.weeks
			end
			alias_method :fortnight, :fortnights

			### Returns the number of seconds in <receiver> months (approximate)
			def months
				return self * 30.days
			end
			alias_method :month, :months

			### Returns the number of seconds in <receiver> years (approximate)
			def years
				return (self * 365.25.days).to_i
			end
			alias_method :year, :years


			### Returns the Time <receiver> number of seconds before the 
			### specified +time+. E.g., 2.hours.before( header.expiration )
			def before( time )
				return time - self
			end


			### Returns the Time <receiver> number of seconds ago. (e.g., 
			### expiration > 2.hours.ago )
			def ago
				return self.before( ::Time.now )
			end


			### Returns the Time <receiver> number of seconds after the given +time+.
			### E.g., 10.minutes.after( header.expiration )
			def after( time )
				return time + self
			end


			### Return a new Time <receiver> number of seconds from now.
			def from_now
				return self.after( ::Time.now )
			end


			### Return a string describing approximately the amount of time in 
			### <receiver> number of seconds.
			def timeperiod
				return case
					when self < 1.minute
						'less than a minute'
					when self < 50.minutes
						'%d minutes' % [ (self.to_f / 1.minute).ceil ]
					when self < 90.minutes
						'about an hour'
					when self < 18.hours
						"%d hours" % [ (self.to_f / 1.hour).ceil ]
					when self < 30.hours
						'about a day'
					when self < 1.week
						"%d days" % [ (self.to_f / 1.day).ceil ]
					when self < 2.weeks
						'about one week'
					when self < 3.months
						"%d weeks" % [ (self.to_f / 1.week).ceil ]
					when self < 18.months
						"%d months" % [ (self.to_f / 1.month).ceil ]
					else
						"%d years" % [ (self.to_f / 1.year).ceil ]
					end
			end

		end # module Time
	end

end # module Symphony


### Add convenience methods to Numerics
class Numeric
	include Symphony::NumericConstantMethods
end

