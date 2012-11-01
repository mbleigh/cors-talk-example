require 'bundler'
Bundler.require :default

AUTH_HOST = ENV["AUTH_HOST"] || "http://localhost:3001"

if ENV['REDISTOGO_URL']
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
else
  $redis = Redis.new
  $redis.select 2
end

module CorsExample
  class Streams < Sinatra::Base
    def token
      request.env["HTTP_AUTHORIZATION"].match(/^Bearer (.*)$/i)[1]
    end

    def auth_server
      @connection ||= Faraday.new(url: AUTH_HOST)
    end

    def authenticate(token)
      if id = $redis.get("tokens:#{token}")
        $redis.hgetall "users:#{id}"
      else
        verify_token(token)
      end
    end

    def verify_token(token)
      response = auth_server.get do |req|
        req.url "/verify"
        req.headers['Authorization'] = request.env["HTTP_AUTHORIZATION"]
      end

      if response.status == 200
        data = MultiJson.load(response.body)

        $redis.multi do
          # Cache the token for 10 minutes
          $redis.setex "tokens:#{token}", 600, data["id"]
          $redis.del "users:#{data["id"]}"
          $redis.hmset "users:#{data["id"]}", *data.to_a.flatten
        end

        data
      else
        halt response.status, response.body
      end
    end

    before do
      @user = authenticate(token)
    end

    post '/activities' do
      activity = {
        created_at: Time.now.to_i,
        activity: params[:activity]
      }
      json = MultiJson.dump(activity)

      $redis.lpush "streams:#{@user["id"]}", json
      
      content_type 'application/json'
      json
    end

    get '/activities' do
      content_type "application/json"
      "[" + $redis.lrange("streams:#{@user["id"]}", 0, -1).join(",") + "]"
    end
  end
end

use Rack::Cors do
  allow do
    origins '*'
    resource '/activities', methods: [:get, :post], headers: :any
  end
end

run CorsExample::Streams