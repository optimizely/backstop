require 'spec_helper'

require 'backstop/web'
require 'rack/test'

describe Backstop::Application do
  include Rack::Test::Methods

  def app
    Backstop::Application
  end

  before(:each) do
    app.class_variable_set :@@publisher, nil
  end

  context 'GET /health' do
    it 'should handle GET /health' do
      get '/health'
      last_response.should be_ok
    end
  end

  context 'POST /snippet' do
    let(:good_snippet_data) { File.open(File.dirname(__FILE__) + '/good_snippet_data.json').read }
    let(:bad_snippet_data) { File.open(File.dirname(__FILE__) + '/bad_snippet_data.json').read }

    it 'should require JSON' do
      post '/snippet', { :payload => 'foo' }
      last_response.should_not be_ok
      last_response.status.should eq(400) 
    end


    it 'should take a snippet push' do
      p = double('publisher')
      Backstop::Publisher.should_receive(:new) { p }
      p.should_receive(:publish).with('42.Firefox.22.cookies.buckets', 4096)
      p.should_receive(:publish).with('42.Firefox.22.times.clientRun', 432)
      post '/snippet', { :data => good_snippet_data }
      last_response.should be_ok
    end

    it 'should complain if missing fields' do
      post '/snippet', { :data => bad_snippet_data }
      last_response.should_not be_ok
    end
  end
end


