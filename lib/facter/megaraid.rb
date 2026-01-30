# frozen_string_literal: true

#
# megaraid.rb
#
# Author: Wagner Sartori Junior <wsartori@wsartori.com>
#
require 'json'
require 'time'

# Main Megaraid class
class Megaraid
  # Is a megaraid driver present?
  def present?
    Dir.exist?('/sys/bus/pci/drivers/megaraid_sas') || Dir.exist?('/sys/bus/pci/drivers/mpt3sas')
  end

  # where's storcli application
  def storcli
    return @storcli if defined?(@storcli)
    @storcli = nil
    return unless present?

    dmi = Facter.value(:dmi)
    manufacturer = dmi.is_a?(Hash) ? dmi['manufacturer'] : nil
    is_dell = manufacturer.is_a?(String) && manufacturer.include?('Dell')

    storcli_locations =
      if is_dell
        ['perccli64', '/opt/MegaRAID/perccli/perccli64',
         'perccli',   '/opt/MegaRAID/perccli/perccli']
      else
        ['storcli64', '/opt/MegaRAID/storcli/storcli64',
         'storcli',   '/opt/MegaRAID/storcli/storcli']
      end

    storcli_locations.each do |run|
      path = Facter::Util::Resolution.which(run)
      next unless path
      @storcli = path
      break
    end

    @storcli
  end

  # Function to call all get methods
  def all_info
    Dir.chdir('/tmp') do
      controller_info
      pr_info
      cc_info
    end
  end

  # Get controller information
  def controller_info
    @controller_info = {}
    return unless present?
    return unless storcli

    raw = Facter::Util::Resolution.exec("#{storcli} /call show J nolog")
    return unless raw && !raw.empty?

    output = begin
               JSON.parse(raw)
             rescue
               nil
             end
    return unless output.is_a?(Hash)

    output.fetch('Controllers', []).each do |controller|
      next if controller.dig('Command Status', 'Status') == 'Failure'
      id = controller.dig('Command Status', 'Controller')
      next if id.nil?

      @controller_info[id] = controller.fetch('Response Data', {})
    end
  end

  # Get patrol read information
  def pr_info
    @pr_info = {}
    return unless present?
    return unless storcli
    return unless num_controllers.positive?

    raw = Facter::Util::Resolution.exec("#{storcli} /call show patrolread J nolog")
    return unless raw && !raw.empty?

    output = begin
               JSON.parse(raw)
             rescue
               nil
             end
    return unless output.is_a?(Hash)

    output.fetch('Controllers', []).each do |controller|
      pr_properties = {}
      controller_properties = controller.dig('Response Data', 'Controller Properties') || {}

      if controller_properties.empty?
        pr_properties['PR Mode'] = 'Un-supported'
        pr_properties['PR Next Start time'] = 'Un-supported'
      else
        controller_properties.each do |attribute|
          key = attribute['Ctrl_Prop']
          val = attribute['Value']

          case key
          when 'PR Execution Delay',
                 'PR iterations completed',
                 'PR MaxConcurrentPd'
            pr_properties[key] = val.to_i
          when 'PR on SSD'
            pr_properties[key] = (val != 'Disabled')
          when 'PR Next Start time'
            begin
              t = Time.strptime(val, '%m/%d/%Y, %H:%M:%S')
              pr_properties[key] = t.strftime('%A at %H:%M:%S')
            rescue
              pr_properties[key] = val
            end
          else
            pr_properties[key] = val
          end
        end
      end

      id = controller.dig('Command Status', 'Controller')
      @pr_info[id] = pr_properties if id
    end
  end

  # Get consistency check information
  def cc_info
    @cc_info = {}
    return unless present?
    return unless storcli
    return unless num_controllers.positive?

    raw = Facter::Util::Resolution.exec("#{storcli} /call show cc J nolog")
    return unless raw && !raw.empty?

    output = begin
               JSON.parse(raw)
             rescue
               nil
             end
    return unless output.is_a?(Hash)

    output.fetch('Controllers', []).each do |controller|
      cc_properties = {}
      controller_properties =
        controller.dig('Response Data', 'Controller Properties') || {}

      if controller_properties.empty?
        cc_properties['CC Operation Mode'] = 'Un-supported'
        cc_properties['CC Next Starttime'] = 'Un-supported'
      else
        controller_properties.each do |attribute|
          key = attribute['Ctrl_Prop']
          val = attribute['Value']

          case key
          when 'CC Execution Delay',
                 'CC Number of iterations',
                 'CC Number of VD completed'
            cc_properties[key] = val.to_i
          when 'CC Next Starttime'
            begin
              t = Time.strptime(val, '%m/%d/%Y, %H:%M:%S')
              cc_properties[key] = t.strftime('%A at %H:%M:%S')
            rescue
              cc_properties[key] = val
            end
          else
            cc_properties[key] = val
          end
        end
      end

      id = controller.dig('Command Status', 'Controller')
      @cc_info[id] = cc_properties if id
    end
  end

  # Number of controllers
  def num_controllers
    @controller_info.size
  end

  # Parse and returns controllers information
  def controllers_info
    ctrls = {}

    @controller_info.each do |controller, parameters|
      vd = {}

      parameters.fetch('VD LIST', []).each do |item|
        next unless item.key?('DG/VD')

        vd_id = item['DG/VD'].split('/')[1]
        vd[vd_id] = {}

        raw = Facter::Util::Resolution.exec(
          "#{storcli} /c#{controller}/v#{vd_id} show all J nolog",
        )
        next unless raw && !raw.empty?

        vd_json = begin
                    JSON.parse(raw)
                  rescue
                    nil
                  end
        next unless vd_json

        vd_output =
          vd_json.fetch('Controllers', [])[0]
                 &.dig('Response Data', "VD#{vd_id} Properties") || {}

        vd[vd_id]['Type']       = item.fetch('TYPE', nil)
        vd[vd_id]['State']      = item.fetch('State', nil)
        vd[vd_id]['Strip Size'] = vd_output.fetch('Strip Size', nil)

        cache = item['Cache'].to_s.upcase

        vd[vd_id]['Write Cache'] =
          case cache
          when %r{AWB}      then 'awb'
          when %r{\bWB\b}   then 'wb'
          when %r{\bWT\b}   then 'wt'
          else 'unknown'
          end

        if cache.start_with?('R')
          vd[vd_id]['Read Cache'] = 'ra'
        elsif cache.start_with?('NR')
          vd[vd_id]['Read Cache'] = 'nora'
        end

        if cache.end_with?('D')
          vd[vd_id]['IO Policy'] = 'direct'
        elsif cache.end_with?('C')
          vd[vd_id]['IO Policy'] = 'cached'
        end

        pdc = vd_output.fetch('Disk Cache Policy', 'unknown')
        vd[vd_id]['Physical Drive Cache'] =
          case pdc
          when "Disk's Default" then 'default'
          when 'Enabled'        then 'on'
          when 'Disabled'       then 'off'
          else pdc
          end

        vd[vd_id]['Name']       = item.fetch('Name', nil)
        vd[vd_id]['Encryption'] = vd_output.fetch('Encryption', nil)
      end

      ctrls[controller] = {
        'product_name'  => parameters.fetch('Product Name', nil),
        'serial_number' => parameters.fetch('Serial Number', nil),

        'fw_package_build' => parameters.fetch('FW Package Build', nil),
        'fw_version'       => parameters.fetch('FW Version', nil),
        'bios_version'     => parameters.fetch('BIOS Version', nil),

        'virtual_drives'   => vd,
        'patrol_read'      => @pr_info[controller],
        'consistency_check' => @cc_info[controller],
      }
    end

    ctrls
  end

  def all_facts
    storcli
    all_info

    {
      'present?'              => present?,
      'storcli'               => storcli,
      'number_of_controllers' => num_controllers,
      'controllers'           => controllers_info,
    }
  end
end

Facter.add(:megaraid) do
  confine kernel: 'Linux'

  setcode do
    Megaraid.new.all_facts
  end
end
