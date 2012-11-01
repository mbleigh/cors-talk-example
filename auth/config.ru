require 'bundler'
Bundler.require :default

require 'securerandom'

if ENV['REDISTOGO_URL']
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
else
  $redis = Redis.new
  $redis.select 1
end

APP_HOST = ENV["APP_HOST"] || "http://localhost:3000"

module CorsExample
  class Auth < Sinatra::Base
    use Rack::Session::Cookie
    use OmniAuth::Strategies::Twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']

    get '/' do
      redirect '/auth/twitter'
    end

    get '/auth/twitter/callback' do
      auth = env['omniauth.auth']

      $redis.hmset "users:#{auth.uid}", *auth.info.select{|k,v| %w(name nickname location id).include?(k) }.merge("id" => auth.uid).to_a.flatten
      token = regenerate_token(auth.uid)
      
      redirect APP_HOST + "/#token=#{token}"
    end

    get '/verify' do
      content_type "application/json"
      MultiJson.dump user
    end

    def regenerate_token(id)
      token = SecureRandom.urlsafe_base64(30)
      $redis.multi do
        $redis.set "users:#{id}:token", token
        $redis.set "tokens:#{token}", id
      end

      token
    end

    def token
      @token ||= request.env["HTTP_AUTHORIZATION"].match(/^Bearer (.*)$/i)[1]
    end

    def user
      return @user if @user
      id = $redis.get "tokens:#{token}"
      halt 401, "Unauthorized" unless id
      @user = $redis.hgetall "users:#{id}"
    end
  end
end

use Rack::Cors do
  allow do
    origins "*"
    resource "*", methods: [:get, :post, :put, :delete, :patch, :options], headers: :any
  end
end

run CorsExample::Auth