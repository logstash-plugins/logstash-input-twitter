require_relative "../spec_helper"

describe LogStash::Inputs::Twitter do

  describe "#receive", :integration => true do

    context "keyword search" do
      let(:config) do
        <<-CONFIG
       input {
         twitter {
            consumer_key => '#{ENV['TWITTER_CONSUMER_KEY']}'
            consumer_secret => '#{ENV['TWITTER_CONSUMER_SECRET']}'
            oauth_token => '#{ENV['TWITTER_OAUTH_TOKEN']}'
            oauth_token_secret => '#{ENV['TWITTER_OAUTH_TOKEN_SECRET']}'
            keywords => [ 'Barcelona' ]
            full_tweet => true
        }
      }
        CONFIG
      end

      let(:events) do
        input(config) do |pipeline, queue|
          3.times.collect { queue.pop }
        end
      end

      it "receive a list of events from the twitter stream" do
        expect(events.count).to eq(3)
      end
    end

    context "pulling from sample" do
      let(:config) do
        <<-CONFIG
       input {
         twitter {
            consumer_key => '#{ENV['TWITTER_CONSUMER_KEY']}'
            consumer_secret => '#{ENV['TWITTER_CONSUMER_SECRET']}'
            oauth_token => '#{ENV['TWITTER_OAUTH_TOKEN']}'
            oauth_token_secret => '#{ENV['TWITTER_OAUTH_TOKEN_SECRET']}'
            use_samples => true
        }
      }
        CONFIG
      end

      let(:events) do
        input(config) do |pipeline, queue|
          3.times.collect { queue.pop }
        end
      end

      let(:event) { events.first }

      it "receive a list of events from the twitter stream" do
        expect(events.count).to eq(3)
      end

      it "contains the hashtags" do
        expect(event["hashtags"]).to be_truthy
      end

      it "contains the symbols" do
        expect(event["symbols"]).to be_truthy
      end

      it "contains the user_mentions" do
        expect(event["user_mentions"]).to be_truthy
      end

    end

    context "when using a proxy" do
      let(:config) do
        <<-CONFIG
       input {
         twitter {
            consumer_key => '#{ENV['TWITTER_CONSUMER_KEY']}'
            consumer_secret => '#{ENV['TWITTER_CONSUMER_SECRET']}'
            keywords => [ "London", "Barcelona" ]
            oauth_token => '#{ENV['TWITTER_OAUTH_TOKEN']}'
            oauth_token_secret => '#{ENV['TWITTER_OAUTH_TOKEN_SECRET']}'
            full_tweet => true
            use_proxy => true
            proxy_address => '127.0.0.1'
            proxy_port => 8123
        }
      }
        CONFIG
      end

      let(:events) do
        input(config) do |pipeline, queue|
          3.times.collect { queue.pop }
        end
      end

      it "receive a list of events from the twitter stream" do
        expect(events.count).to eq(3)
      end
    end
  end

end