require_relative 'project_helper'

path = ARGV[0]
scheme = ARGV[1]
config = ARGV[2]
helper = ProjectHelper.new path, scheme, config

helper.link_static_library()
