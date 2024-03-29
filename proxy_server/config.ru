# frozen_string_literal: true

require_relative './proxy_server'
require_relative './proxy_server_ex'

logger = Logger.new('log/proxy-c.log', 'weekly')

# Middleware to share common log
class WLoggerMiddleware
  def initialize(app, logger)
    @app = app
    @logger = logger
  end

  def call(env)
    env['logger'] = @logger
    @app.call(env)
  end
end

use Rack::Static, urls: ['/css'], root: 'public'
use Rack::CommonLogger, logger
use WLoggerMiddleware, logger

#if rand(0..10_000) > 9_000
run Proxy::ProxyServerEx.new
#else
#  run Proxy::ProxyServer.new
#end
