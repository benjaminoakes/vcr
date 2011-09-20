require 'vcr/cassette/http_interaction_list'
require 'vcr/request_matcher_registry'
require 'vcr/structs/http_interaction'
require 'uri'

module VCR
  class Cassette

    shared_examples_for "an HTTP interaction finding method" do |method|
      it 'returns nil when the list is empty' do
        HTTPInteractionList.new([], [:method]).send(method, stub).should respond_with(nil)
      end

      it 'returns nil when there is no matching interaction' do
        HTTPInteractionList.new([
          interaction('foo', :method => :post),
          interaction('foo', :method => :put)
        ], [:method]).send(method,
          request_with(:method => :get)
        ).should respond_with(nil)
      end

      it 'returns the first matching interaction' do
        list = HTTPInteractionList.new([
          interaction('put response', :method => :put),
          interaction('post response 1', :method => :post),
          interaction('post response 2', :method => :post)
        ], [:method])

        list.send(method, request_with(:method => :post)).should respond_with("post response 1")
      end

      it 'invokes each matcher block to find the matching interaction' do
        VCR.request_matcher_registry.register(:foo) { |r1, r2| true }
        VCR.request_matcher_registry.register(:bar) { |r1, r2| true }

        calls = 0
        VCR.request_matcher_registry.register(:baz) { |r1, r2| calls += 1; calls == 2 }

        list = HTTPInteractionList.new([
          interaction('response', :method => :put)
        ], [:foo, :bar, :baz])

        list.send(method, request_with(:method => :post)).should respond_with(nil)
        list.send(method, request_with(:method => :post)).should respond_with('response')
      end

      it "delegates to the parent list when it can't find a matching interaction" do
        parent_list = mock(method => response('parent'))
        HTTPInteractionList.new(
          [], [:method], parent_list
        ).send(method, stub).should respond_with('parent')
      end
    end

    describe HTTPInteractionList do
      before(:each) do
        VCR.stub(:request_matcher_registry => VCR::RequestMatcherRegistry.new)
      end

      def request_with(values)
        VCR::Request.new.tap do |request|
          values.each do |name, value|
            request.send("#{name}=", value)
          end
        end
      end

      def response(body)
        VCR::Response.new.tap { |r| r.body = body }
      end

      def interaction(body, request_values)
        VCR::HTTPInteraction.new \
          request_with(request_values),
          response(body)
      end

      describe "#has_interaction_matching?" do
        it_behaves_like "an HTTP interaction finding method", :has_interaction_matching? do
          def respond_with(value)
            ::RSpec::Matchers::Matcher.new :respond_with, value do |expected|
              match { |a| expected ? a : !a }
            end
          end
        end

        it 'does not consume the first matching interaction' do
          list = HTTPInteractionList.new([
            interaction('put response', :method => :put),
            interaction('post response 1', :method => :post),
            interaction('post response 2', :method => :post)
          ], [:method])

          10.times do
            list.has_interaction_matching?(request_with(:method => :post)).should be_true
          end
          list.response_for(request_with(:method => :post)).body.should eq("post response 1")
        end
      end

      describe "#response_for" do
        it_behaves_like "an HTTP interaction finding method", :response_for do
          def respond_with(value)
            ::RSpec::Matchers::Matcher.new :respond_with, value do |expected|
              match { |a| expected.nil? ? a.nil? : a.body == expected }
            end
          end
        end

        let(:list) do
          HTTPInteractionList.new([
            interaction('put response', :method => :put),
            interaction('post response 1', :method => :post),
            interaction('post response 2', :method => :post)
          ], [:method])
        end

        it 'consumes the first matching interaction so that it will not be used again' do
          list.response_for(request_with(:method => :post)).body.should eq("post response 1")
          list.response_for(request_with(:method => :post)).body.should eq("post response 2")
        end

        it 'continues to return the response from the last matching interaction when there are no more' do
          list.response_for(request_with(:method => :post))

          10.times.map {
            response = list.response_for(request_with(:method => :post))
            response ? response.body : nil
          }.should eq(["post response 2"] * 10)
        end
      end
    end
  end
end

