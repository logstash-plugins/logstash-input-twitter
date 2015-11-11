require_relative "../spec_helper"

describe LogStash::Inputs::Twitter do

  let(:mock_client) { MockClient.new }

  before :each do
    allow(Twitter::Streaming::Client).to receive(:new).and_return(mock_client)
  end

  let(:input) { LogStash::Plugin.lookup("input", "twitter").new(config) }

  let(:config) do
    {
      'consumer_key' => 'foo',
      'consumer_secret' => 'foo',
      'oauth_token' => 'foo',
      'oauth_token_secret' => 'foo',
      'keywords' => ['foo', 'bar']
    }
  end

  context "when told to shutdown" do
    it_behaves_like "an interruptible input plugin"
  end

  context "registration" do

    it "not raise error" do
      expect {input.register}.to_not raise_error
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
        expect {input.register}.to raise_error(LogStash::ConfigurationError)
      end
    end
  end

  context "stream filter" do

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
      input.register
    end

    let(:options) { input.twitter_options }

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

     describe "run" do

       let(:queue) { Queue.new }

       before(:each) do
         input.register
       end

       let(:options) do
         {:track=>"foo", :locations=>"1234,2343", :language=>"en,fr", :follow=>"1234,4321"}
       end

       it "using the filter endpoint" do
         expect(mock_client).to receive(:filter).with(options).once
         Thread.new do
           input.run(queue)
         end
         sleep 0.1
       end

       context "#sample" do
         let(:config) do
           {
             'consumer_key' => 'foo',
             'consumer_secret' => 'foo',
             'oauth_token' => 'foo',
             'oauth_token_secret' => 'foo',
             'use_samples' => true
           }
         end

         it "using the sample endpoint" do
           expect(mock_client).to receive(:sample).once
           Thread.new do
             input.run(queue)
           end
           sleep 0.1
         end

       end
     end

  end

end
