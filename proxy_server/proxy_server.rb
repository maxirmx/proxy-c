require 'rack'

class ProxyServer
#   def call(req)
#        puts "Hello World!"
#        return [200, {"Content-Type" =>"plain/text"}, ["Hello World!"]]
#   end
    W_CONTROLLER = "http://parts.onlinestocksupply.com/iris-vstock-search-"
    W_CLIENT_ID = "intrd9076"

    def do_search(part_number)
        r = rand(0..10000)
        req = "#{W_CONTROLLER}#{W_CLIENT_ID}-r-en.jsa?Q=#{part_number}&R=#{r}";
        [   200,
            { "content-type"  => "text/html", "cache-control" => "public, max-age=86400" },
            ["Hello, my friend! I will emit #{req}"],
        ]
end


    #   Process "/search" path
    #   expecting two Get request parameters
    #   "from"    --  "efind"
    #   "search"  --  <P/N to search>
    #   Return 400.html if request does not match this pattern
    def search(req)
        if req.params["from"] != "efind" || !req.params.has_key?("search")
            [   400,
                { "content-type"  => "text/html", "cache-control" => "public, max-age=86400" },
                File.open('public/400.html', File::RDONLY),
            ]
        else
            do_search(req.params["search"])
        end
    end

    #   Request handler
    #   Serve "/search" path with search method
    #   Return index.html on requests to root
    #   Return 404.html for all other paths
    def call(env)
        req = Rack::Request.new(env)
        case req.path_info
        when "/search"
            search(req)
        when "/"
            [  200,
                { "content-type"  => "text/html", "cache-control" => "public, max-age=86400" },
                File.open('public/index.html', File::RDONLY),
            ]
        else [  404,
                { "content-type"  => "text/html", "cache-control" => "public, max-age=86400" },
                File.open('public/404.html', File::RDONLY),
             ]
        end
    end
end