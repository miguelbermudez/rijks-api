require 'mongo'
require 'sinatra/base'
#require 'sinatra/synchrony'
require 'json/ext'
require 'rack/contrib/jsonp'
require 'sinatra/config_file'
require 'mini_magick'
require 'cgi'
require 'fileutils'

include Mongo

class RijksApi < Sinatra::Base
  #register Sinatra::Synchrony
  register Sinatra::ConfigFile
  use Rack::JSONP

  config_file 'config.yml'
  set :environment, :development

  configure do
    conn = MongoClient.new(settings.host, settings.mongoport)
    set :mongo_connection, conn
    set :mongo_db, conn.db(settings.database)
    set :mongo_coll, settings.mongo_db[settings.collection]
  end

  before do
    content_type :json
  end

  get '/dbs' do
    settings.mongo_connection.database_info.to_json
  end

  get '/collections/?' do
    settings.mongo_db.collection_names.to_json
  end

  get '/documents/?' do
    skip = ( params[:skip] || "0" ).to_i
    skip = 0 if skip < 0
    page_size = 10
    docs = settings.mongo_coll.find({},{:skip => skip, :limit => page_size})
    docs.each.to_a.to_json
  end

  get '/paintings/?' do
    skip = ( params[:skip] || "0" ).to_i
    skip = 0 if skip < 0
    page_size = 10
    docs = settings.mongo_coll.find({type: 'schilderij'},{:skip => skip, :limit => page_size})
    docs.each.to_a.to_json
  end

  get '/painting/:id' do
    id = params['id']
    work = settings.mongo_coll.find({work_id: id })
    work.to_a.to_json
  end

  get '/paintings/image/' do
    images = []
    skip = ( params[:skip] || "0" ).to_i
    skip = 0 if skip < 0
    page_size = 30
    docs = settings.mongo_coll.find({type: 'schilderij'},
                                    {:skip => skip,
                                     :limit => page_size,
                                     :fields => {"_id" => 0, "formats" => 1 }
                                    })
    docs.to_a.each do |doc|
      url = doc['formats'][0]
      images.push(url)
    end

    images.to_json
  end

  get '/count/?:what?' do
    what = params[:what]
    puts what.inspect
    if (params[:what] == "paintings")
      "#{settings.mongo_coll.find({type: 'schilderij'}).to_a.length} Painting records found ...".to_json
    else
      "#{settings.mongo_coll.count} records found...".to_json
    end
  end

  get '/resize/:dimensions' do
    headers['Cache-Control'] = 'max-age=31536000'
    dimensions = sanitize_dimensions(params[:dimensions])
    url = params[:url]
    puts params.inspect
    uri = URI::parse(url)
    filename = uri.query.downcase.match(/=(.+)$/i)[1]

    #get original image url
    image = MiniMagick::Image.open(url)

    #create tempfile
    tempImageFile = Tempfile.new([filename, ".jpeg"])

    #save full image
    full_image_filename = File.join(settings.imagecache, "#{filename}-full.jpeg")
    image.write(full_image_filename)

    #scale and reduce image
    image.combine_options do |command|
      command.filter("box")
      command.resize(dimensions)
      command.quality '60'
    end

    #write templfile
    image.write(tempImageFile.path)
    tempImageFile.close
    puts "tempfile path: #{tempImageFile.path}"

    #move tempfile to image-cache dir
    FileUtils.mv(tempImageFile.path, "image-cache/#{filename}.jpeg", :verbose => true)
    send_file(image.path, :type => "image/jpeg", :disposition => "inline")
    puts "\n\n"
  end

  get '/image' do

  end
    headers['Cache-Control'] = 'max-age=31536000'
    image_id = params[:id]
    is_full_image_req = params[:full]
    if is_full_image_req
      cache_image_filename = File.join(settings.imagecache, "#{image_id}-full.jpeg")
    else
      cache_image_filename = File.join(settings.imagecache, "#{image_id}.jpeg")
    end

    if File.exist?(cache_image_filename)
      send_file(cache_image_filename, :type => "image/jpeg", :disposition => "inline")
      puts "\n\n"
    else
      redirect_url = "/resize/1000x2000?url=https://www.rijksmuseum.nl/assetimage2.jsp?id=#{image_id}"
      puts "\timage_id: #{image_id}, \tredirect_url: #{redirect_url}"
      redirect redirect_url
    end
  end

  protected

  def sanitize_dimensions(dimensions)
    CGI.unescapeHTML(dimensions)
  end

  def sanitize_url(url)
    url.gsub(%r{^https?://}, '').split('/').map {|u| CGI.escape(u) }.join('/')
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end