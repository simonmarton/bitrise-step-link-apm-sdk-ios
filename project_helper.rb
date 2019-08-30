require 'find'
require 'xcodeproj'
require 'json'
require 'plist'
require 'English'

# ProjectHelper ...
class ProjectHelper
  attr_reader :main_target

  def initialize(project_or_workspace_path, scheme_name)
    raise "project not exist at: #{project_or_workspace_path}" unless File.exist?("#{project_or_workspace_path}")

    extname = File.extname(project_or_workspace_path)
    raise "unkown project extension: #{extname}, should be: .xcodeproj or .xcworkspace" unless ['.xcodeproj', '.xcworkspace'].include?(extname)

    @project_path = "#{project_or_workspace_path}"

    # ensure scheme exist
    scheme, scheme_container_project_path = read_scheme_and_container_project(scheme_name)

    # read scheme application targets
    @main_target, @targets_container_project_path = read_scheme_archivable_target_and_container_project(scheme, scheme_container_project_path)
    raise "failed to find #{scheme_name} scheme's main archivable target" unless @main_target

  end

  def link_static_library()
    @project.targets.each do |target_obj|
        next if target_obj.name != @main_target.name 
    
        target_obj.build_configuration_list.build_configurations.each do |build_configuration| 
            configuration_found = true
        

            build_settings = build_configuration.build_settings
            codesign_settings = {
                'OTHER_LDFLAGS' => '$(inherited) -force_load libMonitor.a',
                'LIBRARY_SEARCH_PATH' => '$(inherited) $(PROJECT_DIR)/apm-cocoa-sdk',
            }
            build_settings.merge!(codesign_settings)
    
        end
    end
    @project.save
  end

  def register_resource()
    apm_collector_token = ENV['APM_COLLECTOR_TOKEN']
    bitrise_configuration_path = "#{@project.path}/../bitrise_configuration.plist"

    obj = Xcodeproj::Plist.write_to_path({
      "APM_COLLECTOR_TOKEN" => apm_collector_token
    }, bitrise_configuration_path)
    
    added_fileref = @project.new_file(bitrise_configuration_path)
    
    res_build_phase = @main_target.resources_build_phase

    added_buildf = res_build_phase.add_file_reference(added_fileref)

    group = @project.main_group
    referenced_build_files = added_buildf.file_ref.build_files

    @project.save
  end

  private

  def read_scheme_and_container_project(scheme_name)
    project_paths = [@project_path]
    project_paths += contained_projects if workspace?

    project_paths.each do |project_path|
      schema_path = File.join(project_path, 'xcshareddata', 'xcschemes', scheme_name + '.xcscheme')

      # if shared scheme does not exist, find the first user scheme
      unless File.exist?(schema_path)
        schema_path = Find.find(project_path).select { |f| f =~ /.*#{scheme_name}\.xcscheme$/ }[0]
      end

      next unless schema_path

      return Xcodeproj::XCScheme.new(schema_path), project_path
    end

    raise "project (#{@project_path}) does not contain scheme: #{scheme_name}"
  end

  def archivable_target_and_container_project(buildable_references, scheme_container_project_dir)
    buildable_references.each do |reference|
      next if reference.target_name.to_s.empty?
      next if reference.target_referenced_container.to_s.empty?

      container = reference.target_referenced_container.sub(/^container:/, '')
      next if container.empty?

      target_project_path = File.expand_path(container, scheme_container_project_dir)
      next unless File.exist?(target_project_path)

      @project = Xcodeproj::Project.open(target_project_path)
      target = @project.targets.find { |t| t.name == reference.target_name }
      next unless target
      next unless runnable_target?(target)

      return target, target_project_path
    end
  end

  def read_scheme_archivable_target_and_container_project(scheme, scheme_container_project_path)
    build_action = scheme.build_action
    return nil unless build_action

    entries = build_action.entries || []
    return nil if entries.empty?

    entries = entries.select(&:build_for_archiving?) || []
    return nil if entries.empty?

    scheme_container_project_dir = File.dirname(scheme_container_project_path)

    entries.each do |entry|
      buildable_references = entry.buildable_references || []
      next if buildable_references.empty?

      target, target_project_path = archivable_target_and_container_project(buildable_references, scheme_container_project_dir)
      next if target.nil? || target_project_path.nil?

      return target, target_project_path
    end

    nil
  end

  def workspace?
    extname = File.extname(@project_path)
    extname == '.xcworkspace'
  end

  def contained_projects
    return [@project_path] unless workspace?

    workspace = Xcodeproj::Workspace.new_from_xcworkspace(@project_path)
    workspace_dir = File.dirname(@project_path)
    project_paths = []
    workspace.file_references.each do |ref|
      pth = ref.path
      next unless File.extname(pth) == '.xcodeproj'
      next if pth.end_with?('Pods/Pods.xcodeproj')

      project_path = File.expand_path(pth, workspace_dir)
      project_paths << project_path
    end

    project_paths
  end

  def runnable_target?(target)
    return false unless target.is_a?(Xcodeproj::Project::Object::PBXNativeTarget)

    product_reference = target.product_reference
    return false unless product_reference

    product_reference.path.end_with?('.app', '.appex')
  end
end
