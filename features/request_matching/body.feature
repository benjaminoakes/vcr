Feature: Matching on Body

  Use the `:body` request matcher to match requests on the request body.

  Background:
    Given a previously recorded cassette file "cassettes/example.yml" with:
      """
      --- 
      - !ruby/struct:VCR::HTTPInteraction 
        request: !ruby/struct:VCR::Request 
          method: :post
          uri: http://example.net:80/some/long/path
          body: body1
          headers: 
        response: !ruby/struct:VCR::Response 
          status: !ruby/struct:VCR::ResponseStatus 
            code: 200
            message: OK
          headers: 
            content-length: 
            - "14"
          body: body1 response
          http_version: "1.1"
      - !ruby/struct:VCR::HTTPInteraction 
        request: !ruby/struct:VCR::Request 
          method: :post
          uri: http://example.net:80/some/long/path
          body: body2
          headers: 
        response: !ruby/struct:VCR::Response 
          status: !ruby/struct:VCR::ResponseStatus 
            code: 200
            message: OK
          headers: 
            content-length: 
            - "14"
          body: body2 response
          http_version: "1.1"
      """

  Scenario Outline: Replay interaction that matches the body
    And a file named "body_matching.rb" with:
      """ruby
      include_http_adapter_for("<http_lib>")

      require 'vcr'

      VCR.configure do |c|
        c.stub_with <stub_with>
        c.cassette_library_dir = 'cassettes'
      end

      VCR.use_cassette('example', :match_requests_on => [:body]) do
        puts "Response for body2: " + response_body_for(:put, "http://example.com/", "body2")
      end

      VCR.use_cassette('example', :match_requests_on => [:body]) do
        puts "Response for body1: " + response_body_for(:put, "http://example.com/", "body1")
      end
      """
    When I run `ruby body_matching.rb`
    Then it should pass with:
      """
      Response for body2: body2 response
      Response for body1: body1 response
      """

    Examples:
      | stub_with  | http_lib        |
      | :fakeweb   | net/http        |
      | :webmock   | net/http        |
      | :webmock   | httpclient      |
      | :webmock   | patron          |
      | :webmock   | curb            |
      | :webmock   | em-http-request |
      | :webmock   | typhoeus        |
      | :typhoeus  | typhoeus        |
      | :excon     | excon           |

