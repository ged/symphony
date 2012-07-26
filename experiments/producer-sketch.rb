#!/usr/bin/env ruby

require 'laika'

$stderr.sync = true

# A little sketch of how GroundControl's API should work.

LAIKA.require_features( :ldap, :groundcontrol )
LAIKA.load_config( '../../etc/config.yml' )

queue = LAIKA::GroundControl.default_queue

loop do
	$stderr.print "Adding gatherer tasks for hosts:"
	LAIKA::Netgroup[:workstations].hosts.each do |host|
		$stderr.print " #{host.cn.first}"
		job = LAIKA::GroundControl::Job.new( method_name: 'gather', arguments: host.fqdn )
		queue.add( job )
	end
	$stderr.puts "done, sleeping for a while..."

	sleep( 5 )
end

