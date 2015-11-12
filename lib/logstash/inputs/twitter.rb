# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "logstash/timestamp"
require "logstash/util"
require "logstash/json"
require "stud/interval"

# Read events from the twitter streaming api.
class LogStash::Inputs::Twitter < LogStash::Inputs::Base

  attr_reader :filter_options

  config_name "twitter"

  # Your twitter app's consumer key
  #
  # Don't know what this is? You need to create an "application"
  # on twitter, see this url: <https://dev.twitter.com/apps/new>
  config :consumer_key, :validate => :string, :required => true

  # Your twitter app's consumer secret
  #
  # If you don't have one of these, you can create one by
  # registering a new application with twitter:
  # <https://dev.twitter.com/apps/new>
  config :consumer_secret, :validate => :password, :required => true

  # Your oauth token.
  #
  # To get this, login to twitter with whatever account you want,
  # then visit <https://dev.twitter.com/apps>
  #
  # Click on your app (used with the consumer_key and consumer_secret settings)
  # Then at the bottom of the page, click 'Create my access token' which
  # will create an oauth token and secret bound to your account and that
  # application.
  config :oauth_token, :validate => :string, :required => true

  # Your oauth token secret.
  #
  # To get this, login to twitter with whatever account you want,
  # then visit <https://dev.twitter.com/apps>
  #
  # Click on your app (used with the consumer_key and consumer_secret settings)
  # Then at the bottom of the page, click 'Create my access token' which
  # will create an oauth token and secret bound to your account and that
  # application.
  config :oauth_token_secret, :validate => :password, :required => true

  # Any keywords to track in the twitter stream
  config :keywords, :validate => :array

  # Record full tweet object as given to us by the Twitter stream api.
  config :full_tweet, :validate => :boolean, :default => false

  # A comma separated list of user IDs, indicating the users to
  # return statuses for in the stream.
  # See https://dev.twitter.com/streaming/overview/request-parameters#follow
  # for more details.
  config :follows, :validate => :array

  # A comma-separated list of longitude,latitude pairs specifying a set
  # of bounding boxes to filter Tweets by.
  # See https://dev.twitter.com/streaming/overview/request-parameters#locations
  # for more details
  config :locations, :validate => :string

  # A list of BCP 47 language identifiers corresponding to any of the languages listed
  # on Twitter’s advanced search page will only return Tweets that have been detected 
  # as being written in the specified languages
  config :languages, :validate => :array

  # Returns a small random sample of all public statuses. The Tweets returned
  # by the default access level are the same, so if two different clients connect
  # to this endpoint, they will see the same Tweets. Default => false
  config :use_samples, :validate => :boolean, :default => false

  # Let's you ingore the retweeets comming out of the twitter api. Default => false
  config :ignore_retweets, :validate => :boolean, :default => false

  def register
    require "twitter"

    if !@use_samples && ( @keywords.nil? && @follows.nil? && @locations.nil? )
      raise LogStash::ConfigurationError.new("At least one parameter (follows, locations or keywords) must be specified.")
    end

    # monkey patch twitter gem to ignore json parsing error.
    # at the same time, use our own json parser
    # this has been tested with a specific gem version, raise if not the same
    raise("Incompatible Twitter gem version and the LogStash::Json.load") unless Twitter::Version.to_s == "5.14.0"

    Twitter::Streaming::Response.module_eval do
      def on_body(data)
        @tokenizer.extract(data).each do |line|
          next if line.empty?
          begin
            @block.call(LogStash::Json.load(line, :symbolize_keys => true))
          rescue LogStash::Json::ParserError
            # silently ignore json parsing errors
          end
        end
      end
    end

    @rest_client     = Twitter::REST::Client.new       { |c|  configure(c) }
    @stream_client   = Twitter::Streaming::Client.new  { |c|  configure(c) }
    @twitter_options = build_options
  end

  def run(queue)
    @logger.info("Starting twitter tracking", twitter_options)
    begin
      if @use_samples
        @stream_client.sample do |tweet|
          return if stop?
          tweet_processor(queue, tweet)
        end
      else
        @stream_client.filter(twitter_options) do |tweet|
          return if stop?
          tweet_processor(queue, tweet)
        end
      end
    rescue Twitter::Error::TooManyRequests => e
      @logger.warn("Twitter too many requests error, sleeping for #{e.rate_limit.reset_in}s")
      Stud.stoppable_sleep(e.rate_limit.reset_in) { stop? }
      retry
    rescue => e
      @logger.warn("Twitter client error", :message => e.message, :exception => e, :backtrace => e.backtrace, :options => @filter_options)
      retry
    end
  end # def run

  def stop
    @stream_client = nil
  end

  def twitter_options
    @twitter_options.delete(:level) # This is added by the logger when you pass the full hash as params
    @twitter_options
  end

  def set_stream_client(client)
    @stream_client = client
  end

  private

  def tweet_processor(queue, tweet)
    if tweet.is_a?(Twitter::Tweet)
      return if ignore?(tweet)
      event = from_tweet(tweet)
      decorate(event)
      queue << event
    end
  end

  def ignore?(tweet)
    @ignore_retweets && tweet.retweet?
  end

  def from_tweet(tweet)
    @logger.debug? && @logger.debug("Got tweet", :user => tweet.user.screen_name, :text => tweet.text)
    if @full_tweet
      event = LogStash::Event.new(LogStash::Util.stringify_symbols(tweet.to_hash))
      event.timestamp = LogStash::Timestamp.new(tweet.created_at)
    else

      attributes = {
        LogStash::Event::TIMESTAMP => LogStash::Timestamp.new(tweet.created_at),
        "message" => tweet.full_text,
        "user" => tweet.user.screen_name,
        "client" => tweet.source,
        "retweeted" => tweet.retweeted?,
        "source" => "http://twitter.com/#{tweet.user.screen_name}/status/#{tweet.id}"
      }

      attributes["hashtags"] = tweet.hashtags
      attributes["symbols"]  = tweet.symbols
      attributes["user_mentions"]  = tweet.user_mentions

      event = LogStash::Event.new(attributes)
      event["in-reply-to"] = tweet.in_reply_to_status_id if tweet.reply?
      unless tweet.urls.empty?
        event["urls"] = tweet.urls.map(&:expanded_url).map(&:to_s)
      end
    end

    # Work around bugs in JrJackson. The standard serializer won't work till we upgrade
    event["in-reply-to"] = nil if event["in-reply-to"].is_a?(Twitter::NullObject)

    event
  end

  def configure(c)
    c.consumer_key = @consumer_key
    c.consumer_secret = @consumer_secret.value
    c.access_token = @oauth_token
    c.access_token_secret = @oauth_token_secret.value
  end

  def build_options
    build_options = {}
    build_options[:track]     = @keywords.join(",")  if @keywords && @keywords.length > 0
    build_options[:locations] = @locations           if @locations && @locations.length > 0
    build_options[:language]  = @languages.join(",") if @languages && @languages.length > 0

    if @follows && @follows.length > 0
      build_options[:follow]    = @follows.map do |username|
        (  username.to_i == 0 ? find_userid(username) : username )
      end.join(",")
    end
    build_options
  end

  def find_userid(username)
    @rest_client.user(:user => username)
  end

end # class LogStash::Inputs::Twitter
