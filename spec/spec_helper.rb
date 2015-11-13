require "logstash/devutils/rspec/spec_helper"
require 'logstash/inputs/twitter'
require 'twitter'

class MockClient
  def filter(options)
    loop { yield }
  end

  alias_method :sample, :filter
end

def run_input_with(input, queue)
  t = Thread.new(input, queue) do |_input, _queue|
    _input.run(_queue)
  end
  sleep 0.1
  t.kill
end
