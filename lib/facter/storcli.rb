# frozen_string_literal: true

# storcli.rb — Facter structured fact for MegaRAID / Dell PERC storcli controllers
#
# Returns $facts['storcli'] as a hash. If no controller is present, or if
# collection times out, returns a minimal hash with 'present' => false.
#
# Fact structure (keys are absent when not applicable):
#
#   storcli:
#     present:               bool
#     number_of_controllers: int
#     controllers:
#       <id>:
#         product_name, serial_number, fw_*, bios_version,
#         driver_name, device_interface, drive_groups_count,
#         physical_drive_count, storcli_tool
#         drive_groups:
#           <dg_id>:
#             virtual_disks:
#               <vd_id>: { name, raid_level, size, state, properties: {...} }
#         controller_settings: { <Ctrl_Prop key> => value, ... }
#         bbu_info:           { state, type, replacement_needed, learn_cycle_active }
#         patrol_read:        { mode, execution_delay, on_ssd, next_start_time }
#         consistency_check:  { operation_mode, execution_delay, next_start_time }
#
# Design notes:
#  - PERC cards are assumed to only appear in Dell hardware and vice versa.
#
# Authors:
#   Wagner Sartori Junior <wsartori@wsartori.com>
#   Pat Riehecky <riehecky@fnal.gov>

require 'json'
require 'time'
require 'timeout'

