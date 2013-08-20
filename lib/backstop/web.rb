require 'sinatra'
require 'json'
require 'time'

require 'backstop'

module Backstop
  class Application < Sinatra::Base
    configure do
      enable :logging
      @@publisher = nil
    end

    before do
      protected! unless request.path == '/health'
    end

    helpers do
      def protected!
        return unless ENV['BACKSTOP_AUTH']
        return if authorized?
        headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
        halt 401, "Not authorized\n"
      end
      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ENV['BACKSTOP_AUTH'].split(':')
      end
      def publisher
        @@publisher ||= Backstop::Publisher.new(Config.carbon_urls, :api_key => Config.api_key)
      end
      def send(metric, value, time)
        begin
          publisher.publish(metric, value, time)
        rescue
          publisher.close_all
          @@publisher = nil
        end
      end
      def send(metric, value)
        begin
          publisher.publish(metric, value)
        rescue
          publisher.close_all
          @@publisher = nil
        end
      end
    end

    get '/health' do
      {'health' => 'ok'}.to_json
    end
    

    post '/snippet' do
      headers['Access-Control-Allow-Origin'] = '*'
      begin
        data = JSON.parse(params['data'])
      rescue
        halt 400, 'No JSON in data key'
      end
      required_fields = %w[accountId browser version]
      required_fields.each do |field|
        halt 400, "Missing #{field}" unless data.has_key?(field)
      end
      base_key = data.values_at(*required_fields).join(".")
      optional_fields = %w[cookies.buckets cookies.segments. cookies.pendingLogEvents
                           cookies.customEvents cookies.total
                           times.clientRun times.potentialFlash time.main]

      optional_fields.each do |field|
        if data.has_key?(field)
          key = [base_key, field].join('.')
          send(key, data[field])
        end
      end
    end

  end
end
