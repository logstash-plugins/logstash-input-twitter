# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "logstash/timestamp"
require "logstash/util"
require "logstash/json"

# Read events from the twitter streaming api.
class LogStash::Inputs::Twitter < LogStash::Inputs::Base

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

  # NB:  Per the Twitter API spec, the keywords, locations, and follows
  # parameters are or'ed together, rather than and'ed (which might have
  # been a reasonable expectation).
  # See https://dev.twitter.com/streaming/overview/request-parameters for
  # more details.

  # Any keywords to track in the twitter stream
  config :keywords, :validate => :array, :default => []

  # Any locations to track in the twitter stream
  # Per the Twitter spec, each value is of the form
  # "lng1,lat1,lng2,lat2" to define a bounding box.
  config :locations, :validate => :array, :default => []

  # Any users to follow in the twitter stream
  config :follows, :validate => :array, :default => []

  # Record full tweet object as given to us by the Twitter stream api.
  config :full_tweet, :validate => :boolean, :default => false

  public
  def register
    require "twitter"

    # monkey patch twitter gem to ignore json parsing error.
    # at the same time, use our own json parser
    # this has been tested with a specific gem version, raise if not the same
    raise("Incompatible Twitter gem version and the LogStash::Json.load") unless Twitter::Version.to_s == "5.12.0"

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

    @client = Twitter::Streaming::Client.new do |c|
      c.consumer_key = @consumer_key
      c.consumer_secret = @consumer_secret.value
      c.access_token = @oauth_token
      c.access_token_secret = @oauth_token_secret.value
    end

    @rest = Twitter::REST::Client.new do |c|
      c.consumer_key = @consumer_key
      c.consumer_secret = @consumer_secret.value
      c.access_token = @oauth_token
      c.access_token_secret = @oauth_token_secret.value
    end
  end

  public
  def run(queue)
    @logger.info("Starting twitter tracking", :keywords => @keywords)
    begin
      options = {}
      if @keywords.length > 0
        options[:track] = @keywords.join(",")
      end
      if @locations.length > 0
        options[:locations] = @locations.join(",")
      end
      if @follows.length > 0
        ids = @follows.map { |user| get_user_id( user) }.compact
        ids =  ids.keep_if { |v| not v.nil? }.join(',')
        if ids != ''
          options[:follow] =  ids
        end
      end

      if options.empty?
        @logger.debug? && @logger.debug("Listening on the firehose")
        @client.firehose() { |tweet| process_a_tweet(tweet, queue) }
      else
        @logger.debug? && @logger.debug("Filtering for tweets", :options => options)
        @client.filter(options) { |tweet| process_a_tweet(tweet, queue) }
      end

    rescue LogStash::ShutdownSignal
      return
    rescue Twitter::Error::TooManyRequests => e
      @logger.warn("Twitter too many requests error, sleeping for #{e.rate_limit.reset_in}s")
      sleep(e.rate_limit.reset_in)
      retry
    rescue => e
      @logger.warn("Twitter client error", :message => e.message, :exception => e, :backtrace => e.backtrace)
      retry
    end
  end # def run

  protected
  def process_a_tweet(tweet, queue)
    if tweet.is_a?(Twitter::Tweet)
      @logger.debug? && @logger.debug("Got tweet", :user => tweet.user.screen_name, :text => tweet.text)
      if @full_tweet
        event = LogStash::Event.new(LogStash::Util.stringify_symbols(tweet.to_hash))
        event.timestamp = LogStash::Timestamp.new(tweet.created_at)
      else
        event = LogStash::Event.new(
          LogStash::Event::TIMESTAMP => LogStash::Timestamp.new(tweet.created_at),
          "message" => tweet.full_text,
          "user" => tweet.user.screen_name,
          "client" => tweet.source,
          "retweeted" => tweet.retweeted?,
          "source" => "http://twitter.com/#{tweet.user.screen_name}/status/#{tweet.id}"
        )
        event["in-reply-to"] = tweet.in_reply_to_status_id if tweet.reply?
        unless tweet.urls.empty?
          event["urls"] = tweet.urls.map(&:expanded_url).map(&:to_s)
        end
      end

      decorate(event)
      queue << event
    end
  end  # def process_a_tweet

  # Use a one-by-one call to user() rather than users() since the latter
  # does not deal gracefully with an unknown user amongst valid users
  protected
  def get_user_id( name)
    if name.is_a?(Integer)
      return name
    end
    begin
        usr = @rest.user(name)
        return usr.id
    rescue Twitter::Error::NotFound => e
      @logger.warn("Unknown twitter user", :user => name)
    end
    return nil
  end

end # class LogStash::Inputs::Twitter
