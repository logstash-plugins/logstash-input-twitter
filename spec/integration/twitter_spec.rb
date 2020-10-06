require_relative "../spec_helper"

describe LogStash::Inputs::Twitter do

  let(:events) do
    input(config) do |_, queue|
      event_count.times.collect { queue.pop }
    end
  end

  let(:event_count) { 3 }

  let(:event) { events.first }

  describe "#receive [integration]", :integration => true do

    context "keyword search" do
      let(:config) do
        <<-CONFIG
       input {
         twitter {
            consumer_key => '#{ENV['TWITTER_CONSUMER_KEY']}'
            consumer_secret => '#{ENV['TWITTER_CONSUMER_SECRET']}'
            oauth_token => '#{ENV['TWITTER_OAUTH_TOKEN']}'
            oauth_token_secret => '#{ENV['TWITTER_OAUTH_TOKEN_SECRET']}'
            keywords => [ 'London', 'Politics', 'New York', 'Samsung', 'Apple' ]
            full_tweet => true
        }
      }
        CONFIG
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

      it "receive a list of events from the twitter stream" do
        expect(events.count).to eq(3)

        event.tap { |event| puts "sample event: #{event.to_hash}" } if $VERBOSE

        expect(event.get("hashtags")).to be_truthy
        expect(event.get("symbols")).to be_truthy
        expect(event.get("user_mentions")).to be_truthy
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
            proxy_port => 3128
        }
      }
        CONFIG
      end

      it "receive a list of events from the twitter stream" do
        expect(events.count).to eq(3)
        event.tap { |event| puts "sample event (using proxy): #{event.to_hash}" } if $VERBOSE
      end
    end
  end

end