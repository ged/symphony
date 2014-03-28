#!/usr/bin/env rspec

require_relative 'helpers'

require 'rspec'
require 'symphony'


describe Symphony do

	before( :each ) do
		ENV.delete( 'SYMPHONY_CONFIG' )
	end


	it "will load a default config file if none is specified" do
		config_object = double( "Configurability::Config object" )
		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Configurability::Config ).to receive( :load ).
			with( described_class::DEFAULT_CONFIG_FILE, {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		described_class.load_config
	end


	it "will load a config file given in an environment variable if none is specified" do
		ENV['SYMPHONY_CONFIG'] = '/usr/local/etc/config.yml'

		config_object = double( "Configurability::Config object" )
		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Configurability::Config ).to receive( :load ).
			with( '/usr/local/etc/config.yml', {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		described_class.load_config
	end


	it "will load a config file and install it if one is given" do
		config_object = double( "Configurability::Config object" )
		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Configurability::Config ).to receive( :load ).
			with( 'a/configfile.yml', {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		described_class.load_config( 'a/configfile.yml' )
	end


	it "will override default values when loading the config if they're given" do
		config_object = double( "Configurability::Config object" )
		expect( Configurability ).to_not receive( :gather_defaults )
		expect( Configurability::Config ).to receive( :load ).
			with( 'a/different/configfile.yml', {database: {dbname: 'test'}} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		described_class.load_config( 'a/different/configfile.yml', database: {dbname: 'test'} )
	end

end

