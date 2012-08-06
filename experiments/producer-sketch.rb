#!/usr/bin/env ruby

require 'etc'
require 'laika'

$stderr.sync = true

# A little sketch of how GroundControl's API should work.

LAIKA.require_features( :ldap, :groundcontrol )
LAIKA.load_config( ARGV.shift )

queue = LAIKA::GroundControl.default_queue
Sequel.extension( :pretty_table )

if ARGV.empty?

	loop do
		$stderr.print "Adding gatherer tasks for hosts:"
		LAIKA::Netgroup[:workstations].hosts.each do |host|
			$stderr.print " #{host.cn.first}"
			queue.add( 'pinger', hostname: host.fqdn, port: 'ssh' )
		end
		$stderr.puts

		started = Time.now
		$stderr.puts "Pausing job injection..."
		queue.wait_for_notification( poll: true, timeout: 5 ) do |*|
			count = queue.dataset.filter( locked_at: nil ).count
			$stderr.puts "%d tasks remain..." % [ count ]
			throw :stop if count < 1
		end

		$stderr.puts "Pausing for 5s before queuing more jobs."
	end

else

	# queue.add( 'pinger', ARGV.shift )

	# queue.add( 'ssh', 
	#            hostname: ARGV.shift,
	#            command:  ARGV.shift )

	recipient = "%s@laika.com" % [ Etc.getlogin ]
	queue.add( 'sshscript',
	           hostname:   ARGV.shift,
	           template:   ARGV.shift,
	           key:        File.expand_path('~/.ssh/id_rsa'),
	           attributes: { recipient: recipient } )
end

