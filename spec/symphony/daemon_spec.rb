# -*- ruby -*-
#encoding: utf-8

require_relative '../helpers'

require 'symphony/daemon'

class TestTask < Symphony::Task

	# Don't ever really try to handle messages.
	def start_handling_messages
	end

end


describe Symphony::Daemon do

	before( :each ) do
		allow( Process ).to receive( :fork ).and_yield
		allow( Process ).to receive( :setpgid )
		Symphony::Daemon.configure( tasks: ['test', 'test'] )
	end


	let( :daemon ) { described_class.new }


	it "can report what version it is" do
		expect(
			described_class.version_string
		).to match( /#{described_class} #{Symphony::VERSION}/i )
	end

	it "can include its build number in its version string" do
		expect(
			described_class.version_string( true )
		).to match( /\(build \p{Xdigit}+\)/i )
	end

	it "loads a task class for each configured task" do
		expect( daemon.tasks.size ).to eq( 2 )
		expect( daemon.tasks ).to include( TestTask )
	end

	it "forks a child for each task" do
		expect( Process ).to receive( :fork ).twice.and_yield
		expect( TestTask ).to receive( :after_fork ).twice
		expect( TestTask ).to receive( :run ).and_return( 118, 119 ) # pids

		daemon.simulate_signal( :TERM )

		status = double( Process::Status, :success? => true )
		expect( Process ).to receive( :waitpid2 ).
			with( -1, Process::WNOHANG|Process::WUNTRACED ).
			and_return( [118, status], [119, status], nil )

		daemon.run_tasks
	end

	it "exits gracefully on one SIGINT" do
		daemon.tasks.clear
		thr = Thread.new { daemon.run_tasks }
		sleep 0.1 until daemon.running? || !thr.alive?

		expect {
			daemon.simulate_signal( :INT )
			thr.join( 2 )
		}.to change { daemon.running? }.from( true ).to( false )
	end

	it "exits gracefully on one SIGQUIT" do
		daemon.tasks.clear
		thr = Thread.new { daemon.run_tasks }
		sleep 0.1 until daemon.running? || !thr.alive?

		expect {
			daemon.simulate_signal( :QUIT )
			thr.join( 2 )
		}.to change { daemon.running? }.from( true ).to( false )
	end

end

