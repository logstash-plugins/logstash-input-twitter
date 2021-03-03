require_relative "../spec_helper"
require "logstash/devutils/rspec/shared_examples"

describe LogStash::Inputs::Twitter do

  let(:config) do
    {
      'consumer_key' => 'foo',
      'consumer_secret' => 'foo',
      'oauth_token' => 'foo',
      'oauth_token_secret' => 'foo',
      'keywords' => ['foo', 'bar']
    }
  end

  let(:plugin) { LogStash::Inputs::Twitter.new(config) }

  let(:queue) { Queue.new }

  describe "registration" do

    it "not raise error" do
      expect { plugin.register }.to_not raise_error
    end

    context "with no required configuration fields" do
      let(:config) do
        {
          'consumer_key' => 'foo',
          'consumer_secret' => 'foo',
          'oauth_token' => 'foo',
          'oauth_token_secret' => 'foo',
        }
      end

      it "raise an error if no required fields are specified" do
        expect { plugin.register }.to raise_error(LogStash::ConfigurationError)
      end
    end

    context "with follows" do

      let(:user) { Twitter::User.new(id: 11111111) }

      let(:config) do
        {
            'consumer_key' => 'foo',
            'consumer_secret' => 'foo',
            'oauth_token' => 'foo',
            'oauth_token_secret' => 'foo',
            'keywords' => ['bar'],
            'follows' => ['12345678', 'theborg']
        }
      end

      it "looks up user name" do
        allow_any_instance_of(Twitter::REST::Client).
            to receive(:user).with(screen_name: 'theborg').and_return user
        plugin.register
        expect(plugin.send(:build_options)).to include(follow: '12345678,11111111')
      end
    end
  end

  describe "when told to shutdown" do
    before(:each) do
      allow(Twitter::Streaming::Client).to receive(:new).and_return(LogstashTwitterInput::MockClient.new)
    end
    it_behaves_like "an interruptible input plugin"
  end

  describe "fetching from sample" do

    let(:input) { LogStash::Inputs::Twitter.new(config) }

    let(:config) do
      {
        'consumer_key' => 'foo',
        'consumer_secret' => 'foo',
        'oauth_token' => 'foo',
        'oauth_token_secret' => 'foo',
        'use_samples' => true
      }
    end

    let(:stream_client)       { double("stream-client") }

    before(:each) do
      input.register
      input.set_stream_client(stream_client)
    end

    it "uses the sample endpoint" do
      expect(stream_client).to receive(:sample).once
      LogstashTwitterInput.run_input_with(input, queue)
    end

  end

  describe "stream filter" do

    describe "options parsing" do

      let(:plugin) { LogStash::Inputs::Twitter.new(config) }

      let(:config) do
        {
          'consumer_key' => 'foo',
          'consumer_secret' => 'foo',
          'oauth_token' => 'foo',
          'oauth_token_secret' => 'foo',
          'keywords' => ['foo'],
          'languages' => ['en', 'fr'],
          'locations' => "1234,2343",
          'follows' => [ '1234', '4321' ]
        }
      end

      before(:each) do
        plugin.register
      end

      let(:options) { plugin.twitter_options }

      it "include the track filter in options" do
        expect(options).to include(:track=>"foo")
      end

      it "include the language filter in options" do
        expect(options).to include(:language=>"en,fr")
      end

      it "include the locations filter in options" do
        expect(options).to include(:locations=>"1234,2343")
      end

      it "include the follows filter in options" do
        expect(options).to include(:follow=>"1234,4321")
      end
    end

    describe "run" do

      let(:input) { LogStash::Inputs::Twitter.new(config) }

      let(:stream_client)       { double("stream-client") }

      let(:options) do
        {:track=>"foo,bar"}
      end

      before(:each) do
        input.register
        input.set_stream_client(stream_client)
      end

      it "using the filter endpoint" do
        expect(stream_client).to receive(:filter).with(options).once
        LogstashTwitterInput.run_input_with(input, queue)
      end

      context "when not filtering retweets" do

        let(:tweet) { Twitter::Tweet.new(id: 1) }

        let(:config) do
          {
            'consumer_key' => 'foo',
            'consumer_secret' => 'foo',
            'oauth_token' => 'foo',
            'oauth_token_secret' => 'foo',
            'keywords' => ['foo'],
            'languages' => ['en', 'fr'],
            'locations' => "1234,2343",
            'ignore_retweets' => false
          }
        end

        it "not exclude retweets" do
          allow(tweet).to receive(:retweet?).and_return(true)
          expect(input).to receive(:from_tweet).with(tweet)
          expect(stream_client).to receive(:filter).at_least(:once).and_yield(tweet)
          expect(queue).to receive(:<<)
          LogstashTwitterInput.run_input_with(input, queue)
        end
      end

      context "when filtering retweets" do

        let(:tweet) { Twitter::Tweet.new(id: 1) }

        let(:config) do
          {
            'consumer_key' => 'foo',
            'consumer_secret' => 'foo',
            'oauth_token' => 'foo',
            'oauth_token_secret' => 'foo',
            'keywords' => ['foo'],
            'languages' => ['en', 'fr'],
            'locations' => "1234,2343",
            'ignore_retweets' => true
          }
        end

        it "exclude retweets" do
          allow(tweet).to receive(:retweet?).and_return(true)
          expect(stream_client).to receive(:filter).at_least(:once).and_yield(tweet)
          expect(queue).not_to receive(:<<)
          LogstashTwitterInput.run_input_with(input, queue)
        end
      end

    end

    describe "proxy" do

      before(:each) do
        plugin.register
      end

      let(:config) do
        super().merge( 'use_proxy' => true, 'proxy_address' => '127.0.0.1', 'proxy_port' => 12345 )
      end

      let(:proxy_socket) { double('proxy-socket') }

      it "sends full URI requests" do
        allow_any_instance_of(Twitter::Streaming::Connection).
            to receive(:new_tcp_socket).with('127.0.0.1', 12345).and_return(proxy_socket)
        header_line = 'POST https://stream.twitter.com/1.1/statuses/filter.json?track=foo%2Cbar HTTP/1.1'
        expect(proxy_socket).to receive(:write).with(/^#{Regexp.escape(header_line)}/).
            and_return(3000) # let the stack assume all content sent was consumed
        # NOTE: this is just bogus - we're really just testing the HTTP header line ...
        expect(proxy_socket).to receive(:readpartial).and_return nil
        plugin.send(:do_run, queue)
      end
    end
  end
end
