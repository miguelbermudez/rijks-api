# config.ru (run with rackup)
#require './api'
#run RijksApi


require 'rubygems'
require 'sinatra'
set :environment, ENV['RACK_ENV'].to_sym
disable :run, :reload

#require './api.rb'

run Sinatra::Application