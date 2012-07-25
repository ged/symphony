#!/usr/bin/env rspec

BEGIN {
	require 'pathname'
	basedir = Pathname( __FILE__ ).dirname.parent.parent

	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'

require 'spec/lib/groundcontrolhelpers'
require 'spec/lib/groundcontrolconstants'

require 'laika'
require 'laika/groundcontrol'
require 'laika/featurebehavior'


describe LAIKA::GroundControl do

	it_should_behave_like "a Feature-registration module"


	it "registers the job model class for requiring" do
		LAIKA::DB.registered_models.should include( 'laika/groundcontrol/job' )
	end

end

