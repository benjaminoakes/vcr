require 'spec_helper'

describe VCR::Configuration do
  describe '#cassette_library_dir=' do
    let(:tmp_dir) { VCR::SPEC_ROOT + '/../tmp/cassette_library_dir/new_dir' }
    after(:each) { FileUtils.rm_rf tmp_dir }

    it 'creates the directory if it does not exist' do
      expect { subject.cassette_library_dir = tmp_dir }.to change { File.exist?(tmp_dir) }.from(false).to(true)
    end

    it 'does not raise an error if given nil' do
      expect { subject.cassette_library_dir = nil }.to_not raise_error
    end
  end

  describe '#default_cassette_options' do
    it 'has a hash with some defaults even if it is set to nil' do
      subject.default_cassette_options = nil
      subject.default_cassette_options.should eq({
        :match_requests_on => VCR::RequestMatcherRegistry::DEFAULT_MATCHERS,
        :record            => :once
      })
    end

    it "returns #{VCR::RequestMatcherRegistry::DEFAULT_MATCHERS.inspect} for :match_requests_on when other defaults have been set" do
      subject.default_cassette_options = { :record => :none }
      subject.default_cassette_options.should include(:match_requests_on => VCR::RequestMatcherRegistry::DEFAULT_MATCHERS)
    end

    it "returns :once for :record when other defaults have been set" do
      subject.default_cassette_options = { :erb => :true }
      subject.default_cassette_options.should include(:record => :once)
    end
  end

  describe '#register_request_matcher' do
    it 'registers the given request matcher' do
      expect {
        VCR.request_matcher_registry[:custom]
      }.to raise_error(VCR::UnregisteredMatcherError)

      matcher_run = false
      subject.register_request_matcher(:custom) { |r1, r2| matcher_run = true }
      VCR.request_matcher_registry[:custom].matches?(:r1, :r2)
      matcher_run.should be_true
    end
  end

  describe '#stub_with' do
    it 'stores the given symbols in http_stubbing_libraries' do
      subject.stub_with :fakeweb, :typhoeus
      subject.http_stubbing_libraries.should eq([:fakeweb, :typhoeus])
    end
  end

  describe '#http_stubbing_libraries' do
    it 'returns an empty array when it has not been set' do
      subject.http_stubbing_libraries.should eq([])
    end
  end

  describe '#ignore_hosts' do
    it 'delegates to the current request_ignorer instance' do
      VCR.request_ignorer.should_receive(:ignore_hosts).with('example.com', 'example.net')
      subject.ignore_hosts 'example.com', 'example.net'
    end
  end

  describe '#ignore_localhost=' do
    it 'delegates to the current request_ignorer instance' do
      VCR.request_ignorer.should_receive(:ignore_localhost=).with(true)
      subject.ignore_localhost = true
    end
  end

  describe '#allow_http_connections_when_no_cassette=' do
    [true, false].each do |val|
      it "sets the allow_http_connections_when_no_cassette to #{val} when set to #{val}" do
        subject.allow_http_connections_when_no_cassette = val
        subject.allow_http_connections_when_no_cassette?.should eq(val)
      end
    end
  end

  describe '#filter_sensitive_data' do
    let(:interaction) { mock('interaction') }
    before(:each) { interaction.stub(:filter!) }

    it 'adds a before_record hook that replaces the string returned by the block with the given string' do
      subject.filter_sensitive_data('foo', &lambda { 'bar' })
      interaction.should_receive(:filter!).with('bar', 'foo')
      subject.invoke_hook(:before_record, nil, interaction)
    end

    it 'adds a before_playback hook that replaces the given string with the string returned by the block' do
      subject.filter_sensitive_data('foo', &lambda { 'bar' })
      interaction.should_receive(:filter!).with('foo', 'bar')
      subject.invoke_hook(:before_playback, nil, interaction)
    end

    it 'tags the before_record hook when given a tag' do
      subject.should_receive(:before_record).with(:my_tag)
      subject.filter_sensitive_data('foo', :my_tag) { 'bar' }
    end

    it 'tags the before_playback hook when given a tag' do
      subject.should_receive(:before_playback).with(:my_tag)
      subject.filter_sensitive_data('foo', :my_tag) { 'bar' }
    end

    it 'yields the interaction to the block for the before_record hook' do
      yielded_interaction = nil
      subject.filter_sensitive_data('foo', &lambda { |i| yielded_interaction = i; 'bar' })
      subject.invoke_hook(:before_record, nil, interaction)
      yielded_interaction.should equal(interaction)
    end

    it 'yields the interaction to the block for the before_playback hook' do
      yielded_interaction = nil
      subject.filter_sensitive_data('foo', &lambda { |i| yielded_interaction = i; 'bar' })
      subject.invoke_hook(:before_playback, nil, interaction)
      yielded_interaction.should equal(interaction)
    end
  end
end
