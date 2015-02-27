# -*- ruby -*-
#encoding: utf-8

require 'loggability'
require 'symphony' unless defined?( Symphony )


# A collection of statistics functions for various Symphony systems. Special
# thanks to Justin Z. Smith <justin@statisticool.com> for the maths. Good luck
# with your search for economic collapse in applesauce!
module Symphony::Statistics

	# The default number of samples to keep
	DEFAULT_SAMPLE_SIZE = 100


	### Set up some instance variables for tracking statistical info when the object
	### is created.
	def initialize( * )
		super
		@samples = []
		@sample_size = DEFAULT_SAMPLE_SIZE
	end


	# Samples of the number of pending jobs
	attr_reader :samples

	##
	# The number of samples to keep for analysis, and required
	# before trending is performed.
	attr_accessor :sample_size


	### Add the specified +value+ as a sample for the current time.
	def add_sample( value )
		@samples << [ Time.now.to_f, value ]
		@samples.pop( @samples.size - self.sample_size ) if @samples.size > self.sample_size
	end


	### Returns +true+ if the samples gathered so far indicate an upwards trend.
	def sample_values_increasing?
		return self.calculate_trend > 3
	end


	### Returns +true+ if the samples gathered so far indicate a downwards trend.
	def sample_values_decreasing?
		return self.calculate_trend < -3
	end


	### Predict the likelihood that an upward trend will continue based on linear regression
	### analysis of the given samples. If the value returned is >= 3.0, the values are
	### statistically trending upwards, which in Symphony's case means that the workers are
	### not handling the incoming work.
	def calculate_trend
		return 0 unless self.samples.size >= self.sample_size
		# Loggability[ Symphony ].debug "%d samples of required %d" % [ self.samples.size, self.sample_size ]

		x_vec, y_vec = self.samples.transpose

		y_avg = y_vec.inject( :+ ).to_f / y_vec.size
		x_avg = x_vec.inject( :+ ).to_f / x_vec.size

		# Find slope and y-intercept.
		#
		n = d = 0
		samples.each do |x, y_val|
			xv = x - x_avg
			n  = n + ( xv * ( y_val - y_avg ) )
			d  = d + ( xv ** 2 )
		end

		slope = n/d
		y_intercept = y_avg - ( slope * x_avg )

		# Find stderr.
		#
		r = s = 0
		samples.each do |x, y_val|
			yv = ( slope * x ) + y_intercept
			r  = r + ( (y_val - yv) ** 2 )
			s  = s + ( (x - x_avg) ** 2 )
		end

		stde = Math.sqrt( (r / ( samples.size - 2 )) / s )

		# Loggability[ Symphony ].debug "  job sampling trend is: %f" %  [ slope / stde ]
		return slope / stde
	end


end # module Symphony::Statistics

