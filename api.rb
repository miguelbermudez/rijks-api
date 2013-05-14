require 'sinatra/base'
require 'mongo'
require 'json/ext'
require 'rack/contrib/jsonp'
require 'sinatra/config_file'
require 'mini_magick'
require 'cgi'

include Mongo

class RijksApi < Sinatra::Base

  use Rack::JSONP
  register Sinatra::ConfigFile
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
    dimensions = params[:dimensions]
    url = params[:url]
    puts params.inspect

    dimensions = sanitize_dimensions(dimensions)
    image = MiniMagick::Image.open(url)
    image.combine_options do |command|
      command.filter("box")
      command.resize(dimensions)
      command.quality '75'
    end
    send_file(image.path, :type => "image/jpeg", :disposition => "inline")
  end

  protected

  def sanitize_dimensions(dimensions)
    CGI.unescapeHTML(dimensions)
  end

  def sanitize_url(url)
    url.gsub(%r{^https?://}, '').split('/').map {|u| CGI.escape(u) }.join('/')
  end



  #helpers do
  #  def object_id val
  #    BSON::ObjectId.from_string(val)
  #  end
  #
  #  def document_by_id id
  #    id = object_id(id) if String === id
  #    settings.mongo_coll.find_one({_id: id}).to_json
  #  end
  #end

  # start the server if ruby file executed directly
  run! if app_file == $0
end