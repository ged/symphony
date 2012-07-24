#!/usr/bin/env ruby

require 'laika' unless defined?( LAIKA )


### A collection of constants used in testing laika-groundcontrol classes
module LAIKA::GroundcontrolTestConstants # :nodoc:all

	unless defined?( A_CONSTANT )

		A_CONSTANT = :replace_me

		constants.each do |cname|
			const_get(cname).freeze
		end
	end

end

