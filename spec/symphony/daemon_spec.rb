# -*- ruby -*-
#encoding: utf-8
# vim: set noet nosta sw=4 ts=4 :


require_relative '../helpers'

require 'symphony/daemon'
require 'symphony/task'

class Test1Task < Symphony::Task
	subscribe_to '#'
end
class Test2Task < Symphony::Task
	subscribe_to '#'
end
class Test3Task < Symphony::Task
	subscribe_to '#'
end


describe Symphony::Daemon do

	before( :all ) do
		@pids = ( 200..65534 ).cycle
	end

	before( :each ) do
		allow( Process ).to receive( :fork ).and_yield.and_return( @pids.next )
		allow( Process ).to receive( :setpgid )
		allow( Process ).to receive( :kill )
		Symphony.configure( tasks: ['test', 'test'] )

		dummy_session = Symphony::SpecHelpers::DummySession.new
		allow( Bunny::Session ).to receive( :new ).and_return( dummy_session )
	end


	let!( :daemon ) { described_class.new }


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

	it "exits gracefully on one SIGINT" do
		Symphony.tasks.clear
		thr = Thread.new { daemon.run_tasks }
		sleep 0.1 until daemon.running? || !thr.alive?

		expect {
			daemon.simulate_signal( :INT )
			thr.join( 2 )
		}.to change { daemon.running? }.from( true ).to( false )
	end

	it "exits gracefully on one SIGQUIT" do
		Symphony.tasks.clear
		thr = Thread.new { daemon.run_tasks }
		sleep 0.1 until daemon.running? || !thr.alive?

		expect {
			daemon.simulate_signal( :QUIT )
			thr.join( 2 )
		}.to change { daemon.running? }.from( true ).to( false )
	end

	it "re-reads its configuration on a SIGHUP" do
		Symphony.tasks.clear
		thr = Thread.new { daemon.run_tasks }
		sleep 0.1 until daemon.running? || !thr.alive?

		config = double( Configurability::Config )
		expect( Symphony ).to receive( :config ).at_least( :once ).and_return( config )
		expect( config ).to receive( :reload )

		daemon.simulate_signal( :HUP )
		daemon.stop
		thr.join( 2 )
	end

	it "adjusts its tasks when its config is reloaded" do
		config = Configurability.default_config
		config.symphony.tasks = [ 'test1', 'test2' ]
		# config.logging.__default__ = 'debug'
		config.install

		allow( Symphony::Task ).to receive( :exit )
		allow( Process ).to receive( :kill ) do |sig, pid|
			status = instance_double( Process::Status, :success? => true )
			daemon.task_pids[ pid ].on_child_exit( pid, status )
			daemon.task_pids.delete( pid )
		end

		begin
			thr = Thread.new { daemon.run_tasks }
			sleep 0.1 until daemon.running? || !thr.alive?

			daemon.task_groups.each do |task_class, task_group|
				case task_class
				when Test1Task
					expect( task_group ).to receive( :restart_workers ) do
						daemon.task_pids.clear
					end
				when Test2Task
					expect( task_group ).to receive( :stop_workers ) do
						daemon.task_pids.clear
					end
				end
			end

			expect( config ).to receive( :reload ) do
				config.symphony.tasks = [ 'test1', 'test3' ]
				config.install
			end

			expect {
				daemon.reload_config
			}.to change { daemon.task_groups }

		ensure
			daemon.stop
			thr.join( 2 )
		end
	end

end

