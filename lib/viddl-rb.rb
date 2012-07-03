#!/usr/bin/env ruby
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'helper')

require "rubygems"
require "nokogiri"
require "mechanize"
require "cgi"
require "open-uri"
require "open3"
require "download-helper.rb"
require "plugin-helper.rb"

Dir[File.join(File.dirname(__FILE__),"../plugins/*.rb")].each { |p| load p }


module ViddlRb

  def self.get_urls(url)

    PluginBase.registered_plugins.each do |plugin|
      if plugin.matches_provider?(url)
        begin
          #we'll end up with an array of hashes with they keys :url and :name 
          download_queue = plugin.get_urls_and_filenames(url)
        rescue StandardError => e
          puts "Error while running the #{plugin.name.inspect} plugin. Maybe it has to be updated? Error: #{e.message}."  
          return nil
        end
        return download_queue.map { |url_name| url_name[:url] }
      end
    end
  end
end
