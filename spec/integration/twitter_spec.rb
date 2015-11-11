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

    context "folling a user stream" do
      let(:config) do
        <<-CONFIG
       input {
         twitter {
            consumer_key => '#{ENV['TWITTER_CONSUMER_KEY']}'
            consumer_secret => '#{ENV['TWITTER_CONSUMER_SECRET']}'
            oauth_token => '#{ENV['TWITTER_OAUTH_TOKEN']}'
            oauth_token_secret => '#{ENV['TWITTER_OAUTH_TOKEN_SECRET']}'
            follows => '#{ENV['TWITTER_FOLLOW']}'
        }
      }
        CONFIG
      end

      let(:events) do
        input(config) do |pipeline, queue|
          1.times.collect { queue.pop }
        end
      end

      it "receive a list of events from the twitter stream" do
        expect(events.count).to eq(1)
      end
    end

  end
end
