# -*- ruby -*-
#encoding: utf-8

require 'bunny'
require 'yajl'

# A spike to play around with a flattened-out task

session = Bunny.new(  )