#!/usr/bin/env ruby

%w[shellwords erb yaml rubygems fileutils nokogiri json cgi time pp].each do |filename|
  require filename
end

require 'util.rb'
require 'settings.rb'
require 'porterstemmer.rb'
require 'knowledge.rb'
require 'string.rb'
require 'helpbuilder.rb'
require 'helppdfbuilder.rb'


