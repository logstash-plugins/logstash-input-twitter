require "logstash/devutils/rspec/spec_helper"
require 'logstash/inputs/twitter'
require 'twitter'

class MockClient
  def filter(options)
    loop { yield }
  end
end

describe LogStash::Inputs::Twitter do
  context "when told to shutdown" do
    before :each do
      allow(Twitter::Streaming::Client).to receive(:new).and_return(MockClient.new)
    end

    it_behaves_like "an interruptible input plugin" do
      let(:config) do
        {
          'consumer_key' => 'foo',
          'consumer_secret' => 'foo',
          'oauth_token' => 'foo',
          'oauth_token_secret' => 'foo',
          'keywords' => ['foo', 'bar']
        }
      end
    end
  end
end
