# frozen_string_literal: true

require 'rack'
require 'open-uri'
require_relative 'id'

#  Сlass ProxyServer that implements everything we need
class ProxyServer
  W_CONTROLLER = 'http://parts.onlinestocksupply.com/iris-vstock-search-'

  def error_response(code)
    [code,
     { 'content-type' => 'text/html', 'cache-control' => 'public, max-age=86400' },
     File.open("public/#{code}.html", File::RDONLY)]
  end

  def do_search(part_number)
    r = rand(0..10_000)
    req = "#{W_CONTROLLER}#{W_CLIENT_ID}-r-en.jsa?Q=#{part_number}&R=#{r}"
#    f = URI.parse(req).open
    f = File.open('sample.txt', 'r')
    [200,
     { 'content-type' => 'text/html', 'cache-control' => 'public, max-age=86400' },
     f]
  end

  #   Process "/search" path
  #   expecting two Get request parameters
  #   "from"    --  "efind"
  #   "search"  --  <P/N to search>
  #   Return 400.html if request does not match this pattern
  def search(req)
    if req.params['from'] != 'efind' || !req.params.key?('search')
      error_response(400)
    else
      do_search(req.params['search'])
    end
  end

  #   Request handler
  #   Serve "/search" path with search method
  #   Return index.html on requests to root
  #   Return 404.html for all other paths
  def call(env)
    req = Rack::Request.new(env)
    case req.path_info
    when '/search'
      search(req)
    when '/'
      error_response(200)
    else
      error_response(404)
    end
  end
end
