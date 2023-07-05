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

require_relative 'proxy_base'

#  Proxy module
module Proxy
  #  Сlass ProxyServer that implements everything we need
  class ProxyServerEx < ProxyBase
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

    def process_row!(items, row, keywords)
      p_number = row.xpath('td[1]/a')[0].content
      pp_number = p_number.downcase.tr(REMOVE, '')
      return unless keywords.all? { |keyword| pp_number.include? keyword } && !items.key?(p_number)

      to_mfr = row.xpath('td[2]/a')
      mfr = to_mfr[0].nil? ? '-' : to_mfr[0].content
      items.store(p_number, mfr)
    end

    # Parse single document
    def process_document!(items, document, keywords, unlimited)
      document.xpath('//table[@class="dataTable"]/tbody/tr').each do |row|
        process_row!(items, row, keywords)
        break unless unlimited || items.size < MAX_ITEMS
      end
    end

    def process_extra_documents!(items, doc, keywords, unlimited)
      paginator = doc.xpath('//div[@class="pagination"]')
      paginator.xpath('a[not(@class)]').each do |page_ref|
        href = page_ref['href']
        #  puts "Processing additional page at #{href} ..."
        unless href.nil? || href.empty?
          extra_doc = Nokogiri::HTML(URI.parse("#{W_SERVER}/#{href}").open)
          process_document!(items, extra_doc, keywords, unlimited)
        end
        break unless unlimited || items.size < MAX_ITEMS
      end
    end

    def get_document(part_number)
      req = "#{W_SERVER}/#{W_CONTROLLER}?originalFullPartNumber=#{CGI.escape(part_number)}"
      f = URI.parse(req).open
      # f = File.open('sample/sample.txt', 'r')
      Nokogiri::HTML(f)
    end

    def do_search_inner_inner(part_number, logger, unlimited)
      doc = get_document(part_number)
      items = {}
      keywords = part_number.split(SPLIT_RE).map!(&:downcase).map! { |keyword| keyword.tr(REMOVE, '') }
      process_document!(items, doc, keywords, unlimited)
      process_extra_documents!(items, doc, keywords, unlimited)
      logger << "PN '#{part_number}': found #{items.size} items\n"
      generate_output(items)
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
  end
end

# begin
#  p = Proxy::ProxyServerEx.new
#  search = String.new
#  search << 'abcdef'
#  logger = Logger.new('log/proxy-c.log', 'weekly')
#  puts p.do_search(search, logger, false)
# rescue StandardError => e
#  raise e
# end
