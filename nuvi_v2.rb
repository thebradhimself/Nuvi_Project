require 'zip'
require 'open-uri'
require 'curb'
require 'redis'

class Nuvi

  URL = "http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/"

  # A files directory is created, I use CURL to get the http from the URL
  # I scan that file using REGEX for a pattern that will grab all zip file names.
  def grab_the_zips

    Dir.mkdir("files/") unless File.exists?("files/")
    zip_strings = Curl.get(URL).body_str.scan(/([0-9]+.zip)+/)
    formatted_strings = zip_strings.flatten.map {|item| "#{URL}#{item}"}
    download_the_zips(formatted_strings, zip_strings)

  end

  # Each zip file name is looped through and opened/downloaded using open-uri.
  # After each zip file is done being used, it is deleted
  def download_the_zips(the_zips, zip_names)

    temp_dir = "files/temp/"
    Dir.mkdir(temp_dir) unless File.exists?(temp_dir)
    the_zips.each_with_index do |zip, index|
      puts "Downloading zip file #{zip_names[index].first}.  Can take up to 30 seconds per zip file"
      download = open(zip)
      save_location = "files/temp/#{zip_names[index].first}"
      IO.copy_stream(download, save_location) unless File.exists?(save_location)
      unzip_the_zip(save_location)
      FileUtils.rm_rf(save_location)
    end

  end

  # Each zip file is opened and the xml file is saved temporariy.
  # I grab the contents of the XML file and remove it from Redis if it exists and then add it.
  def unzip_the_zip(the_zip)

    temp_dir = "files/xml/"
    Dir.mkdir(temp_dir) unless File.exists?(temp_dir)

    Zip::File.open(the_zip) do |zip_file|
      redis = Redis.new
      zip_file.each do |item|
        final_path = File.join(temp_dir, item.name)
        item.extract(final_path) unless File.exists?(final_path)
        file = File.read(final_path)
        puts "Saving contents of #{item.name} to Redis"
        redis.lrem('NEWS_XML', 1, file)
        redis.lpush('NEWS_XML', file)
        FileUtils.rm_rf(final_path)
      end
    end
  end

end

Nuvi.new.grab_the_zips
