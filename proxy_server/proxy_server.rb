# frozen_string_literal: true

require 'rack'
require 'open-uri'
require 'nokogiri'
require_relative 'id'

#  Сlass ProxyServer that implements everything we need
class ProxyServer
  W_SERVER = 'http://parts.onlinestocksupply.com'
  W_CONTROLLER = 'iris-vstock-search-'

  # Generate error page
  # This also covers 200 OK for the root :)
  def error_response(code)
    [code,
     { 'content-type' => 'text/html', 'cache-control' => 'public, max-age=86400' },
     File.open("public/#{code}.html", File::RDONLY)]
  end

  # Aquash duplicate part numbers
  def squash_items(items)
    squashed_items = {}
    items.each do |item|
      unless squashed_items.key?(item['PartNumber'])
        squashed_items.store(item['PartNumber'],
                             item['ManufacturerName'])
      end
    end
    squashed_items
  end

  # Output generator
  # Specification https://efind.ru/services/partnership/online/specs/
  def generate_output(items)
    output = ['<data version="2.0">']
    squash_items(items).each do |key, value|
      output << '  <item>'
      output << "    <part>#{key}</part>"
      output << "    <mfg>#{value}</mfg>" unless value == '-'
      output << '<dlv>6-8 недель</dlv>'
      output << '  </item>'
    end
    output << '</data>'
  end

  # Parse single document
  # Table cells like <td class="txtC noRightBord">
  # And items inside like <input type="hidden" name="Doc.TargetClient[24].Item.PartNumber" value="4-1633930-9"/>
  def process_document!(items, document)
    document.xpath('//table/tbody/tr/td[@class="txtC noRightBord"]/input').each do |input|
      i_match, i_item, i_name = input['name'].match(/Doc.TargetClient\[(.+)\]\.Item\.(.+)/).to_a
      unless i_match.nil?
        items[i_item.to_i] = {} if items[i_item.to_i].nil?
        items[i_item.to_i].store(i_name, input['value'])
      end
    end
  end

  def do_search(part_number)
    r = rand(0..10_000)
    req = "#{W_SERVER}/#{W_CONTROLLER}#{W_CLIENT_ID}-r-en.jsa?Q=#{part_number}&R=#{r}"
    f = URI.parse(req).open
    # f = File.open('sample.txt', 'r')
    doc = Nokogiri::HTML(f)

    items = []
    process_document!(items, doc)
    output = generate_output(items)

    [200,
     { 'content-type' => 'text/plain', 'cache-control' => 'public, max-age=86400' },
     output]
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

# begin
#  p = ProxyServer.new
#  puts p.do_search('123')
# rescue StandardError => e
#  raise e
# end
