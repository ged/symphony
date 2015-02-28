# -*- encoding: utf-8 -*-
# stub: symphony 0.9.0.pre20150227170321 ruby lib

Gem::Specification.new do |s|
  s.name = "symphony"
  s.version = "0.9.0.pre20150227170321"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Michael Granger", "Mahlon E. Smith"]
  s.date = "2015-02-28"
  s.description = "Symphony is a subscription-based asynchronous job system. It\nallows you to define jobs that watch for lightweight events from a\ndistributed-messaging AMQP broker, and do work based on their payload.\n\nIt includes several executables under bin/:\n\nsymphony::\n  A daemon which manages startup and shutdown of one or more Workers\n  running Tasks as they are published from a queue.\n\nsymphony-task::\n  A wrapper that runs a single task, useful for testing, or if you don't\n  require the process management that the symphony daemon provides."
  s.email = ["ged@FaerieMUD.org", "mahlon@martini.nu"]
  s.executables = ["symphony", "symphony-task"]
  s.extra_rdoc_files = ["History.rdoc", "Manifest.txt", "README.rdoc", "UPGRADING.md", "USAGE.rdoc", "History.rdoc", "README.rdoc", "USAGE.rdoc"]
  s.files = [".simplecov", "ChangeLog", "History.rdoc", "Manifest.txt", "README.rdoc", "Rakefile", "UPGRADING.md", "USAGE.rdoc", "bin/symphony", "bin/symphony-task", "etc/config.yml.example", "lib/symphony.rb", "lib/symphony/daemon.rb", "lib/symphony/metrics.rb", "lib/symphony/mixins.rb", "lib/symphony/queue.rb", "lib/symphony/routing.rb", "lib/symphony/signal_handling.rb", "lib/symphony/statistics.rb", "lib/symphony/task.rb", "lib/symphony/task_group.rb", "lib/symphony/task_group/longlived.rb", "lib/symphony/task_group/oneshot.rb", "lib/symphony/tasks/auditor.rb", "lib/symphony/tasks/failure_logger.rb", "lib/symphony/tasks/oneshot_simulator.rb", "lib/symphony/tasks/simulator.rb", "spec/helpers.rb", "spec/symphony/daemon_spec.rb", "spec/symphony/mixins_spec.rb", "spec/symphony/queue_spec.rb", "spec/symphony/routing_spec.rb", "spec/symphony/statistics_spec.rb", "spec/symphony/task_group/longlived_spec.rb", "spec/symphony/task_group/oneshot_spec.rb", "spec/symphony/task_group_spec.rb", "spec/symphony/task_spec.rb", "spec/symphony_spec.rb"]
  s.homepage = "http://bitbucket.org/ged/symphony"
  s.licenses = ["BSD"]
  s.rdoc_options = ["-f", "fivefish", "-t", "Symphony"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0")
  s.rubygems_version = "2.4.5"
  s.signing_key = "/Volumes/Keys/ged-private_gem_key.pem"
  s.summary = "Symphony is a subscription-based asynchronous job system"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<configurability>, ["~> 2.2"])
      s.add_runtime_dependency(%q<loggability>, ["~> 0.10"])
      s.add_runtime_dependency(%q<pluggability>, ["~> 0.4"])
      s.add_runtime_dependency(%q<bunny>, ["~> 1.5"])
      s.add_runtime_dependency(%q<sysexits>, ["~> 1.1"])
      s.add_runtime_dependency(%q<yajl-ruby>, ["~> 1.2"])
      s.add_runtime_dependency(%q<msgpack>, ["~> 0.5"])
      s.add_runtime_dependency(%q<metriks>, ["~> 0.9"])
      s.add_runtime_dependency(%q<rusage>, ["~> 0.2"])
      s.add_development_dependency(%q<hoe-mercurial>, ["~> 1.4"])
      s.add_development_dependency(%q<hoe-deveiate>, ["~> 0.6"])
      s.add_development_dependency(%q<hoe-highline>, ["~> 0.2"])
      s.add_development_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_development_dependency(%q<rspec>, ["~> 3.0"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.8"])
      s.add_development_dependency(%q<timecop>, ["~> 0.7"])
      s.add_development_dependency(%q<hoe>, ["~> 3.13"])
    else
      s.add_dependency(%q<configurability>, ["~> 2.2"])
      s.add_dependency(%q<loggability>, ["~> 0.10"])
      s.add_dependency(%q<pluggability>, ["~> 0.4"])
      s.add_dependency(%q<bunny>, ["~> 1.5"])
      s.add_dependency(%q<sysexits>, ["~> 1.1"])
      s.add_dependency(%q<yajl-ruby>, ["~> 1.2"])
      s.add_dependency(%q<msgpack>, ["~> 0.5"])
      s.add_dependency(%q<metriks>, ["~> 0.9"])
      s.add_dependency(%q<rusage>, ["~> 0.2"])
      s.add_dependency(%q<hoe-mercurial>, ["~> 1.4"])
      s.add_dependency(%q<hoe-deveiate>, ["~> 0.6"])
      s.add_dependency(%q<hoe-highline>, ["~> 0.2"])
      s.add_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_dependency(%q<rspec>, ["~> 3.0"])
      s.add_dependency(%q<simplecov>, ["~> 0.8"])
      s.add_dependency(%q<timecop>, ["~> 0.7"])
      s.add_dependency(%q<hoe>, ["~> 3.13"])
    end
  else
    s.add_dependency(%q<configurability>, ["~> 2.2"])
    s.add_dependency(%q<loggability>, ["~> 0.10"])
    s.add_dependency(%q<pluggability>, ["~> 0.4"])
    s.add_dependency(%q<bunny>, ["~> 1.5"])
    s.add_dependency(%q<sysexits>, ["~> 1.1"])
    s.add_dependency(%q<yajl-ruby>, ["~> 1.2"])
    s.add_dependency(%q<msgpack>, ["~> 0.5"])
    s.add_dependency(%q<metriks>, ["~> 0.9"])
    s.add_dependency(%q<rusage>, ["~> 0.2"])
    s.add_dependency(%q<hoe-mercurial>, ["~> 1.4"])
    s.add_dependency(%q<hoe-deveiate>, ["~> 0.6"])
    s.add_dependency(%q<hoe-highline>, ["~> 0.2"])
    s.add_dependency(%q<rdoc>, ["~> 4.0"])
    s.add_dependency(%q<rspec>, ["~> 3.0"])
    s.add_dependency(%q<simplecov>, ["~> 0.8"])
    s.add_dependency(%q<timecop>, ["~> 0.7"])
    s.add_dependency(%q<hoe>, ["~> 3.13"])
  end
end
