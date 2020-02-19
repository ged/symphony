# -*- encoding: utf-8 -*-
# stub: symphony 0.13.0.pre.20200219135214 ruby lib

Gem::Specification.new do |s|
  s.name = "symphony".freeze
  s.version = "0.13.0.pre.20200219135214"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze, "Mahlon E. Smith".freeze]
  s.date = "2020-02-19"
  s.description = "Symphony is a subscription-based asynchronous job system. It\nallows you to define jobs that watch for lightweight events from a\ndistributed-messaging AMQP broker, and do work based on their payload.".freeze
  s.email = ["ged@faeriemud.org".freeze, "mahlon@martini.nu".freeze]
  s.executables = ["symphony".freeze, "symphony-task".freeze]
  s.files = [".simplecov".freeze, "ChangeLog".freeze, "History.rdoc".freeze, "Manifest.txt".freeze, "README.md".freeze, "Rakefile".freeze, "UPGRADING.md".freeze, "USAGE.rdoc".freeze, "bin/symphony".freeze, "bin/symphony-task".freeze, "etc/config.yml.example".freeze, "lib/symphony.rb".freeze, "lib/symphony/daemon.rb".freeze, "lib/symphony/metrics.rb".freeze, "lib/symphony/mixins.rb".freeze, "lib/symphony/queue.rb".freeze, "lib/symphony/routing.rb".freeze, "lib/symphony/signal_handling.rb".freeze, "lib/symphony/statistics.rb".freeze, "lib/symphony/task.rb".freeze, "lib/symphony/task_group.rb".freeze, "lib/symphony/task_group/longlived.rb".freeze, "lib/symphony/task_group/oneshot.rb".freeze, "lib/symphony/tasks/auditor.rb".freeze, "lib/symphony/tasks/failure_logger.rb".freeze, "lib/symphony/tasks/oneshot_simulator.rb".freeze, "lib/symphony/tasks/simulator.rb".freeze, "spec/helpers.rb".freeze, "spec/symphony/daemon_spec.rb".freeze, "spec/symphony/mixins_spec.rb".freeze, "spec/symphony/queue_spec.rb".freeze, "spec/symphony/routing_spec.rb".freeze, "spec/symphony/statistics_spec.rb".freeze, "spec/symphony/task_group/longlived_spec.rb".freeze, "spec/symphony/task_group/oneshot_spec.rb".freeze, "spec/symphony/task_group_spec.rb".freeze, "spec/symphony/task_spec.rb".freeze, "spec/symphony_spec.rb".freeze]
  s.homepage = "https://hg.sr.ht/~ged/symphony".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.rubygems_version = "3.0.6".freeze
  s.summary = "Symphony is a subscription-based asynchronous job system.".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<configurability>.freeze, [">= 3.1", "<= 4.99"])
      s.add_runtime_dependency(%q<loggability>.freeze, ["~> 0.11"])
      s.add_runtime_dependency(%q<pluggability>.freeze, ["~> 0.4"])
      s.add_runtime_dependency(%q<bunny>.freeze, ["~> 2.0"])
      s.add_runtime_dependency(%q<sysexits>.freeze, ["~> 1.1"])
      s.add_runtime_dependency(%q<yajl-ruby>.freeze, ["~> 1.3"])
      s.add_runtime_dependency(%q<msgpack>.freeze, ["~> 1.0"])
      s.add_runtime_dependency(%q<metriks>.freeze, ["~> 0.9"])
      s.add_runtime_dependency(%q<rusage>.freeze, ["~> 0.2"])
      s.add_development_dependency(%q<rake-deveiate>.freeze, ["~> 0.10"])
      s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.8"])
      s.add_development_dependency(%q<timecop>.freeze, ["~> 0.8"])
    else
      s.add_dependency(%q<configurability>.freeze, [">= 3.1", "<= 4.99"])
      s.add_dependency(%q<loggability>.freeze, ["~> 0.11"])
      s.add_dependency(%q<pluggability>.freeze, ["~> 0.4"])
      s.add_dependency(%q<bunny>.freeze, ["~> 2.0"])
      s.add_dependency(%q<sysexits>.freeze, ["~> 1.1"])
      s.add_dependency(%q<yajl-ruby>.freeze, ["~> 1.3"])
      s.add_dependency(%q<msgpack>.freeze, ["~> 1.0"])
      s.add_dependency(%q<metriks>.freeze, ["~> 0.9"])
      s.add_dependency(%q<rusage>.freeze, ["~> 0.2"])
      s.add_dependency(%q<rake-deveiate>.freeze, ["~> 0.10"])
      s.add_dependency(%q<simplecov>.freeze, ["~> 0.8"])
      s.add_dependency(%q<timecop>.freeze, ["~> 0.8"])
    end
  else
    s.add_dependency(%q<configurability>.freeze, [">= 3.1", "<= 4.99"])
    s.add_dependency(%q<loggability>.freeze, ["~> 0.11"])
    s.add_dependency(%q<pluggability>.freeze, ["~> 0.4"])
    s.add_dependency(%q<bunny>.freeze, ["~> 2.0"])
    s.add_dependency(%q<sysexits>.freeze, ["~> 1.1"])
    s.add_dependency(%q<yajl-ruby>.freeze, ["~> 1.3"])
    s.add_dependency(%q<msgpack>.freeze, ["~> 1.0"])
    s.add_dependency(%q<metriks>.freeze, ["~> 0.9"])
    s.add_dependency(%q<rusage>.freeze, ["~> 0.2"])
    s.add_dependency(%q<rake-deveiate>.freeze, ["~> 0.10"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.8"])
    s.add_dependency(%q<timecop>.freeze, ["~> 0.8"])
  end
end
