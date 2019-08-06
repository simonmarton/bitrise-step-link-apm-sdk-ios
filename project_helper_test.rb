require 'xcodeproj'

MAIN_TARGET = ""

project = Xcodeproj::Project.open(ARGV[0])
project.targets.each do |target_obj|
    next if target_obj.name != MAIN_TARGET

    target_obj.build_configuration_list.build_configurations.each do |build_configuration|
        build_settings = build_configuration.build_settings
        

        if build_settings['OTHER_LDFLAGS']
            build_settings['OTHER_LDFLAGS'].each_with_index do |flag, idx|
                if flag == "libMonitor.a" && build_settings['OTHER_LDFLAGS'][idx-1] != '-force_load'
                    puts "Target '#{target_obj.name}' with '#{build_configuration.name}' configuration does not contain expected build settings"
                    puts "Expected OTHER_LDFLAGS should contain '-force_load libMonitoring.a'"
                    puts "Actual OTHER_LDFLAGS: #{build_settings['OTHER_LDFLAGS']}"
                    exit 1
                end
            end
        else
            puts "Target '#{target_obj.name}' with '#{build_configuration.name}' configuration does not contain OTHER_LDFLAGS"
            puts "Expected OTHER_LDFLAGS should contain '-force_load libMonitoring.a'"
            exit 1
        end

        if build_settings['LIBRARY_SEARCH_PATH'] 
            if !build_settings['LIBRARY_SEARCH_PATH'].include? "$(inherited)" || !(build_settings['LIBRARY_SEARCH_PATH'].include? "$(PROJECT_DIR)/apm-cocoa-sdk")
                puts "Target '#{target_obj.name}' with '#{build_configuration.name}' configuration does not contain expected build settings"
                puts "Expected LIBRARY_SEARCH_PATH should include '$(inherited)' and '$(PROJECT_DIR)/apm-cocoa-sdk'"
                puts "Actual LIBRARY_SEARCH_PATH: #{build_settings['LIBRARY_SEARCH_PATH']}"
                exit 1
            end
        else
            puts "Target '#{target_obj.name}' with '#{build_configuration.name}' configuration does not contain LIBRARY_SEARCH_PATH"
            puts "Expected LIBRARY_SEARCH_PATH should include '$(inherited)' and '$(PROJECT_DIR)/apm-cocoa-sdk'"
            exit 1
        end
    end
end