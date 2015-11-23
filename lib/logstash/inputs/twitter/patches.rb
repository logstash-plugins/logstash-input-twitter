# encoding: utf-8
require 'twitter/streaming/connection'
require 'twitter/streaming/response'
require 'twitter/streaming/message_parser'

module LogStash
  module Inputs
    class TwitterPatches

      def self.patch
        verify_version
        patch_json
        patch_connection_stream
        patch_request
      end

      private

      def self.verify_version
        raise("Incompatible Twitter gem version and the LogStash::Json.load") unless ::Twitter::Version.to_s == "5.15.0"
      end

      def self.patch_connection_stream
        ::Twitter::Streaming::Connection.class_eval do
          def stream(request, response)
            socket = @tcp_socket_class.new(Resolv.getaddress(request.socket_host), request.socket_port)
            socket = ssl_stream(socket) if !request.using_proxy?

            request.stream(socket)
            while body = socket.readpartial(1024) # rubocop:disable AssignmentInCondition
              response << body
            end
          end

          def ssl_stream(client)
            client_context = OpenSSL::SSL::SSLContext.new
            ssl_client     = @ssl_socket_class.new(client, client_context)
            ssl_client.connect
          end

          def normalized_port(scheme)
            HTTP::URI.port_mapping[scheme]
          end
        end
      end

      def self.patch_request
        ::Twitter::Streaming::Client.class_eval do
          def request(method, uri, params)
            before_request.call
            headers = ::Twitter::Headers.new(self, method, uri, params).request_headers
            request = ::HTTP::Request.new(method, uri + '?' + to_url_params(params), headers, proxy)
            response = ::Twitter::Streaming::Response.new do |data|
              if item = ::Twitter::Streaming::MessageParser.parse(data) # rubocop:disable AssignmentInCondition
                yield(item)
              end
            end
            @connection.stream(request, response)
          end
        end
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

    end
  end
end
