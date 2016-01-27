#!/usr/bin/env rake

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires hoe (gem install hoe)"
end

GEMSPEC = 'symphony.gemspec'


Hoe.plugin :mercurial
Hoe.plugin :signing
Hoe.plugin :deveiate

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

	spec.dependency 'configurability', '~> 2.2'
	spec.dependency 'loggability', '~> 0.10'
	spec.dependency 'pluggability', '~> 0.4'
	spec.dependency 'bunny', '~> 2.0'
	spec.dependency 'sysexits', '~> 1.1'
	spec.dependency 'yajl-ruby', '~> 1.2'
	spec.dependency 'msgpack', '~> 0.5'
	spec.dependency 'metriks', '~> 0.9'
	spec.dependency 'rusage', '~> 0.2'

	spec.dependency 'rspec', '~> 3.0', :developer
	spec.dependency 'simplecov', '~> 0.8', :developer
	spec.dependency 'timecop', '~> 0.7', :developer

	spec.require_ruby_version( '>=2.0.0' )
	spec.hg_sign_tags = true if spec.respond_to?( :hg_sign_tags= )

	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

# Fix some Hoe retardedness
hoespec.spec.files.delete( '.gemtest' )
ENV['VERSION'] ||= hoespec.spec.version.to_s

# Run the tests before checking in
task 'hg:precheckin' => [ :check_history, :check_manifest, :gemspec, :spec ]

# Rebuild the ChangeLog immediately before release
task :prerelease => 'ChangeLog'
CLOBBER.include( 'ChangeLog' )

desc "Build a coverage report"
task :coverage do
	ENV["COVERAGE"] = 'yes'
	Rake::Task[:spec].invoke
end


task :gemspec => GEMSPEC
file GEMSPEC => hoespec.spec.files do |task|
	spec = $hoespec.spec
	spec.version = "#{spec.version.bump}.0.pre#{Time.now.strftime("%Y%m%d%H%M%S")}"
	File.open( task.name, 'w' ) do |fh|
		fh.write( spec.to_ruby )
	end
end

task :default => :gemspec

CLOBBER.include( GEMSPEC.to_s )