# Main class for MegaRAID storcli fact collection
class Storcli
  # @return [String] sysfs path used to detect MegaRAID SAS hardware
  MEGARAID_SAS_DRIVER_PATH = '/sys/bus/pci/drivers/megaraid_sas' unless defined?(MEGARAID_SAS_DRIVER_PATH)
  # @return [String] sysfs path used to detect MPT3SAS hardware
  MPT3SAS_DRIVER_PATH = '/sys/bus/pci/drivers/mpt3sas' unless defined?(MPT3SAS_DRIVER_PATH)
  # @return [Integer] timeout in seconds for storcli command execution
  STORCLI_TIMEOUT = 60 unless defined?(STORCLI_TIMEOUT)

  # Hardware presence detection
  def present?
    Dir.exist?(MEGARAID_SAS_DRIVER_PATH) || Dir.exist?(MPT3SAS_DRIVER_PATH)
  end

  # CLI tool discovery
  def storcli_tools
    return @storcli_tools if defined?(@storcli_tools)

    @storcli_tools = []
    return @storcli_tools unless present?

    is_dell = Facter.value(:dmi)&.dig('manufacturer')&.include?('Dell') || false
    candidates = is_dell ? perccli_candidates : storcli_candidates

    # Deduplicate paths in case symlinks point to the same binary
    seen_paths = {}
    candidates.each do |name|
      path = Facter::Core::Execution.which(name)
      next unless path
      next if seen_paths[path]

      seen_paths[path] = true
      @storcli_tools << path
    end

    @storcli_tools
  end

  # Low-level exec helpers

  # Runs `tool args` and returns the parsed JSON, or nil on empty output or
  # parse failure. Parse errors are logged at debug level so they appear with
  # `facter --debug` without cluttering normal Puppet runs.
  def exec_json(tool, args)
    raw = Dir.chdir('/tmp') { Facter::Core::Execution.execute("#{tool} #{args} J nolog", on_fail: nil) }
    return nil unless raw && !raw.empty?

    JSON.parse(raw)
  rescue JSON::ParserError => e
    Facter.debug("storcli: JSON parse error from `#{tool} #{args}`: #{e.message}")
    nil
  end

  # Yields (tool, controller_hash) for every controller entry returned across
  # all discovered CLI tools for the given storcli argument string.
  #
  # Centralises the repetitive pattern that every collector needs:
  #   storcli_tools.each → exec_json → output['Controllers'].each
  def each_controller_response(args)
    storcli_tools.each do |tool|
      output = exec_json(tool, args)
      next unless output.is_a?(Hash)

      output.fetch('Controllers', []).each { |ctrl| yield tool, ctrl }
    end
  end

  # Per-controller data collectors

  # Populates @controller_info: a hash keyed by controller ID whose values are
  # the raw 'Response Data' hashes with '_storcli_tool' appended.
  def collect_controller_info
    @controller_info = {}

    each_controller_response('/call show') do |tool, controller|
      next if controller.dig('Command Status', 'Status') == 'Failure'

      id = controller.dig('Command Status', 'Controller')
      next unless id

      data = controller.fetch('Response Data', {})
      data['_storcli_tool'] = tool
      @controller_info[id] = data
    end
  end

  # Safe accessor for controller count; returns 0 before collect_controller_info runs.
  def num_controllers
    (@controller_info || {}).size
  end

  # Parses a storcli schedule time string ("MM/DD/YYYY, HH:MM:SS") into a
  # standard format ("YYYY-MM-DD HH:MM:SS").
  # Falls back to the original string if parsing fails so data is never silently lost.
  def parse_schedule_time(val)
    Time.strptime(val, '%m/%d/%Y, %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S')
  rescue StandardError
    val
  end

  # Populates @pr_info: patrol read schedule keyed by controller ID.
  def collect_pr_info
    @pr_info = {}
    return unless num_controllers.positive?

    each_controller_response('/call show patrolread') do |_tool, controller|
      id = controller.dig('Command Status', 'Controller')
      next unless id

      props = controller.dig('Response Data', 'Controller Properties') || []
      next if props.empty? # controller does not support patrol read

      pr = extract_patrol_read_properties(props)
      @pr_info[id] = pr unless pr.empty?
    end
  end

  # Populates @cc_info: consistency check schedule keyed by controller ID.
  def collect_cc_info
    @cc_info = {}
    return unless num_controllers.positive?

    each_controller_response('/call show cc') do |_tool, controller|
      id = controller.dig('Command Status', 'Controller')
      next unless id

      props = controller.dig('Response Data', 'Controller Properties') || []
      next if props.empty?

      cc = extract_consistency_check_properties(props)
      @cc_info[id] = cc unless cc.empty?
    end
  end

  # Populates @controller_settings_info: all controller properties keyed
  # by controller ID. Keys are converted to snake_case, numeric strings are
  # coerced to integers, and On/Off/Enabled/Disabled strings become booleans.
  def collect_controller_settings
    @controller_settings_info = {}
    return unless num_controllers.positive?

    each_controller_response('/call show all') do |_tool, controller|
      id = controller.dig('Command Status', 'Controller')
      next unless id

      settings = {}
      props = controller.dig('Response Data', 'Controller Properties') || []
      props.each do |attr|
        key = to_snake_case(attr['Ctrl_Prop'])
        val = attr['Value']
        settings[key] = coerce_setting_value(val)
      end

      @controller_settings_info[id] = settings unless settings.empty?
    end
  end

  # Populates @bbu_info: battery backup unit state keyed by controller ID.
  def collect_bbu_info
    @bbu_info = {}
    return unless num_controllers.positive?

    each_controller_response('/call show bbu') do |_tool, controller|
      id = controller.dig('Command Status', 'Controller')
      next unless id

      # Key name varies between storcli versions: 'BBU_Info' (newer) vs 'BBU Info' (older)
      bbu_raw = controller.dig('Response Data', 'BBU_Info') ||
                controller.dig('Response Data', 'BBU Info')
      next unless bbu_raw && !bbu_raw.empty?

      @bbu_info[id] = {
        'state'              => bbu_raw.fetch('State', 'Unknown'),
        # 'Model' in newer storcli; 'Type' in older storcli
        'type'               => bbu_raw.fetch('Model', nil) || bbu_raw.fetch('Type', 'BBU'),
        'replacement_needed' => bbu_raw.fetch('Battery Replacement required', 'No') == 'Yes',
        'learn_cycle_active' => bbu_raw.fetch('Learn Cycle Requested', 'No') != 'No',
      }
    end
  end

  # Virtual disk / drive group assembly

  # Parses the compact 'Cache' token from the VD LIST entry into discrete
  # policy symbols. Cache strings follow pattern: [R|NR][AWB|WB|WT][D|C]
  # Examples: RWBD, NRWTD, RAWBC
  def parse_cache_string(cache)
    return {} unless cache

    c = cache.to_s.upcase

    # Order matters: AWB must be checked before WB
    write = if c.include?('AWB')
              'awb'
            elsif c.include?('WB')
              'wb'
            elsif c.include?('WT')
              'wt'
            end

    # NR must be tested before R to avoid false matches
    read = if c.start_with?('NR')
             'nora'
           elsif c.start_with?('R')
             'ra'
           end

    io = if c.end_with?('D')
           'Direct'
         elsif c.end_with?('C')
           'Cached'
         end

    { write: write, read: read, io: io }.compact
  end

  # Queries per-VD detail and assembles the drive_groups subtree for one
  # controller. Returns { dg_id => { 'virtual_disks' => { vd_id => {...} } } }.
  def build_drive_groups(controller_id, tool, vd_list)
    drive_groups = {}

    vd_list.each do |item|
      dg_id, vd_id = extract_vd_identifiers(item)
      next unless dg_id && vd_id

      drive_groups[dg_id] ||= { 'virtual_disks' => {} }
      drive_groups[dg_id]['virtual_disks'][vd_id] = build_virtual_disk(controller_id, vd_id, item, tool)
    end

    drive_groups
  end

  # Top-level fact assembly
  def all_facts
    return { 'present' => false } unless present?

    collect_controller_info
    collect_pr_info
    collect_cc_info
    collect_controller_settings
    collect_bbu_info

    return { 'present' => false } if num_controllers.zero?

    {
      'present'               => true,
      'number_of_controllers' => num_controllers,
      'controllers'           => build_controllers_hash,
    }
  end

  private

  # Returns list of perccli tool candidates
  def perccli_candidates
    [
      'perccli64',
      '/opt/MegaRAID/perccli/perccli64',
      'perccli',
      '/opt/MegaRAID/perccli/perccli',
    ]
  end

  # Returns list of storcli tool candidates
  def storcli_candidates
    [
      'storcli64',
      '/opt/MegaRAID/storcli/storcli64',
      'storcli',
      '/opt/MegaRAID/storcli/storcli',
    ]
  end

  # Extract patrol read properties from controller properties array
  def extract_patrol_read_properties(props)
    pr = {}
    props.each do |attr|
      case attr['Ctrl_Prop']
      when 'PR Mode'            then pr['mode']            = attr['Value']
      when 'PR Execution Delay' then pr['execution_delay'] = attr['Value'].to_i
      when 'PR on SSD'          then pr['on_ssd']          = (attr['Value'] != 'Disabled')
      when 'PR Next Start time' then pr['next_start_time'] = parse_schedule_time(attr['Value'])
      end
    end
    pr
  end

  # Extract consistency check properties from controller properties array
  def extract_consistency_check_properties(props)
    cc = {}
    props.each do |attr|
      case attr['Ctrl_Prop']
      when 'CC Operation Mode'  then cc['operation_mode']  = attr['Value']
      when 'CC Execution Delay' then cc['execution_delay'] = attr['Value'].to_i
      when 'CC Next Starttime'  then cc['next_start_time'] = parse_schedule_time(attr['Value'])
      end
    end
    cc
  end

  # Attempts to convert a value to integer, returns original value if conversion fails
  def coerce_to_integer(val)
    Integer(val, 10)
  rescue ArgumentError
    val
  end

  # Converts 'Yes'/'No' strings to true/false booleans.
  # Returns nil for nil input (so .compact can strip it).
  # Returns the original string for values that are neither 'Yes' nor 'No'
  # (e.g. 'N/A').
  def yes_no_to_bool(val)
    return nil if val.nil?

    case val.to_s
    when %r{\AYes\z}i  then true
    when %r{\ANo\z}i   then false
    else val
    end
  end

  # Converts a storcli Ctrl_Prop key to snake_case.
  # Examples: 'Rebuild Rate' → 'rebuild_rate', 'AutoRebuild' → 'auto_rebuild',
  #           'PR Mode' → 'pr_mode', 'CC Next Starttime' → 'cc_next_starttime'
  def to_snake_case(str)
    str.gsub(%r{([a-z\d])([A-Z])}, '\1_\2') # camelCase boundaries
       .gsub(%r{([A-Z]+)([A-Z][a-z])}, '\1_\2') # ABCDef → ABC_Def
       .tr(' ', '_').squeeze('_') # collapse multiple underscores
       .downcase
  end

  # Coerce a controller setting value: try integer first, then On/Off and
  # Enabled/Disabled to boolean, otherwise return the original string.
  def coerce_setting_value(val)
    return val if val.nil?

    # Try integer first
    int_val = coerce_to_integer(val)
    return int_val if int_val.is_a?(Integer)

    # Try boolean coercion for common storcli toggle strings
    case val.to_s
    when %r{\AOn\z}i       then true
    when %r{\AOff\z}i      then false
    when %r{\AEnabled\z}i  then true
    when %r{\ADisabled\z}i then false
    else val
    end
  end

  # Extract drive group and virtual disk identifiers from VD list item
  # Returns [dg_id, vd_id] or [nil, nil] if not found
  def extract_vd_identifiers(item)
    if item.key?('DG/VD')
      # Newer storcli uses 'DG/VD' (e.g. "0/0")
      item['DG/VD'].split('/')
    elsif item.key?('VD')
      # Older storcli uses plain 'VD'
      ['0', item['VD'].to_s]
    else
      [nil, nil]
    end
  end

  # Build a virtual disk hash from VD list item and detailed properties
  def build_virtual_disk(controller_id, vd_id, item, tool)
    vd_detail = exec_json(tool, "/c#{controller_id}/v#{vd_id} show all")
    controllers = vd_detail&.fetch('Controllers', [])
    vd_props    = controllers&.first
                             &.dig('Response Data', "VD#{vd_id} Properties") || {}

    cache = parse_cache_string(item['Cache'])

    vd = {
      'name'          => "/c#{controller_id}/v#{vd_id}",
      'raid_level'    => item.fetch('TYPE', nil),
      'state'         => item.fetch('State', nil),
      'size'          => item.fetch('Size', nil),
      'os_drive_name' => item.fetch('OS Drive Name', nil),
    }

    properties = build_vd_properties(vd_props, cache)
    vd['properties'] = properties unless properties.empty?

    vd
  end

  # Build virtual disk properties hash
  def build_vd_properties(vd_props, cache)
    {
      'stripe_size'               => vd_props.fetch('Strip Size', nil),
      'span_depth'                => vd_props.fetch('Span Depth', nil),
      'number_of_drives_per_span' => vd_props.fetch('Number of Drives Per Span', nil),
      'current_write_policy'      => map_write_policy(cache[:write]),
      'current_read_policy'       => map_read_policy(cache[:read]),
      'io_policy'                 => cache[:io],
      'disk_cache_policy'         => normalize_disk_cache_policy(vd_props.fetch('Disk Cache Policy', nil)),
      'is_vd_boot_drive'          => yes_no_to_bool(vd_props.fetch('Is LD Ready for OS Requests', nil)),
      'encryption'                => vd_props.fetch('Encryption', nil),
      'exposed_to_os'             => yes_no_to_bool(vd_props.fetch('Exposed to OS', nil)),
      'unmap_enabled'             => yes_no_to_bool(vd_props.fetch('Unmap Enabled', nil)),
      'data_protection'           => vd_props.fetch('Data Protection', nil),
    }.compact
  end

  # Map cache token to write policy name
  def map_write_policy(token)
    case token
    when 'awb' then 'AlwaysWriteBack'
    when 'wb'  then 'WriteBack'
    when 'wt'  then 'WriteThrough'
    end
  end

  # Map cache token to read policy name
  def map_read_policy(token)
    (token == 'ra') ? 'ReadAhead' : 'ReadAheadNone'
  end

  # Normalize disk cache policy to short tokens
  def normalize_disk_cache_policy(policy)
    case policy
    when "Disk's Default" then 'default'
    when 'Enabled'        then 'on'
    when 'Disabled'       then 'off'
    else policy
    end
  end

  # Build the controllers hash for the fact output
  def build_controllers_hash
    controllers = {}
    @controller_info.each do |id, params|
      tool = params.fetch('_storcli_tool', storcli_tools.first)
      drive_groups = build_drive_groups(id, tool, params.fetch('VD LIST', []))

      controllers[id] = {
        'product_name'         => params.fetch('Product Name', nil),
        'serial_number'        => params.fetch('Serial Number', nil),
        'fw_package_build'     => params.fetch('FW Package Build', nil),
        'fw_version'           => params.fetch('FW Version', nil),
        'bios_version'         => params.fetch('BIOS Version', nil),
        'driver_name'          => params.fetch('Driver Name', nil),
        'device_interface'     => params.fetch('Device Interface', nil),
        'drive_groups_count'   => params.fetch('Drive Groups', nil),
        'physical_drive_count' => params.fetch('Physical Drives', nil),
        'storcli_tool'         => tool,
        'drive_groups'         => drive_groups,
        'controller_settings'  => @controller_settings_info[id],
        'bbu_info'             => @bbu_info[id],
        'patrol_read'          => @pr_info[id],
        'consistency_check'    => @cc_info[id],
      }.compact
    end
    controllers
  end
end

# Register fact
Facter.add(:storcli) do
  confine kernel: 'Linux'

  setcode do
    # Guard against storcli hanging on degraded or failed hardware.
    # 60 s is generous for a heavily-loaded system with many VDs.
    Timeout.timeout(Storcli::STORCLI_TIMEOUT) do
      Storcli.new.all_facts
    end
  rescue Timeout::Error
    Facter.warn("storcli: fact collection timed out after #{Storcli::STORCLI_TIMEOUT} seconds")
    { 'present' => false, 'error' => 'timeout' }
  rescue StandardError => e
    Facter.warn("storcli: fact collection failed: #{e.message}")
    { 'present' => false, 'error' => e.message }
  end
end
