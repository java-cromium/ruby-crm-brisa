# config.ru
require_relative 'app'

# Enable PUT/PATCH/DELETE methods via _method parameter in forms
use Rack::MethodOverride

run Sinatra::Application
