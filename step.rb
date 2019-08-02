require_relative 'project_helper'

path = ARGV[0]
scheme = ARGV[1]
config = ARGV[2]
helper = ProjectHelper.new path, scheme, config

targets = helper.targets.collect(&:name)

targets.each do |target_name|
    helper.link_static_library(target_name)
end