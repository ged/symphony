#!/usr/bin/env ruby

require 'laika' unless defined?( LAIKA )
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )
require 'laika/model'

# A task base class for LAIKA GroundControl jobs.
class LAIKA::GroundControl::Job < LAIKA::Model( :groundcontrol__jobs )

	plugin :validation_helpers
	plugin :schema
	plugin :timestamps

	# Define the schema. If you're changing this, you should also be defining
	# a migration.
	set_schema do
		primary_key :id

		column :queue_name, :text, :null => false, :default => 'default'
		column :method_name, :text, :null => false
		column :arguments, :text

		column :created_at, :timestamp
		column :locked_at, :timestamp
	end

	def_dataset_method( :for_queue ) {|queue_name| filter(:queue_name => queue_name) }
	def_dataset_method( :running ) { filter(:locked_at) }


	### Validation callback.
	def validate
		super

		self.validate_required_fields
	end


	### Ensure required fields are defined.
	def validate_required_fields
		self.validates_presence( [:method_name] )
	end


	### Return a human-readable representation of the object suitable for 
	### display in a text interface.
	def to_s
		return "%s%s [%s] @%s%s" % [
			self.method_name,
			self.arguments || '',
			self.queue_name,
			self.created_at,
			self.locked_at ? ' (in progress)' : '',
		]
	end


end # class LAIKA::GroundControl::Job

