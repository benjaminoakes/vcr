Feature: Matching on Headers

  Use the `:headers` request matcher to match requests on the request headers.

  Background:
    Given a previously recorded cassette file "cassettes/example.yml" with:
      """
      --- 
      - !ruby/struct:VCR::HTTPInteraction 
        request: !ruby/struct:VCR::Request 
          method: :post
          uri: http://example.net:80/some/long/path
          body: 
          headers: 
            x-user-id: 
            - "1"
        response: !ruby/struct:VCR::Response 
          status: !ruby/struct:VCR::ResponseStatus 
            code: 200
            message: OK
          headers: 
            content-length: 
            - "15"
          body: user 1 response
          http_version: "1.1"
      - !ruby/struct:VCR::HTTPInteraction 
        request: !ruby/struct:VCR::Request 
          method: :post
          uri: http://example.net:80/some/long/path
          body: 
          headers: 
            x-user-id: 
            - "2"
        response: !ruby/struct:VCR::Response 
          status: !ruby/struct:VCR::ResponseStatus 
            code: 200
            message: OK
          headers: 
            content-length: 
            - "15"
          body: user 2 response
          http_version: "1.1"
      """

  Scenario Outline: Replay interaction that matches the headers
    And a file named "header_matching.rb" with:
      """ruby
      include_http_adapter_for("<http_lib>")

      require 'vcr'

      VCR.configure do |c|
        c.stub_with <stub_with>
        c.cassette_library_dir = 'cassettes'
      end

      VCR.use_cassette('example', :match_requests_on => [:headers]) do
        puts "Response for user 2: " + response_body_for(:get, "http://example.com/", nil, 'X-User-Id' => '2')
      end

      VCR.use_cassette('example', :match_requests_on => [:headers]) do
        puts "Response for user 1: " + response_body_for(:get, "http://example.com/", nil, 'X-User-Id' => '1')
      end
      """
    When I run `ruby header_matching.rb`
    Then it should pass with:
      """
      Response for user 2: user 2 response
      Response for user 1: user 1 response
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

