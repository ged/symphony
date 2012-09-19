#!/usr/bin/env rake

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires hoe (gem install hoe)"
end

Hoe.plugin :mercurial
Hoe.plugin :signing
Hoe.plugin :laika

Hoe.plugins.delete :rubyforge
Hoe.plugins.delete :gemcutter

hoespec = Hoe.spec 'laika-groundcontrol' do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files = FileList[ '*.rdoc' ]
	self.spec_extras[:rdoc_options] = ['-f', 'fivefish', '-t', 'LAIKA GroundControl']

	self.developer 'Michael Granger', 'mgranger@laika.com'

	self.dependency 'laika-base', '~> 3.2'
	self.dependency 'laika-db', '~> 0.9'
	self.dependency 'pluginfactory', '~> 1.0'
	self.dependency 'inversion', '~> 0.11'
	self.dependency 'net-ssh', '~> 2.5'
	self.dependency 'net-sftp', '~> 2.0'
	self.dependency 'sysexits', '~> 1.1'

	self.dependency 'rspec', '~> 2.11', :developer

	self.require_ruby_version( '>=1.9.3' )
	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.rdoc_locations << "havnor:/usr/local/laika/www/public/#{remote_rdoc_dir}"
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

