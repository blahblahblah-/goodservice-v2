require 'clockwork'
require './config/boot'
require './config/environment'

module Clockwork
  handler do |job|
    puts "Running #{job}"
  end

  every(30.seconds, 'retrieve feeds') {
    ServiceChangeAnalyzer.preload_current_routings
    FeedRetriever.retrieve_all_feeds
  }
end