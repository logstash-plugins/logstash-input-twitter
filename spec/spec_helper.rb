require 'logstash/devutils/rspec/spec_helper'
require 'logstash/inputs/twitter'
require 'twitter'
require 'rspec_sequencing'

module LogstashTwitterInput
  class MockClient
    def filter(options)
      loop { yield }
    end
    alias_method :sample, :filter
  end

  def self.run_input_with(input, queue)
    t = Thread.new(input, queue) do |_input, _queue|
      _input.run(_queue)
    end
    sleep 0.1
    t.kill
  end

  def self.fixture_path
    File.expand_path('../fixtures', __FILE__)
  end

  def self.fixture(file)
    File.new(self.fixture_path + '/' + file)
  end
end