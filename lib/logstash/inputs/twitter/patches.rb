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
        # NOTE: we're also known to work with twitter gem version 7.0 which uses http 4.x
        raise("Incompatible HTTP gem version: #{HTTP::VERSION}") if HTTP::VERSION >= '5.0' || HTTP::VERSION < '3.0'
        # after a major upgrade, unless CI is running integration specs, please run integration specs manually
      end

      def self.patch_json
        ::Twitter::Streaming::Response.module_eval do
          unless method_defined? :on_body
            raise "::Twitter::Streaming::Response#on_body not defined!" # patch bellow needs a review
          end
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
        # NOTE: we might decide to drop the patch at some point, for now proxies such as squid
        # are opinionated about having full URIs in the http head-line (having only /path fails
        # with 400 Bad Request in Squid 4.10).
        ::HTTP::Request.class_eval do
          unless method_defined? :headline
            raise "::HTTP::Request#headline not defined!" # patch bellow needs a review
          end
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
