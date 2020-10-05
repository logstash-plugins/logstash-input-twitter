# encoding: utf-8
require 'twitter/streaming/response'

module LogStash
  module Inputs
    class TwitterPatches

      def self.patch
        verify_version
        patch_json
        patch_http_request
      end

      private

      def self.verify_version
        raise("Incompatible Twitter gem version and the LogStash::Json.load") unless ::Twitter::Version.to_s == "6.2.0"
      end

      def self.patch_json
        ::Twitter::Streaming::Response.module_eval do
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
      end

      def self.patch_http_request
        ::HTTP::Request.class_eval do
          def headline
            request_uri =
                if using_proxy? #&& !uri.https?
                  uri.omit(:fragment)
                else
                  uri.request_uri
                end

            "#{verb.to_s.upcase} #{request_uri} HTTP/#{version}"
          end
        end
      end

    end
  end
end
