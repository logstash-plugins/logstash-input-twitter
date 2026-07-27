require 'logstash/devutils/rspec/spec_helper'
require 'rspec_sequencing'

require 'logstash/inputs/twitter'

creds_file_path = File.expand_path('spec/integration_credentials.rb')
if File.exist?(creds_file_path)
  load creds_file_path
  RSpec.configure do |config|
    # enable integrations only when credentials are loaded
    exclusions = config.exclusion_filter
    exclusions.delete(:integration)
    config.exclusion_filter = exclusions
  end
end

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
    t.kill unless t.join(1.5) # due CI
  end

  def self.fixture_path
    File.expand_path('../fixtures', __FILE__)
  end

  def self.fixture(file)
    File.new(self.fixture_path + '/' + file)
  end
end