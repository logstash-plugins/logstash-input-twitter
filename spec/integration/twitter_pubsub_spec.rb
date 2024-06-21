__END__
require_relative "../spec_helper"

describe LogStash::Inputs::Twitter do
  describe "full integration", :integration => true do

    before(:all) do
      @_abort_on_exception = Thread.abort_on_exception
      Thread.abort_on_exception = true
    end

    after(:all) do
      Thread.abort_on_exception = @_abort_on_exception
    end

    let(:pub_config) do
      {
        :consumer_key => ENV['PUB_TWITTER_CONSUMER_KEY'],
        :consumer_secret => ENV['PUB_TWITTER_CONSUMER_SECRET'],
        :access_token => ENV['PUB_TWITTER_OAUTH_TOKEN'],
        :access_token_secret => ENV['PUB_TWITTER_OAUTH_TOKEN_SECRET']
      }
    end

    let(:publisher) do
      Twitter::REST::Client.new(pub_config)
    end

    let(:plugin_cfg) do
      {
        'consumer_key' => ENV['TWITTER_CONSUMER_KEY'],
        'consumer_secret' => ENV['TWITTER_CONSUMER_SECRET'],
        'oauth_token' => ENV['TWITTER_OAUTH_TOKEN'],
        'oauth_token_secret' => ENV['TWITTER_OAUTH_TOKEN_SECRET'],
        'keywords' => ['logstash_ci_publish'],
        'full_tweet' => full_tweets
      }
    end

    let(:plugin) { described_class.new(plugin_cfg) }
    let(:queue)  { Array.new }
    let(:tweet_count) { 1 }
    let(:full_tweets) { false }

    before do
      Thread.new do
        plugin.register
        plugin.run(queue)
      end
    end

    context "partial tweet pub sub" do
      it "receives an event from the twitter stream" do
        RSpec::Sequencing.run_after(1, "update tweet status") do
          twt = "logstash_ci_publish partial tweet test #{Time.now} #{SecureRandom.hex(6)} $AAPL #lscipub @logstash https://www.elastic.co/downloads/logstash"
          publisher.update_with_media(twt, File.open(LogstashTwitterInput.fixture("small_smile.png")))
        end.then_after(10, "stop plugin") do
          plugin.stop
          true
        end.value
        expect(queue.size).to eq(tweet_count)
        expect(plugin.event_generation_error_count).to eq(0)
        event = queue.first
        expect { event.to_json }.not_to raise_error
        expect(event.get("hashtags").size).to be > 0
        expect(event.get("symbols").size).to be > 0
        expect(event.get("user_mentions").size).to be > 0
        expect(event.get("urls").size).to be > 0
      end
    end

    context "full tweet pub sub" do
      let(:full_tweets) { true }

      it "receives an event from the twitter stream" do
        RSpec::Sequencing.run_after(1, "update tweet status") do
          twt = "logstash_ci_publish full tweet test #{Time.now} #{SecureRandom.hex(6)} $AAPL #lscipub @logstash https://www.elastic.co/downloads/logstash"
          publisher.update_with_media(twt, File.open(LogstashTwitterInput.fixture("small_smile.png")))
        end.then_after(10, "stop plugin") do
          plugin.stop
          true
        end.value
        expect(queue.count).to eq(tweet_count)
        expect(plugin.event_generation_error_count).to eq(0)
        event = queue.first
        expect { LogStash::Json.dump(event.to_hash) }.not_to raise_error
        expect(event.get("[entities][hashtags]").size).to be > 0
        expect(event.get("[entities][symbols]").size).to be > 0
        expect(event.get("[entities][user_mentions]").size).to be > 0
        expect(event.get("[entities][urls]").size).to be > 0
        expect(event.get("[extended_tweet][entities][media]").size).to be > 0
      end
    end
  end
end
