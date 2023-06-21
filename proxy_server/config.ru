# frozen_string_literal: true

require_relative './proxy_server'

# Cache items placed in the following folders
use Rack::Static, urls: ['/css'], root: 'public'

run Proxy::ProxyServer.new
