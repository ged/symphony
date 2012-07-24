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


describe LAIKA::Groundcontrol do

	it_should_behave_like "a Feature-registration module"

	it "is well-tested" do
		fail "it isn't"
	end

end

