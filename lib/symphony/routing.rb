# -*- ruby -*-
#encoding: utf-8

require 'loggability'

require 'symphony' unless defined?( Symphony )
require 'symphony/mixins'


# A mixin for adding handlers for multiple topic keys to a Task.
module Symphony::Routing
	extend Loggability
	log_to :symphony

	### Add some instance data to inheriting +subclass+es.
	def self::included( mod )
		self.log.info "Adding routing to %p" % [ mod ]
		super
		mod.extend( Symphony::MethodUtilities )
		mod.extend( Symphony::Routing::ClassMethods )
		mod.singleton_attr_accessor( :routes, :route_options )
		mod.routes = Hash.new {|h,k| h[k] = [] }
		mod.route_options = Hash.new {|h,k| h[k] = {} }
	end


	# Methods to add to including classes
	module ClassMethods

		### Register an event pattern and a block to execute when an event
		### matching that pattern is received.
		def on( *route_patterns, &block )
			raise LocalJumpError, "no block given" unless block
			options = route_patterns.pop if route_patterns.last.is_a?( Hash )
			route_patterns.each do |pattern|
				methodobj = self.make_handler_method( pattern, &block )
				self.routing_keys << pattern

				pattern_re = self.make_routing_pattern( pattern )
				self.routes[ pattern_re ] << methodobj
				self.route_options[ pattern ].merge!( options ) if options
			end
		end


		### Install the given +block+ as an instance method of the receiver, using
		### the given +pattern+ to derive the name, and return it as an UnboundMethod
		### object.
		def make_handler_method( pattern, &block )
			methname = self.make_handler_method_name( pattern, block )
			self.log.info "Setting up #%s as a handler for %s" % [ methname, pattern ]
			define_method( methname, &block )
			return self.instance_method( methname )
		end


		### Return the name of the method that the given +block+ should be installed
		### as, derived from the specified +pattern+.
		def make_handler_method_name( pattern, block )
			_, line = block.source_location
			pattern = pattern.
				gsub( /#/, 'hash' ).
				gsub( /\*/, 'star' ).
				gsub( /\./, '_' )

			return "on_%s_%d" % [ pattern, line ]
		end


		### Return a regular expression that will match messages matching the given
		### +routing_key+.
		def make_routing_pattern( routing_key )
			re_string = routing_key.gsub( /\./, '\\.' )
			re_string = re_string.gsub( /\*/, '([^\.]*)' )
			re_string = re_string.gsub( /#/, '(.*)' )

			return Regexp.compile( re_string )
		end

	end # module ClassMethods


	### Route the work based on the blocks registered with 'on'.
	def work( payload, metadata )
		key = metadata[:delivery_info].routing_key
		self.log.debug "Routing a %s message..." % [ key ]

		blocks = self.find_matching_blocks( key )

		self.log.debug "  calling %d block/s" % [ blocks.length ]
		return blocks.all? do |block|
			block.bind( self ).call( payload, metadata )
		end
	end


	### Return routing block whose patterns match the specified +key+.
	def find_matching_blocks( key )
		return self.class.routes.inject([]) do |accum, (re, re_blocks)|
			accum += re_blocks if re.match( key )
			accum
		end
	end

end # module Symphony::Routing


