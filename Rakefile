#!/usr/bin/env rake

require 'pathname'

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires hoe (gem install hoe)"
end


BASEDIR         = Pathname( __FILE__ ).dirname.relative_path_from( Pathname.pwd )

LIBDIR          = BASEDIR + 'lib'
SYMPHONY_LIBDIR = LIBDIR + 'symphony'

GEMSPEC         = BASEDIR + 'symphony.gemspec'
EXPRESSION_RL   = SYMPHONY_LIBDIR + 'intervalexpression.rl'
EXPRESSION_RB   = SYMPHONY_LIBDIR + 'intervalexpression.rb'


Hoe.plugin :mercurial
Hoe.plugin :signing
Hoe.plugin :deveiate
Hoe.plugin :bundler

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'symphony' do |spec|
	spec.readme_file = 'README.rdoc'
	spec.history_file = 'History.rdoc'
	spec.extra_rdoc_files = FileList[ '*.rdoc' ]
	spec.spec_extras[:rdoc_options] = ['-f', 'fivefish', '-t', 'Symphony']
	spec.spec_extras[:required_rubygems_version] = '>= 2.0.3'
	spec.license 'BSD'

	spec.developer 'Michael Granger', 'ged@FaerieMUD.org'
	spec.developer 'Mahlon E. Smith', 'mahlon@martini.nu'

	spec.dependency 'loggability', '~> 0.10'
	spec.dependency 'pluggability', '~> 0.4'
	spec.dependency 'bunny', '~> 1.1'
	spec.dependency 'sysexits', '~> 1.1'
	spec.dependency 'yajl-ruby', '~> 1.2'
	spec.dependency 'msgpack', '~> 0.5'
	spec.dependency 'metriks', '~> 0.9'
	spec.dependency 'rusage', '~> 0.2'

	spec.dependency 'rspec', '~> 3.0', :developer
	spec.dependency 'net-ssh', '~> 2.8', :developer
	spec.dependency 'net-sftp', '~> 2.1', :developer
	spec.dependency 'simplecov', '~> 0.8', :developer

	spec.require_ruby_version( '>=2.0.0' )
	spec.hg_sign_tags = true if spec.respond_to?( :hg_sign_tags= )
	spec.quality_check_whitelist.include( EXPRESSION_RB.to_s ) if
		spec.respond_to?( :quality_check_whitelist )

	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

# Run the tests before checking in
task 'hg:precheckin' => [ :check_history, :check_manifest, :spec ]


# Rebuild the ChangeLog immediately before release
task :prerelease => 'ChangeLog'
CLOBBER.include( 'ChangeLog' )


desc "Build a coverage report"
task :coverage do
	ENV["COVERAGE"] = 'yes'
	Rake::Task[:spec].invoke
end


# Generate the expression parser with Ragel
file EXPRESSION_RL
file EXPRESSION_RB
task EXPRESSION_RB => EXPRESSION_RL do |task|
	 sh 'ragel', '-R', '-T1', '-Ls', task.prerequisites.first
end
task :spec => EXPRESSION_RB


# Generate a .gemspec file for integration with systems that read it
task :gemspec => GEMSPEC
file GEMSPEC => __FILE__ do |task|
	spec = $hoespec.spec
	spec.files.delete( '.gemtest' )
	spec.version = "#{spec.version}.pre#{Time.now.strftime("%Y%m%d%H%M%S")}"
	File.open( task.name, 'w' ) do |fh|
		fh.write( spec.to_ruby )
	end
end
task :default => :gemspec

