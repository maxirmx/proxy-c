# frozen_string_literal: true

require_relative './proxy_server'

logger = Logger.new('log/proxy-c.log', shift_age: 'weekly')
use Rack::CommonLogger, logger

# Cache items placed in the following folders
use Rack::Static, urls: ['/css'], root: 'public'

run Proxy::ProxyServer.new
