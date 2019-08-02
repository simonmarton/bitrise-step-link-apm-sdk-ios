require 'xcodeproj'
require 'json'
require 'plist'
require 'English'

# ProjectHelper ...
class ProjectHelper
  attr_reader :main_target
  attr_reader :targets
  attr_reader :platform

  def initialize(project_or_workspace_path, scheme_name, configuration_name)
    raise "project not exist at: #{project_or_workspace_path}" unless File.exist?(project_or_workspace_path)

    extname = File.extname(project_or_workspace_path)
    raise "unkown project extension: #{extname}, should be: .xcodeproj or .xcworkspace" unless ['.xcodeproj', '.xcworkspace'].include?(extname)

    @project_path = project_or_workspace_path

    # ensure scheme exist
    scheme, scheme_container_project_path = read_scheme_and_container_project(scheme_name)

    # read scheme application targets
    @main_target, @targets_container_project_path = read_scheme_archivable_target_and_container_project(scheme, scheme_container_project_path)
    raise "failed to find #{scheme_name} scheme's main archivable target" unless @main_target
    @platform = @main_target.platform_name

    @targets = collect_dependent_targets(@main_target)
    @targets = unique_targets(@targets) unless @targets.empty?
    raise "failed to collect #{@main_target}'s dependent targets" if @targets.empty?

    # ensure configuration exist
    action = scheme.archive_action
    raise "archive action not defined for scheme: #{scheme_name}" unless action
    default_configuration_name = action.build_configuration
    raise "archive action's configuration not found for scheme: #{scheme_name}" unless default_configuration_name

    if configuration_name.empty? || configuration_name == default_configuration_name
      @configuration_name = default_configuration_name
    elsif configuration_name != default_configuration_name
      targets.each do |target_obj|
        configuration = target_obj.build_configuration_list.build_configurations.find { |c| configuration_name.to_s == c.name }
        raise "build configuration (#{configuration_name}) not defined for target: #{@main_target.name}" unless configuration
      end

      @configuration_name = configuration_name
    end

    @build_settings_by_target = {}
  end

  def link_static_library(target_name, development_team)
    project = Xcodeproj::Project.open(@targets_container_project_path)
    project.targets.each do |target_obj|
        target_found = true
    
        target_obj.build_configuration_list.build_configurations.each do |build_configuration| 
            configuration_found = true
        

            build_settings = build_configuration.build_settings
            codesign_settings = {
                'OTHER_LDFLAGS' => '-force_load libMonitor.a',
                'LIBRARY_SEARCH_PATH' => '$(inherited) $(PROJECT_DIR)/apm-cocoa-sdk',
            }
            build_settings.merge!(codesign_settings)
    
        end
    end
    project.save
  end

  def project_team_id
    team_id = nil

    project = Xcodeproj::Project.open(@targets_container_project_path)
    attributes = project.root_object.attributes['TargetAttributes'] || {}

    @targets.each do |target|
      target_name = target.name

      current_team_id = target_team_id(target_name)
      # Log.debug("#{target_name} target build settings team id: #{current_team_id}")

      unless current_team_id
        # Log.warn("no DEVELOPMENT_TEAM build settings found for target: #{target_name}, checking target attributes...")

        target_attributes = attributes[target.uuid] if attributes
        target_attributes_team_id = target_attributes['DevelopmentTeam'] if target_attributes
        # Log.debug("#{target_name} target attributes team id: #{target_attributes_team_id}")

        unless target_attributes_team_id
          # Log.warn("no DevelopmentTeam target attribute found for target: #{target_name}")
          next
        end

        current_team_id = target_attributes_team_id
      end

      if team_id.nil?
        team_id = current_team_id
        next
      end

      next if team_id == current_team_id

      # Log.warn("target team id: #{current_team_id} does not match to the already registered team id: #{team_id}")
      team_id = nil
      break
    end

    team_id
  end

  private

  def unique_targets(targets)
    names = {}
    targets.reject do |target|
      found = names.key?(target.name)
      names[target.name] = true
      found
    end
  end

  def read_scheme_and_container_project(scheme_name)
    project_paths = [@project_path]
    project_paths += contained_projects if workspace?

    project_paths.each do |project_path|
      schema_path = File.join(project_path, 'xcshareddata', 'xcschemes', scheme_name + '.xcscheme')
      next unless File.exist?(schema_path)

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

      project = Xcodeproj::Project.open(target_project_path)
      target = project.targets.find { |t| t.name == reference.target_name }
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

  def collect_dependent_targets(target, dependent_targets = [])
    dependent_targets << target

    dependencies = target.dependencies || []
    return dependent_targets if dependencies.empty?

    dependencies.each do |dependency|
      dependent_target = dependency.target
      next unless dependent_target
      next unless runnable_target?(dependent_target)

      collect_dependent_targets(dependent_target, dependent_targets)
    end

    dependent_targets
  end

  def target_team_id(target_name)
    settings = xcodebuild_target_build_settings(target_name)
    settings['DEVELOPMENT_TEAM']
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

  def xcodebuild_target_build_settings(target)
    raise 'xcodebuild -showBuildSettings failed: target not specified' if target.to_s.empty?

    settings = @build_settings_by_target[target]
    return settings if settings

    cmd = [
      'xcodebuild',
      '-showBuildSettings',
      '-project',
      "\"#{@targets_container_project_path}\"",
      '-target',
      "\"#{target}\"",
      '-configuration',
      "\"#{@configuration_name}\""
    ].join(' ')

    # Log.debug("$ #{cmd}")
    out = `#{cmd}`
    raise "#{cmd} failed, out: #{out}" unless $CHILD_STATUS.success?

    settings = {}
    lines = out.split(/\n/)
    lines.each do |line|
      line = line.strip
      next unless line.include?(' = ')

      split = line.split(' = ')
      next unless split.length == 2

      value = split[1].strip
      next if value.empty?

      key = split[0].strip
      next if key.empty?

      settings[key] = value
    end

    @build_settings_by_target[target] = settings
    settings
  end
end
