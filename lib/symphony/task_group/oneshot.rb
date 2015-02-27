# -*- ruby -*-
#encoding: utf-8

require 'symphony/task_group' unless defined?( Symphony::TaskGroup )


# A task group for the 'oneshot' work model.
class Symphony::TaskGroup::Oneshot < Symphony::TaskGroup

	### If the number of workers is not at the maximum, start some.
	def adjust_workers
		return nil if self.throttled?

		missing_workers = []
		missing_count = self.max_workers - self.workers.size
		missing_count.times do
			missing_workers << self.start_worker
		end

		return missing_workers.empty? ? nil : missing_workers
	end

end # class Symphony::TaskGroup::Oneshot


