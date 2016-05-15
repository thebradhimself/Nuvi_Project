require 'rubygems'
require 'zip'
require 'pry'
require 'open-uri'
require 'curb'
require 'redis'

def grab_the_zips

  Dir.mkdir("files/") unless File.exists?("files/")

  #setting url to a variable since we use it more than once
  url = "http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/"
  #using curl to grab the http file.
  http = Curl.get(url)
  #using regex to scan the http body as a string for all zip file names
  zip_strings = http.body_str.scan(/([0-9]+.zip)+/)
  #putting the zip file names into a better format with URL at the front and it is no longer an array of arrays.
  formatted_strings = zip_strings.flatten.map {|item| "#{url}#{item}"}
  #call my function to download all the zip files
  download_the_zips(formatted_strings, zip_strings)
end

def download_the_zips(the_zips, zip_names)

  #temp_dir for saving zips
  temp_dir = "files/temp/"
  # create directory if it does not exist
  Dir.mkdir(temp_dir) unless File.exists?(temp_dir)

  #do a loop on my array of zip file names
  the_zips.each_with_index do |zip, index|
    puts "Downloading zip file #{zip_names[index].first}.  Can take up to 20 seconds per zip file"
    #using open uri to open the URL of the zip file
    download = open(zip)
    #set name of zip file and where it will be saved
    save_location = "files/temp/#{zip_names[index].first}"
    #download and save zip files to save_location
    IO.copy_stream(download, save_location) unless File.exists?(save_location)
    #function to unzip the brand new zip file, passing in file location
    unzip_the_zip(save_location)
    #remove zip file after all XML files have been extracted
    FileUtils.rm_rf(save_location)
  end
end

def unzip_the_zip(the_zip)

  #temp_dir for saving xml file
  temp_dir = "files/xml/"
  # create directory if it does not exist
  Dir.mkdir(temp_dir) unless File.exists?(temp_dir)

  #using rubyzip to open zip file
  Zip::File.open(the_zip) do |zip_file|
    #redis
    redis = Redis.new
    #open zip file and go through each item
    zip_file.each do |item|
      #variable with file name and location for xml file
      final_path = File.join(temp_dir, item.name)
      #save xml file to files/xml/FILE_NAME
      item.extract(final_path) unless File.exists?(final_path)
      #reads xml in as string
      file = File.read(final_path)
      puts "Saving contents of #{item.name} to Redis"
      #Removes xml contents from redis list if it exists, no errors happen if it does not exist. Duplicate entries cannote exist with this method
      redis.lrem('NEWS_XML', 1, file)
      #pushes item onto list titled NEWS_XML
      redis.lpush('NEWS_XML', file)
      #removes xml file after done being used to save on space
      FileUtils.rm_rf(final_path)
    end
  end
end

grab_the_zips()
I
