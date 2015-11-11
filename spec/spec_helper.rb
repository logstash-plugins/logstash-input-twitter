require "logstash/devutils/rspec/spec_helper"
require 'logstash/inputs/twitter'
require 'twitter'

class MockClient
  def filter(options)
    loop { yield }
  end

  alias_method :sample, :filter
end
