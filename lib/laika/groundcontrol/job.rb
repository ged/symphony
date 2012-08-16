#!/usr/bin/env ruby

require 'laika' unless defined?( LAIKA )
require 'laika/groundcontrol' unless defined?( LAIKA::GroundControl )
require 'laika/groundcontrol/queue'
require 'laika/model'


# A Job is a request for the execution of a Task with a particular set of arguments. They
# are managed via a Queue, and run with a Worker launched by bin/gcworkerd.
#
#   require 'laika'
#
#   LAIKA.require_features( :groundcontrol )
#   LAIKA.load_config( 'config.yml' )
#
#   # You can instantiate a Job directly...
#   job = LAIKA::GroundControl::Job.create( task_name: 'pinger',
#                                           queue_name: '_default_',
#                                           task_options: {
#                                               hostname: 'gw.bennett.laika.com'
#                                           } )
#   job.save
#
#   # But Queue objects provide a somewhat less-verbose mechanism for doing so:
#   queue = LAIKA::GroundControl.default_queue
#   queue.add( 'pinger', hostname: 'gw.bennett.laika.com' )
#
class LAIKA::GroundControl::Job < LAIKA::Model( :groundcontrol__jobs )
	extend LAIKA::MethodUtilities

	plugin :validation_helpers
	plugin :schema
	plugin :timestamps


	# Define the schema. If you're changing this, you should also be defining
	# a migration.
	set_schema do
		primary_key :id

		column :queue_name, :text, null: false,
		       default: LAIKA::GroundControl::Queue::DEFAULT_NAME
		column :task_name, :text, null: false
		column :task_options, :text

		column :created_at, :timestamp
		column :locked_at, :timestamp
	end


	#
	# :section: Dataset Methods
	# These methods return a Sequel::Dataset for a subset of Jobs. See
	# the docs for Sequel::Dataset for usage details.
	#

	##
	# :singleton-method: unlocked
	# Dataset method for all unlocked jobs.
	def_dataset_method( :unlocked ) { filter(locked_at: nil) }

	##
	# :singleton-method: for_queue
	# :call-seq:
	#   Job.for_queue( queue_name )
	#
	# Fetch a dataset for jobs in the queue named 'queuename'
	def_dataset_method( :for_queue ) {|queue_name| filter(queue_name: queue_name) }

	##
	# :singleton-method: locked
	# Dataset method for all locked jobs.
	def_dataset_method( :locked ) { filter(:locked_at) }
	singleton_method_alias :in_progress, :locked


	# Dont allow writes to the 'locked_at' columns via mass updates
	set_restricted_columns :locked_at


	# :section:

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


	### Fetch the LAIKA::GroundControl::Task subclass associated with this job.
	def task_class
		return LAIKA::GroundControl::Task.get_subclass( self.task_name )
	end


	### Fetch the unserialized options data as a Hash.
	def task_options
		return Marshal.load( self[:task_options] )
	end


	### Set the task options to +newopts+, which should be a Hash of task options.
	def task_options=( newopts )
		self[:task_options] = Marshal.dump( newopts )
	end


	### Return a human-readable representation of the object suitable for
	### display in a text interface.
	def to_s
		return "%s [%s] @%s%s" % [
			self.task_name ? self.task_name.capitalize : '(unknown)',
			self.queue_name,
			self.created_at,
			self.locked_at ? ' (in progress)' : '',
		]
	end


	#########
	protected
	#########

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
	### sent after a job is fetched and locked prove to be problematic.
	def after_save
		self.log.debug "Sending a notification for the %s queue" % [ self.queue_name ]

		# :TODO: Sequel doesn't quote this, so the queue_name can't be a keyword like 'default'.
		#        Send a patch to Jeremy to fix this.
		self.db.notify( self.queue_name )
	end

end # class LAIKA::GroundControl::Job

