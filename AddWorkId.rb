require 'mongo'
require 'json/ext'
require 'yaml'
require 'awesome_print'

include Mongo

settings = YAML.load_file('config.yml')
settings = settings['development']

conn = MongoClient.new(settings['host'], settings['mongoport'])
db = conn.db(settings['database'])
coll =  db[settings['collection']]

#find all paintings
docs = coll.find({type: 'schilderij'}).limit(1)   # n.3281

#get the first formats entry
docs.each_with_index do |doc|
  uri = URI::parse(doc['formats'][0])
  work_id = uri.query.downcase.match(/=(.+)$/i)[1]
  doc['work_id'] = work_id
  coll.update({"_id" => doc['_id']}, doc)
end
