# frozen_string_literal: true

require 'cgi'
require 'json'
require 'rack'
require 'open-uri'
require 'nokogiri'
require 'tzinfo'
require 'connection_pool'
begin
  require 'redis'
rescue LoadError
  false
end

#  Proxy module
module Proxy
  def self.redis
    r = Redis.new
    r.get 'test'
    @redis ||= ConnectionPool::Wrapper.new { r }
  rescue StandardError
    @redis ||= nil
  end

  #  Сlass ProxyBase
  class ProxyBase
    W_SERVER = ''
    W_CONTROLLER = ''

    # Если запрашиваемая строка состоит из слов, разделенных пробелом (или символом-разделителем),
    # в результирующих строках должны присутствовать все запрашиваемые слова.
    # Символы-разделители: « », «\t» (табуляция), «\n» (перевод строки), «,» «;» «*» «?».
    # \s - tab, space, newline
    SPLIT_RE = /[\s,;*?]/.freeze

    # При поиске допускается удаление некоторых спецсимволов: «_», «-», «.», «/», «\», «|», «#», «~», «+»,
    # «^», «@», «%», «(», «)», «{», «}», «[», «]», «=», «:», «'», «"», «`», «<»,«>», «–» («длинное» тире).
    REMOVE = '_\-./\\|#~+^@%(){}[]=:\'"`<>–'

    # В результатах поиска должно быть не более 5 строк.
    MAX_ITEMS = 5

    # Generate error page
    # This also covers 200 OK for the root :)
    def error_response(code)
      [code,
       { 'content-type' => 'text/html', 'cache-control' => 'public, max-age=86400' },
       File.open("public/#{code}.html", File::RDONLY)]
    end

    def response(items)
      [200,
       { 'content-type' => 'text/xml', 'cache-control' => 'public, max-age=86400' },
       items]
    end

    def empty_response
      [200,
       { 'content-type' => 'text/xml', 'cache-control' => 'public, max-age=86400' },
       File.open('public/empty.xml', File::RDONLY)]
    end

    # Output generator
    # Specification https://efind.ru/services/partnership/online/specs/
    def generate_output(items)
      output = ['<data version="2.0">']
      items.each do |key, value|
        output << '<item>'
        output << "<part>#{key}</part>"
        output << "<mfg>#{value == '-' ? '' : value}</mfg>"
        output << '<dlv>4-6 недель</dlv><note>Под заказ</note>'
        output << '</item>'
      end
      output << '</data>'
    end

    def do_search(_req, _logger)
      empty_response
    end

    # Process "/search" path
    # expecting two Get request parameters
    #   "from"    --  "efind"
    #   "pn"  --  <P/N to search>
    # Return 400.html if request does not match this pattern
    def search(req, logger)
      case req.params['from']
      when 'efind'
        do_search(req.params['pn'].upcase, logger, false)
      when 'intrademanagement'
        do_search(req.params['pn'].upcase, logger, true)
      else
        error_response(400)
      end
    end

    #   Request handler
    #   Serve "/search" path with search method
    #   Return 200.html on requests to root
    #   Return 404.html for all other paths
    def call(env)
      req = Rack::Request.new(env)

      if req.path_info == '/search' && req.params.key?('pn')
        search(req, env['logger'])
      else
        error_response(req.path_info == '/' ? 200 : 400)
      end
      # rescue StandardError
      # empty_response
    end
  end
end
