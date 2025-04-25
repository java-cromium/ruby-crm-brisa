# config.ru
require 'dotenv'
Dotenv.load # Load .env file variables

require 'sequel'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'rack/session/cookie'

# Set up database connection (ensure this happens first)
# Load DATABASE_URL from .env or default
DATABASE_URL = ENV['DATABASE_URL'] || 'postgres://localhost/ruby_crm_dev'
DB = Sequel.connect(DATABASE_URL)
puts "Connecting to database: #{DATABASE_URL}" # Add logging

# Load models (ensure this happens after DB connection)
puts "Loading models..."
Dir['./models/**/*.rb'].each do |file|
  puts " - Requiring #{file}"
  require file
end

# Configure middleware BEFORE requiring the app

# Enable PUT/PATCH/DELETE methods via _method parameter in forms
use Rack::MethodOverride

# OmniAuth configuration - Important to set before session middleware
OmniAuth.config.allowed_request_methods = [:post, :get]  # Allow GET requests (OmniAuth 2.0+ defaults to POST only)
OmniAuth.config.path_prefix = '/auth'  # Explicitly set path prefix

# Configure session middleware with proper settings
use Rack::Session::Cookie, 
    key: 'brisa_session',
    secret: ENV['SESSION_SECRET'] || SecureRandom.hex(64),
    expire_after: 2592000, # 30 days in seconds
    secure: false,         # Set to true in production with HTTPS
    httponly: true,        # Extra security
    same_site: :lax        # Prevents CSRF

# Configure OmniAuth middleware
use OmniAuth::Builder do
  # Ensure ENV variables are loaded before this block
  google_client_id = ENV['GOOGLE_CLIENT_ID']
  google_client_secret = ENV['GOOGLE_CLIENT_SECRET']

  # Add logging to check if ENV variables are loaded
  puts "Google Client ID: #{google_client_id ? google_client_id[0..5] + '...' : 'NIL'}"
  puts "Google Client Secret: #{google_client_secret ? google_client_secret[0..5] + '...' : 'NIL'}"

  provider :google_oauth2, google_client_id, google_client_secret, {
    scope: 'email, profile',
    prompt: 'select_account',
    callback_path: '/auth/google_oauth2/callback'
  }
end

# Now require the application file AFTER middleware setup
puts "Requiring app.rb..."
require_relative './app'

# Map the application itself
# In most Rack applications, this is the final line of config.ru
run BrisaApp
