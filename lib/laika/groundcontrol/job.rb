#!/usr/bin/env ruby

require 'laika' unless defined?( LAIKA )
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )
require 'laika/model'


# A Job is an instruction for running a Task with a particular set of arguments. They
# are put into a Queue, and run with bin/gcworkerd.
class LAIKA::GroundControl::Job < LAIKA::Model( :groundcontrol__jobs )
	extend LAIKA::MethodUtilities

	plugin :validation_helpers
	plugin :schema
	plugin :timestamps
	plugin :serialization


	# Define the schema. If you're changing this, you should also be defining
	# a migration.
	set_schema do
		primary_key :id

		column :queue_name, :text, :null => false, :default => 'default'
		column :task_name, :text, :null => false
		column :task_arguments, :text

		column :created_at, :timestamp
		column :locked_at, :timestamp
	end

	# Pre-define some datasets
	def_dataset_method( :unlocked ) { filter(locked_at: nil) }
	def_dataset_method( :for_queue ) {|queue_name| filter(:queue_name => queue_name) }
	def_dataset_method( :locked ) { filter(:locked_at) }
	singleton_method_alias :in_progress, :locked
	

	# Dont allow writes to the 'locked_at' columns via mass updates
	set_restricted_columns :locked_at

	# Serialize the job's arguments as JSON
	serialize_attributes :marshal, :task_arguments


	### Default the queue name if it's not set on instantiation.
	def initialize( * ) # :notnew:
		super
		self.queue_name ||= LAIKA::GroundControl::Queue::DEFAULT_NAME
	end


	### Copy constructor -- clear the id and locked_at columns.
	def initialize_copy( original )
		self.id = nil
		self.locked_at = nil
	end


	######
	public
	######

	### Lock the job. Raises an exception if this method is called outside of a transaction.
	def lock
		raise LAIKA::GroundControl::LockingError, "jobs must be locked in a transaction" unless
			self.db.in_transaction?
		raise LAIKA::GroundControl::LockingError, "job is already locked" if
			self.locked_at

		self.locked_at = Time.now
		self.save
	end


	### Validation callback.
	def validate
		super

		self.validate_required_fields
		self.validate_queue_name
	end


	### Ensure required fields are defined.
	def validate_required_fields
		self.validates_presence( [:task_name] )
	end


	### Ensure the queue name is a valid SQL identifier
	def validate_queue_name
		self.validates_format( /^\w+$/, :queue_name, message: "must be a valid SQL identifier" )
	end


	### Sequel Hook -- send a notification whenever there's a modification
	### :TODO: This may need to be moved to #after_create instead if notifications
	###        sent after a job is fetched and locked is problematic.
	def after_save
		self.log.debug "Sending a notification for the %s queue" % [ self.queue_name ]

		# :TODO: Sequel doesn't quote this, so the queue_name can't be a keyword like 'default'.
		#        Send a patch to Jeremy to fix this.
		self.db.notify( self.queue_name )
	end


	### Return a human-readable representation of the object suitable for 
	### display in a text interface.
	def to_s
		return "%s%s [%s] @%s%s" % [
			self.task_name ? self.task_name.capitalize : '(unknown)',
			self.task_arguments ? "(#{self.task_arguments.inspect})" : '',
			self.queue_name,
			self.created_at,
			self.locked_at ? ' (in progress)' : '',
		]
	end


end # class LAIKA::GroundControl::Job

