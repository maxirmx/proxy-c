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

require_relative 'id'

#  Proxy module
module Proxy
  def self.redis
    r = Redis.new
    r.get 'test'
    @redis ||= ConnectionPool::Wrapper.new { r }
  rescue StandardError
    @redis ||= nil
  end

  #  Сlass ProxyServer that implements everything we need
  # rubocop:disable Metrics/ClassLength
  class ProxyServer
    W_SERVER = 'http://parts.onlinestocksupply.com'
    W_CONTROLLER = 'iris-vstock-search-'

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

    # Check that part_number contains ALL keywords from the search term
    # efind.ru wants ALL while brokerforum.com provides ANY
    # Squash duplicate part numbers
    def squash_items!(squashed_items, items, keywords, unlimited)
      items.each do |item|
        p_number = item['PartNumber']
        pp_number = p_number.tr(REMOVE, '')
        if keywords.all? { |keyword| pp_number.include? keyword } && !squashed_items.key?(p_number)
          squashed_items.store(p_number, item['ManufacturerName'])
        end
        break unless unlimited || squashed_items.size < MAX_ITEMS
      end
    end

    # Output generator
    # Specification https://efind.ru/services/partnership/online/specs/
    def generate_output(items)
      output = ['<data version="2.0">']
      items.each do |key, value|
        output << '<item>'
        output << "<part>#{key}</part>"
        output << "<mfg>#{value}</mfg>" unless value == '-'
        output << '<dlv>4-6 недель</dlv><note>Под заказ</note>'
        output << '</item>'
      end
      output << '</data>'
    end

    # Parse single document
    # Table cells like <td class="txtC noRightBord">
    # And items inside like <input type="hidden" name="Doc.TargetClient[24].Item.PartNumber" value="4-1633930-9"/>
    def process_document!(items, document)
      document.xpath('//table/tbody/tr/td[@class="txtC noRightBord"]/input').each do |input|
        i_match, i_item, i_name = input['name'].match(/Doc.TargetClient\[(.+)\]\.Item\.(.+)/).to_a
        next if i_match.nil?

        items[i_item.to_i] = {} if items[i_item.to_i].nil?
        items[i_item.to_i].store(i_name, input['value'])
        #        puts "---> #{items[i_item.to_i]}"
      end
    end

    def process_extra_documents!(final_items, doc, keywords, unlimited)
      doc.xpath('//body/div/div/div/a').each do |page_ref|
        href = page_ref['href']
        # puts "Processing additional page at #{page_ref} ..."
        unless href.nil? || href.empty?
          # extra_req = "#{W_SERVER}/#{href}"
          # puts "extra_req  #{extra_req}"
          extra_doc = Nokogiri::HTML(URI.parse("#{W_SERVER}/#{href}").open)
          items = []
          process_document!(items, extra_doc)
          squash_items!(final_items, items, keywords, unlimited)
        end
        break unless unlimited || final_items.size < MAX_ITEMS
      end
    end

    def get_document(part_number)
      req = "#{W_SERVER}/#{W_CONTROLLER}#{W_CLIENT_ID}-r-en.jsa?Q=#{CGI.escape(part_number)}&R=#{rand(0..10_000)}"
      f = URI.parse(req).open
      # f = File.open('sample/sample.txt', 'r')
      Nokogiri::HTML(f)
    end

    def do_search_inner_inner(part_number, logger, unlimited)
      # pn = part_number.tr(REMOVE, ' ')
      doc = get_document(part_number)
      items = []
      final_items = {}
      keywords = part_number.split(SPLIT_RE).map! { |keyword| keyword.tr(REMOVE, '') }
      process_document!(items, doc)

      squash_items!(final_items, items, keywords, unlimited)
      logger << "PN '#{part_number}': found #{items.size} items ... filtered to: #{final_items.size}\n"
      process_extra_documents!(final_items, doc, keywords, unlimited) if unlimited || final_items.size < MAX_ITEMS
      generate_output(final_items)
    end

    def save_response(part_number, rsp)
      Proxy.redis.set part_number, rsp
      Proxy.redis.expire part_number, 60 * 60 * 24 * 7
    end

    def do_search_inner(part_number, logger, unlimited)
      rsp = Proxy.redis.nil? || unlimited ? nil : Proxy.redis.get(part_number)
      if rsp.nil?
        rsp = do_search_inner_inner(part_number, logger, unlimited)
        save_response(part_number, rsp) unless Proxy.redis.nil? || unlimited
      else
        logger << "PN '#{part_number}': served from cache\n"
        rsp = JSON.parse(rsp)
      end

      response rsp
    end

    # Do search job
    def do_search(part_number, logger, unlimited)
      if part_number.force_encoding('UTF-8').ascii_only?
        do_search_inner(part_number, logger, unlimited)
      else
        logger << "PN '#{part_number}': empty response because of non ascii symbols\n"
        empty_response
      end
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
  # rubocop:enable Metrics/ClassLength
end

# begin
#   p = Proxy::ProxyServer.new
#   search = String.new
#   search << '4163'
#   logger = Logger.new('log/proxy-c.log', 'weekly')
#   puts p.do_search(search, logger, false)
# rescue StandardError => e
#   raise e
# end
