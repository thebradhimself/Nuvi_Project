require 'rubygems'
require 'zip'
require 'pry'
require 'open-uri'
require 'curb'
require 'redis'
require 'nokogiri'

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
    #using open uri to open the URL of the zip file
    download = open(zip)
    #set name of zip file and where it will be saved
    save_location = "files/temp/#{zip_names[index].first}"
    #download and save zip files to save_location
    IO.copy_stream(download, save_location) unless File.exists?(save_location)
    #function to unzip the brand new zip file, passing in file location
    unzip_the_zip(save_location)
  end
end

def unzip_the_zip(the_zip)
  #using rubyzip to open zip file
  Zip::File.open(the_zip) do |zip_file|
    #redis
    redis = Redis.new
    #open zip file and go through each item
    zip_file.each do |item|
      puts "Saving #{item.name} to Redis"
      #Removes xml item from redis list if it exists, no errors happen if it does not exist. Duplicate entries cannote exist with this method
      redis.lrem('NEWS_XML', 1, item)
      #pushes item onto list titled NEWS_XML
      redis.lpush('NEWS_XML', item)
    end
  end
end

grab_the_zips()
