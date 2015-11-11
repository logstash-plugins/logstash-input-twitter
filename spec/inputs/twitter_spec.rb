require_relative "../spec_helper"

describe LogStash::Inputs::Twitter do
  context "when told to shutdown" do
    before :each do
      allow(Twitter::Streaming::Client).to receive(:new).and_return(MockClient.new)
    end

    let(:config) do
      {
        'consumer_key' => 'foo',
        'consumer_secret' => 'foo',
        'oauth_token' => 'foo',
        'oauth_token_secret' => 'foo',
        'keywords' => ['foo', 'bar']
      }
    end

    context "registration" do
      it "not raise error" do
        input = LogStash::Plugin.lookup("input", "twitter").new(config)
        expect {input.register}.to_not raise_error
      end
    end


    it_behaves_like "an interruptible input plugin"
  end
end
