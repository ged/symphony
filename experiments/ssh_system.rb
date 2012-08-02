#!/usr/bin/env ruby

$stderr.sync = true

# Try using Ruby 1.9's spawn instead of Open3 to avoid the thread and potential deadlock

def open_connection( host )
	cmd = ["/usr/bin/ssh", "-e", "none", "-T", "-x", "-o", "CheckHostIP=no",
		"-o", "KbdInteractiveAuthentication=no", "-o", "StrictHostKeyChecking=no", "-p", "22",
		"-l", "root", host ]

	parent_reader, child_writer = IO.pipe
	child_reader, parent_writer = IO.pipe
	null = File.open( '/dev/null', 'w+' )

	pid = spawn( *cmd, :out => child_writer, :in => child_reader, :err => null, :close_others => true )
	child_writer.close
	child_reader.close

	$stderr.puts "Yielding back to the run block."
	@output = yield( parent_reader, parent_writer )
	$stderr.puts "  run block done."

	pid, status = Process.waitpid2( pid )
	null.close

	return status
end


host = ARGV.shift
command = ARGV.shift

rv = open_connection( host ) do |reader, writer|
	$stderr.puts "Writing command #{command}..."
	writer.puts( command )
	$stderr.puts "  closing child's writer."
	writer.close
	$stderr.puts "  reading from child."
	puts reader.read
end


$stderr.puts "exited with %d" % [ rv.exitstatus ]

