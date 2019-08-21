require 'down'
require "fileutils"
require_relative 'project_helper'

if !ENV['APM_COLLECTOR_TOKEN']
    puts 'Error: missing APM_COLLECTOR_TOKEN env'
    exit 1
end

path = ARGV[0]
scheme = ARGV[1]
lib_version = ENV['LIB_VERSION']

if !path 
    puts "Error: BITRISE_PROJECT_PATH env var is required"
end

if !scheme
    puts "Error: BITRISE_SCHEME env var is required"
end

if lib_version.empty?
    raise "Error: missing input LIB_VERSION"
end

begin
    url = "https://monitoring-sdk.firebaseapp.com/#{lib_version}/libMonitor.a"
    tmpf = Down.download(url)
    FileUtils.mv(tmpf.path, "#{path}/#{tmpf.original_filename}")
rescue Exception => e
    puts "Error downloading Bitrise monitoring library version #{lib_version} from #{url}: #{e.message}"
    exit 1
end

helper = ProjectHelper.new(path, scheme)

begin
    puts "Updating project to link monitoring library"
    helper.link_static_library()
rescue Exception => e
    puts "Error modifying project to link monitoring library: #{e.message}"
end

begin
    puts "Registering configuration plist file into build phase"
    helper.register_resource()
rescue Exception => e
    puts "Error registering Bitrise configuration plist file: #{e.message}"
end

puts "Done!"
