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
    @storcli = nil
    return unless present?
    manufacturer = Facter.value(:dmi)['manufacturer']
    storcli_locations = if manufacturer.include? 'Dell'
                          ['perccli64', '/opt/MegaRAID/perccli/perccli64', 'perccli', '/opt/MegaRAID/perccli/perccli']
                        else
                          ['storcli64', '/opt/MegaRAID/storcli/storcli64', 'storcli', '/opt/MegaRAID/storcli/storcli']
                        end

    storcli_locations.each do |run|
      @storcli = Facter::Util::Resolution.which(run)
      next if @storcli.nil?
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
    return unless @storcli
    output = JSON.parse(Facter::Util::Resolution.exec("#{@storcli} /call show J nolog"))
    output.fetch('Controllers').each do |controller|
      if controller.dig('Command Status', 'Status') != 'Failure'
        @controller_info[controller.dig('Command Status', 'Controller')] = controller.fetch('Response Data', {})
      end
    end
  end

  # Get patrol read information
  def pr_info
    @pr_info = {}
    return unless present?
    return unless @storcli
    return unless num_controllers > 0
    output = JSON.parse(Facter::Util::Resolution.exec("#{@storcli} /call show patrolread J nolog"))
    # this command will return the properties in pairs, transforming into key/value
    output.fetch('Controllers').each do |controller|
      pr_properties = {}
      controller_properties = controller.dig('Response Data', 'Controller Properties') || {}
      if controller_properties.empty?
        pr_properties['PR Mode'] = 'Un-supported'
        pr_properties['PR Next Start time'] = 'Un-supported'
      else
        controller_properties.each do |attribute|
          # Let's parse some attributes
          case attribute['Ctrl_Prop']
          when 'PR Execution Delay', 'PR iterations completed', 'PR MaxConcurrentPd'
            pr_properties[attribute['Ctrl_Prop']] = attribute['Value'].to_i
          when 'PR on SSD'
            pr_properties[attribute['Ctrl_Prop']] = if attribute['Value'] == 'Disabled'
                                                      false
                                                    else
                                                      true
                                                    end
          when 'PR Next Start time'
            next_start_time = Time.strptime(attribute['Value'], '%m/%d/%Y, %H:%M:%S')
            pr_properties[attribute['Ctrl_Prop']] = next_start_time.strftime('%A at %H:%M:%S')
          else
            pr_properties[attribute['Ctrl_Prop']] = attribute['Value']
          end
        end
      end
      @pr_info[controller.dig('Command Status', 'Controller')] = pr_properties
    end
  end

  # Get consistency check information
  def cc_info
    @cc_info = {}
    return unless present?
    return unless @storcli
    return unless num_controllers > 0
    output = JSON.parse(Facter::Util::Resolution.exec("#{@storcli} /call show cc J nolog"))
    # this command will return the properties in pairs, transforming into key/value
    output.fetch('Controllers').each do |controller|
      cc_properties = {}
      controller_properties = controller.dig('Response Data', 'Controller Properties') || {}
      if controller_properties.empty?
        cc_properties['CC Operation Mode'] = 'Un-supported'
        cc_properties['CC Next Starttime'] = 'Un-supported'
      else
        controller_properties.each do |attribute|
          # Let's parse some attributes
          case attribute['Ctrl_Prop']
          when 'CC Execution Delay', 'CC Number of iterations', 'CC Number of VD completed'
            cc_properties[attribute['Ctrl_Prop']] = attribute['Value'].to_i
          when 'CC Next Starttime'
            next_start_time = Time.strptime(attribute['Value'], '%m/%d/%Y, %H:%M:%S')
            cc_properties[attribute['Ctrl_Prop']] = next_start_time.strftime('%A at %H:%M:%S')
          else
            cc_properties[attribute['Ctrl_Prop']] = attribute['Value']
          end
        end
      end
      @cc_info[controller.dig('Command Status', 'Controller')] = cc_properties
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

        vd_output = JSON.parse(Facter::Util::Resolution.exec("#{@storcli} /c#{controller}/v#{vd_id} show all J nolog")).fetch('Controllers')[0].dig('Response Data', "VD#{vd_id} Properties")
        vd[vd_id]['Type'] = item.fetch('TYPE')
        vd[vd_id]['State'] = item.fetch('State')
        vd[vd_id]['Strip Size'] = vd_output.fetch('Strip Size')

        if item['Cache'].include?('AWB')
          vd[vd_id]['Write Cache'] = 'awb'
        elsif item['Cache'].include?('WB')
          vd[vd_id]['Write Cache'] = 'wb'
        elsif item['Cache'].include?('WT')
          vd[vd_id]['Write Cache'] = 'wt'
        end

        if item['Cache'].start_with?('R')
          vd[vd_id]['Read Cache'] = 'ra'
        elsif item['Cache'].start_with?('NR')
          vd[vd_id]['Read Cache'] = 'nora'
        end

        if item['Cache'].end_with?('D')
          vd[vd_id]['IO Policy'] = 'direct'
        elsif item['Cache'].end_with?('C')
          vd[vd_id]['IO Policy'] = 'cached'
        end

        vd[vd_id]['Physical Drive Cache'] = vd_output.fetch('Disk Cache Policy', '')
        if vd[vd_id]['Physical Drive Cache'] == 'Disk\'s Default'
          vd[vd_id]['Physical Drive Cache'] = 'default'
        elsif vd[vd_id]['Physical Drive Cache'] == 'Enabled'
          vd[vd_id]['Physical Drive Cache'] = 'on'
        elsif vd[vd_id]['Physical Drive Cache'] == 'Disabled'
          vd[vd_id]['Physical Drive Cache'] = 'off'
        end

        vd[vd_id]['Name'] = item.fetch('Name', '')
        vd[vd_id]['Encryption'] = vd_output.fetch('Encryption', '')
      end

      ctrls[controller] = {
        # Basics
        'product_name'  => parameters.fetch('Product Name'),
        'serial_number' => parameters.fetch('Serial Number'),

        # Version
        'fw_package_build' => parameters.fetch('FW Package Build'),
        'fw_version'       => parameters.fetch('FW Version'),
        'bios_version'     => parameters.fetch('BIOS Version'),

        # virtual drives
        'virtual_drives'   => vd,

        # Patrol Read
        'patrol_read' => @pr_info[controller],

        # Consistency Check
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
    megaraid = Megaraid.new
    megaraid.all_facts
  end
end
