# frozen_string_literal: true

require 'rspec'
require 'json'
require 'time'
require 'facter'

require_relative '../../../lib/facter/storcli'

describe :storcli, type: :fact do
  subject(:fact) { Facter.fact(:storcli) }

  before :each do
    Facter.clear
  end

  # Discover all fixture directories at test-definition time
  FIXTURE_DIRS = Dir.glob('spec/fixtures/*/').map { |path| File.basename(path) }.sort

  # Parse fixture JSON files for a given fixture directory
  def self.parse_fixture(fixture_name, file)
    path = File.join('spec/fixtures', fixture_name, file)
    return nil unless File.exist?(path)

    JSON.parse(File.read(path))
  rescue JSON::ParserError
    nil
  end

  # Extract expected values from fixture data
  def self.analyze_fixture(fixture_name)
    call_show = parse_fixture(fixture_name, 'storcli_call_show.json')
    pr_data = parse_fixture(fixture_name, 'storcli_call_show_patrolread.json')
    cc_data = parse_fixture(fixture_name, 'storcli_call_show_cc.json')

    return nil unless call_show

    controllers = call_show.fetch('Controllers', [])

    # Extract successful controllers
    successful_controllers = controllers.reject do |ctrl|
      ctrl.dig('Command Status', 'Status') == 'Failure'
    end

    # Extract controller IDs and their data
    controller_info = {}
    successful_controllers.each do |ctrl|
      id = ctrl.dig('Command Status', 'Controller')
      next unless id

      data = ctrl.fetch('Response Data', {})
      controller_info[id] = data
    end

    # Extract VD information per controller
    vd_files = Dir.glob(File.join('spec/fixtures', fixture_name, 'storcli_call_show_vdisk*.json'))
    vd_data = {}
    vd_files.each do |vd_file|
      vd_json = JSON.parse(File.read(vd_file))
      vd_data[File.basename(vd_file)] = vd_json
    rescue JSON::ParserError
      next
    end

    # Determine if this is a Dell PERC fixture
    is_perc = fixture_name.include?('PERC')

    {
      fixture_name: fixture_name,
      is_perc: is_perc,
      num_controllers: controller_info.size,
      controller_info: controller_info,
      pr_data: pr_data,
      cc_data: cc_data,
      vd_data: vd_data,
    }
  end

  # Helper to setup mocks for a fixture
  def setup_fixture_mocks(fixture_info)
    # Mock hardware present
    allow(Dir).to receive(:exist?).and_call_original
    allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)
    allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)

    # Mock Dir.chdir
    allow(Dir).to receive(:chdir).with('/tmp').and_yield

    # Mock DMI for Dell vs non-Dell
    if fixture_info[:is_perc]
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Dell Inc.' })
    else
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })
    end

    # Mock which for appropriate tools
    tool_path = '/example/path'
    if fixture_info[:is_perc]
      allow(Facter::Core::Execution).to receive(:which).with('perccli64').and_return(tool_path)
      allow(Facter::Core::Execution).to receive(:which).with('/opt/MegaRAID/perccli/perccli64').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('perccli').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('/opt/MegaRAID/perccli/perccli').and_return(nil)
    else
      allow(Facter::Core::Execution).to receive(:which).with('storcli64').and_return(tool_path)
      allow(Facter::Core::Execution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('storcli').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)
    end

    # Mock exec calls
    fixture_name = fixture_info[:fixture_name]

    # Pass through any execute calls not matched below (e.g. Facter-internal uname calls)
    allow(Facter::Core::Execution).to receive(:execute).and_call_original

    # Main controller info
    call_show_path = File.join('spec/fixtures', fixture_name, 'storcli_call_show.json')
    allow(Facter::Core::Execution).to receive(:execute).with("#{tool_path} /call show J nolog", on_fail: nil)
                                                       .and_return(File.read(call_show_path))

    # Patrol read info
    pr_path = File.join('spec/fixtures', fixture_name, 'storcli_call_show_patrolread.json')
    if File.exist?(pr_path)
      allow(Facter::Core::Execution).to receive(:execute).with("#{tool_path} /call show patrolread J nolog", on_fail: nil)
                                                         .and_return(File.read(pr_path))
    else
      allow(Facter::Core::Execution).to receive(:execute).with("#{tool_path} /call show patrolread J nolog", on_fail: nil)
                                                         .and_return(nil)
    end

    # Consistency check info
    cc_path = File.join('spec/fixtures', fixture_name, 'storcli_call_show_cc.json')
    if File.exist?(cc_path)
      allow(Facter::Core::Execution).to receive(:execute).with("#{tool_path} /call show cc J nolog", on_fail: nil)
                                                         .and_return(File.read(cc_path))
    else
      allow(Facter::Core::Execution).to receive(:execute).with("#{tool_path} /call show cc J nolog", on_fail: nil)
                                                         .and_return(nil)
    end

    # Controller settings and BBU (no fixtures, return nil)
    allow(Facter::Core::Execution).to receive(:execute).with("#{tool_path} /call show all J nolog", on_fail: nil)
                                                       .and_return(nil)
    allow(Facter::Core::Execution).to receive(:execute).with("#{tool_path} /call show bbu J nolog", on_fail: nil)
                                                       .and_return(nil)

    # Mock VD detail calls
    fixture_info[:controller_info].each do |controller_id, controller_data|
      vd_list = controller_data.fetch('VD LIST', [])
      vd_list.each do |vd_item|
        # Parse VD ID from DG/VD or VD field
        if vd_item.key?('DG/VD')
          _dg_id, vd_id = vd_item['DG/VD'].split('/')
        elsif vd_item.key?('VD')
          vd_id = vd_item['VD'].to_s
        else
          next
        end

        vd_file = "storcli_call_show_vdisk#{vd_id}.json"
        vd_path = File.join('spec/fixtures', fixture_name, vd_file)

        if File.exist?(vd_path)
          allow(Facter::Core::Execution).to receive(:execute)
            .with("#{tool_path} /c#{controller_id}/v#{vd_id} show all J nolog", on_fail: nil)
            .and_return(File.read(vd_path))
        else
          allow(Facter::Core::Execution).to receive(:execute)
            .with("#{tool_path} /c#{controller_id}/v#{vd_id} show all J nolog", on_fail: nil)
            .and_return(nil)
        end
      end
    end
  end

  # Parse schedule time as the fact does
  def parse_schedule_time(val)
    Time.strptime(val, '%m/%d/%Y, %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S')
  rescue StandardError
    val
  end

  #
  # Static edge case tests
  #

  context 'no module present' do
    before :each do
      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(false)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(false)
    end

    it 'returns present false only' do
      expect(fact.value).to eq({ 'present' => false })
    end

    it 'does not call which or exec' do
      expect(Facter::Core::Execution).not_to receive(:which).with(String)
      expect(Facter::Core::Execution).not_to receive(:execute).with(%r{storcli|perccli}, anything)
      fact.value
    end
  end

  context 'module present, no storcli' do
    before :each do
      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })

      allow(Facter::Core::Execution).to receive(:which).with('storcli64').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('storcli').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)
    end

    it 'returns present false only' do
      expect(fact.value).to eq({ 'present' => false })
    end

    it 'does not call exec' do
      expect(Facter::Core::Execution).not_to receive(:execute).with(%r{storcli|perccli}, anything)
      fact.value
    end
  end

  context 'card unsupported (all controllers return Failure)' do
    before :each do
      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
      allow(Dir).to receive(:chdir).with('/tmp').and_yield
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })

      allow(Facter::Core::Execution).to receive(:which).with('storcli64').and_return('/example/path')
      allow(Facter::Core::Execution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('storcli').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)

      allow(Facter::Core::Execution).to receive(:execute).and_call_original
      allow(Facter::Core::Execution).to receive(:execute).with('/example/path /call show J nolog', on_fail: nil)
                                                         .and_return(File.read('spec/fixtures/storcli_call_show_fail.json'))
      allow(Facter::Core::Execution).to receive(:execute).with('/example/path /call show patrolread J nolog', on_fail: nil)
                                                         .and_return(nil)
      allow(Facter::Core::Execution).to receive(:execute).with('/example/path /call show cc J nolog', on_fail: nil)
                                                         .and_return(nil)
    end

    it 'returns present false only' do
      expect(fact.value).to eq({ 'present' => false })
    end
  end

  #
  # Data-driven fixture tests
  #

  FIXTURE_DIRS.each do |fixture_name|
    fixture_info = analyze_fixture(fixture_name)
    next unless fixture_info
    next if fixture_info[:num_controllers].zero?

    context "with fixture: #{fixture_name}" do
      before :each do
        setup_fixture_mocks(fixture_info)
      end

      it 'has correct top-level structure' do
        result = fact.value

        expect(result['present']).to eq(true)
        expect(result['number_of_controllers']).to eq(fixture_info[:num_controllers])
        expect(result['controllers']).to be_a(Hash)
        expect(result['controllers'].size).to eq(fixture_info[:num_controllers])
      end

      it 'does not have storcli_tools or tool_info keys' do
        result = fact.value
        expect(result).not_to have_key('storcli_tools')
        expect(result).not_to have_key('tool_info')
        expect(result).not_to have_key('error')
        expect(result).not_to have_key('storcli_tool')
      end

      fixture_info[:controller_info].each do |controller_id, controller_data|
        context "controller #{controller_id}" do
          let(:controller) do
            result = fact.value
            # Controller IDs in the fact output are strings (Facter serialization)
            result['controllers'][controller_id.to_s]
          end

          it 'has correct metadata' do
            expect(controller).to be_a(Hash)
            expect(controller['product_name']).to eq(controller_data.fetch('Product Name', nil))
            expect(controller['serial_number']).to eq(controller_data.fetch('Serial Number', nil))
            expect(controller['fw_package_build']).to eq(controller_data.fetch('FW Package Build', nil))
            expect(controller['fw_version']).to eq(controller_data.fetch('FW Version', nil))
            expect(controller['bios_version']).to eq(controller_data.fetch('BIOS Version', nil))
            expect(controller['driver_name']).to eq(controller_data.fetch('Driver Name', nil))
            expect(controller['device_interface']).to eq(controller_data.fetch('Device Interface', nil))
            expect(controller['drive_groups_count']).to eq(controller_data.fetch('Drive Groups', nil))
            expect(controller['physical_drive_count']).to eq(controller_data.fetch('Physical Drives', nil))
            expect(controller['storcli_tool']).to eq('/example/path')
          end

          it 'has drive_groups as a Hash' do
            expect(controller['drive_groups']).to be_a(Hash)
          end

          # Test patrol_read structure
          if fixture_info[:pr_data]
            pr_controllers = fixture_info[:pr_data].fetch('Controllers', [])
            pr_ctrl = pr_controllers.find { |c| c.dig('Command Status', 'Controller') == controller_id }

            if pr_ctrl && pr_ctrl.dig('Command Status', 'Status') == 'Success'
              pr_props = pr_ctrl.dig('Response Data', 'Controller Properties') || []

              unless pr_props.empty?
                it 'has patrol_read with new snake_case keys' do
                  expect(controller['patrol_read']).to be_a(Hash)

                  # Verify new keys exist
                  pr = controller['patrol_read']
                  pr_props.each do |attr|
                    case attr['Ctrl_Prop']
                    when 'PR Mode'
                      expect(pr['mode']).to eq(attr['Value'])
                    when 'PR Execution Delay'
                      expect(pr['execution_delay']).to eq(attr['Value'].to_i)
                    when 'PR on SSD'
                      expect(pr['on_ssd']).to eq(attr['Value'] != 'Disabled')
                    when 'PR Next Start time'
                      expected_time = parse_schedule_time(attr['Value'])
                      expect(pr['next_start_time']).to eq(expected_time)
                    end
                  end
                end

                it 'does not have old-style PR keys' do
                  pr = controller['patrol_read']
                  expect(pr).not_to have_key('PR Mode')
                  expect(pr).not_to have_key('PR Current State')
                  expect(pr).not_to have_key('PR iterations completed')
                  expect(pr).not_to have_key('PR Excluded VDs')
                  expect(pr).not_to have_key('PR MaxConcurrentPd')
                  expect(pr).not_to have_key('PR Execution Delay')
                  expect(pr).not_to have_key('PR on SSD')
                  expect(pr).not_to have_key('PR Next Start time')
                end
              end
            else
              it 'does not have patrol_read key (controller does not support it or failed)' do
                expect(controller).not_to have_key('patrol_read')
              end
            end
          end

          # Test consistency_check structure
          if fixture_info[:cc_data]
            cc_controllers = fixture_info[:cc_data].fetch('Controllers', [])
            cc_ctrl = cc_controllers.find { |c| c.dig('Command Status', 'Controller') == controller_id }

            if cc_ctrl && cc_ctrl.dig('Command Status', 'Status') == 'Success'
              cc_props = cc_ctrl.dig('Response Data', 'Controller Properties') || []

              unless cc_props.empty?
                it 'has consistency_check with new snake_case keys' do
                  expect(controller['consistency_check']).to be_a(Hash)

                  # Verify new keys exist
                  cc = controller['consistency_check']
                  cc_props.each do |attr|
                    case attr['Ctrl_Prop']
                    when 'CC Operation Mode'
                      expect(cc['operation_mode']).to eq(attr['Value'])
                    when 'CC Execution Delay'
                      expect(cc['execution_delay']).to eq(attr['Value'].to_i)
                    when 'CC Next Starttime'
                      expected_time = parse_schedule_time(attr['Value'])
                      expect(cc['next_start_time']).to eq(expected_time)
                    end
                  end
                end

                it 'does not have old-style CC keys' do
                  cc = controller['consistency_check']
                  expect(cc).not_to have_key('CC Operation Mode')
                  expect(cc).not_to have_key('CC Current State')
                  expect(cc).not_to have_key('CC Number of iterations')
                  expect(cc).not_to have_key('CC Excluded VDs')
                  expect(cc).not_to have_key('CC Execution Delay')
                  expect(cc).not_to have_key('CC Next Starttime')
                end
              end
            else
              it 'does not have consistency_check key (controller does not support it or failed)' do
                expect(controller).not_to have_key('consistency_check')
              end
            end
          end

          # Test that controller_settings and bbu_info are absent (no fixtures)
          it 'does not have controller_settings (no fixture data)' do
            expect(controller).not_to have_key('controller_settings')
          end

          it 'does not have bbu_info (no fixture data)' do
            expect(controller).not_to have_key('bbu_info')
          end

          # Test virtual disks / drive groups
          vd_list = controller_data.fetch('VD LIST', [])
          if vd_list.any?
            it 'has virtual disks in drive_groups' do
              drive_groups = controller['drive_groups']

              vd_list.each do |vd_item|
                # Parse DG/VD - all IDs are strings in the output
                if vd_item.key?('DG/VD')
                  dg_id, vd_id = vd_item['DG/VD'].split('/')
                elsif vd_item.key?('VD')
                  dg_id = '0'
                  vd_id = vd_item['VD'].to_s
                else
                  next
                end

                # Verify drive group exists
                expect(drive_groups[dg_id]).to be_a(Hash)
                expect(drive_groups[dg_id]['virtual_disks']).to be_a(Hash)

                # Verify VD exists
                vd = drive_groups[dg_id]['virtual_disks'][vd_id]
                expect(vd).to be_a(Hash)

                # Verify VD basic fields
                expect(vd['name']).to eq("/c#{controller_id}/v#{vd_id}")
                expect(vd['raid_level']).to eq(vd_item.fetch('TYPE', nil))
                expect(vd['state']).to eq(vd_item.fetch('State', nil))
                expect(vd['size']).to eq(vd_item.fetch('Size', nil))

                # If we have VD detail fixture, verify properties
                vd_file = "storcli_call_show_vdisk#{vd_id}.json"
                vd_detail_data = fixture_info[:vd_data][vd_file]

                next unless vd_detail_data
                vd_props_data = vd_detail_data.dig('Controllers', 0, 'Response Data', "VD#{vd_id} Properties")

                next unless vd_props_data
                expect(vd['properties']).to be_a(Hash)

                # Verify properties structure
                props = vd['properties']

                # Check stripe_size
                if vd_props_data['Strip Size']
                  expect(props['stripe_size']).to eq(vd_props_data['Strip Size'])
                end

                # Check encryption
                if vd_props_data['Encryption']
                  expect(props['encryption']).to eq(vd_props_data['Encryption'])
                end

                # Check exposed_to_os (converted from Yes/No to boolean)
                if vd_props_data['Exposed to OS']
                  raw = vd_props_data['Exposed to OS']
                  expected = case raw
                             when %r{\AYes\z}i then true
                             when %r{\ANo\z}i then false
                             else raw
                             end
                  expect(props['exposed_to_os']).to eq(expected)
                end

                # Check data_protection (stays as string — tri-state: None/Disabled/Enabled)
                if vd_props_data['Data Protection']
                  expect(props['data_protection']).to eq(vd_props_data['Data Protection'])
                end

                # Check disk_cache_policy normalization
                if vd_props_data['Disk Cache Policy']
                  disk_cache = vd_props_data['Disk Cache Policy']
                  normalized = case disk_cache
                               when "Disk's Default" then 'default'
                               when 'Enabled' then 'on'
                               when 'Disabled' then 'off'
                               else disk_cache
                               end
                  expect(props['disk_cache_policy']).to eq(normalized)
                end

                # Verify write and read policies are derived from Cache string
                # Cache format is like "RWBD", "NRWTD", "RFWBC", "RAWBD", etc.
                # Write: AWB=AlwaysWriteBack, WB=WriteBack, WT=WriteThrough
                # Read: R=ReadAhead, NR=ReadAheadNone (NR must be checked before R)
                # IO: D=Direct, C=Cached
                cache_str = vd_item['Cache']
                next unless cache_str
                # Validate write policy - AWB must be checked before WB
                if cache_str.include?('AWB')
                  expect(props['current_write_policy']).to eq('AlwaysWriteBack')
                elsif cache_str.include?('WB')
                  expect(props['current_write_policy']).to eq('WriteBack')
                elsif cache_str.include?('WT')
                  expect(props['current_write_policy']).to eq('WriteThrough')
                end

                # Validate read policy - NR must be checked before R
                if cache_str.start_with?('NR')
                  expect(props['current_read_policy']).to eq('ReadAheadNone')
                elsif cache_str.start_with?('R')
                  expect(props['current_read_policy']).to eq('ReadAhead')
                end

                # Validate IO policy
                if cache_str.end_with?('D')
                  expect(props['io_policy']).to eq('Direct')
                elsif cache_str.end_with?('C')
                  expect(props['io_policy']).to eq('Cached')
                end
              end
            end
          else
            it 'has empty drive_groups (no VDs)' do
              expect(controller['drive_groups']).to eq({})
            end
          end
        end
      end
    end
  end

  describe 'Storcli helper methods' do
    let(:storcli) { Storcli.new }

    describe '#to_snake_case' do
      {
        'Rebuild Rate'        => 'rebuild_rate',
        'Patrol Read Rate'    => 'patrol_read_rate',
        'AutoRebuild'         => 'auto_rebuild',
        'NCQ'                 => 'ncq',
        'SmartPollInterval'   => 'smart_poll_interval',
        'PR Mode'             => 'pr_mode',
        'CC Next Starttime'   => 'cc_next_starttime',
        'Boot With Pinned Cache' => 'boot_with_pinned_cache',
        'Cache Flush Interval'   => 'cache_flush_interval',
        'Perf Mode' => 'perf_mode',
      }.each do |input, expected|
        it "converts '#{input}' to '#{expected}'" do
          expect(storcli.send(:to_snake_case, input)).to eq(expected)
        end
      end
    end

    describe '#coerce_setting_value' do
      it 'converts numeric strings to integers' do
        expect(storcli.send(:coerce_setting_value, '60')).to eq(60)
      end

      it 'converts On to true' do
        expect(storcli.send(:coerce_setting_value, 'On')).to eq(true)
      end

      it 'converts Off to false' do
        expect(storcli.send(:coerce_setting_value, 'Off')).to eq(false)
      end

      it 'converts Enabled to true' do
        expect(storcli.send(:coerce_setting_value, 'Enabled')).to eq(true)
      end

      it 'converts Disabled to false' do
        expect(storcli.send(:coerce_setting_value, 'Disabled')).to eq(false)
      end

      it 'preserves other strings as-is' do
        expect(storcli.send(:coerce_setting_value, 'RAID5')).to eq('RAID5')
      end

      it 'returns nil for nil input' do
        expect(storcli.send(:coerce_setting_value, nil)).to be_nil
      end
    end
  end
end
