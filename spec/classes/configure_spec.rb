# frozen_string_literal: true

require 'spec_helper'

describe 'storcli::configure' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'without storcli' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => nil, 'controllers' => {} } }) }

        it { is_expected.to compile }
        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'without storcli, with management' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => nil, 'controllers' => {} } }) }
        let(:params) do
          {
            'configure_settings' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'with storcli, no management' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => {} } }) }
        let(:params) do
          {
            'configure_settings' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'with storcli, and management of config - defaults' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
          }
        end

        it { is_expected.to compile }
        # mostly just check that it has a LOT of resources, specific checks come later
        it { is_expected.to have_exec_resource_count(34) }
      end

      context 'with storcli, and management of config - autorebuild = true' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_autorebuild' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable autorebuild on MegaRAID controller /c1') }
        it { is_expected.not_to contain_exec('Disable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Disable autorebuild on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - autorebuild = false' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_autorebuild' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable autorebuild on MegaRAID controller /c1') }
        it { is_expected.to contain_exec('Disable autorebuild on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable autorebuild on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - rebuildrate=50' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_rebuildrate' => 50,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Set rebuildrate=50% on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set rebuildrate=50% on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - sync_time_to_controllers = false' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'sync_time_to_controllers' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.not_to contain_exec('Set time on MegaRAID controller /c1 to UTC') }
        it { is_expected.not_to contain_exec('Set time on MegaRAID controller /c0 to local time') }
        it { is_expected.not_to contain_exec('Set time on MegaRAID controller /c1 to local time') }
      end

      context 'with storcli, and management of config - sync_time_to_controllers = true, use UTC' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'sync_time_to_controllers' => true,
            'controller_use_utc' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.to contain_exec('Set time on MegaRAID controller /c1 to UTC') }
        it { is_expected.not_to contain_exec('Set time on MegaRAID controller /c0 to local time') }
        it { is_expected.not_to contain_exec('Set time on MegaRAID controller /c1 to local time') }
      end

      context 'with storcli, and management of config - sync_time_to_controllers = true, use local time' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'sync_time_to_controllers' => true,
            'controller_use_utc' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.not_to contain_exec('Set time on MegaRAID controller /c1 to UTC') }
        it { is_expected.to contain_exec('Set time on MegaRAID controller /c0 to local time') }
        it { is_expected.to contain_exec('Set time on MegaRAID controller /c1 to local time') }
      end

      context 'with storcli, and management of config - perfmode=0' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_perfmode' => 0,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Set perfmode=0 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set perfmode=0 on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - controller_ncq = true' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_ncq' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable NCQ on MegaRAID controller /c1') }
        it { is_expected.not_to contain_exec('Disable NCQ on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Disable NCQ on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - controller_ncq = false' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_ncq' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable NCQ on MegaRAID controller /c1') }
        it { is_expected.to contain_exec('Disable NCQ on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable NCQ on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - cacheflushinterval=5' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_cacheflushinterval' => 5,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Set cacheflushinterval=5 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set cacheflushinterval=5 on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - controller_bootwithpinnedcache = true' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_bootwithpinnedcache' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Enable bootwithpinnedcache on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable bootwithpinnedcache on MegaRAID controller /c1') }
        it { is_expected.not_to contain_exec('Disable bootwithpinnedcache on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Disable bootwithpinnedcache on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - controller_bootwithpinnedcache = false' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_bootwithpinnedcache' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Enable bootwithpinnedcache on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable bootwithpinnedcache on MegaRAID controller /c1') }
        it { is_expected.to contain_exec('Disable bootwithpinnedcache on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable bootwithpinnedcache on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - controller_alarm = true' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_alarm' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Enable alarm sound on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable alarm sound on MegaRAID controller /c1') }
        it { is_expected.not_to contain_exec('Disable alarm sound on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Disable alarm sound on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - controller_alarm = false' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_alarm' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Enable alarm sound on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable alarm sound on MegaRAID controller /c1') }
        it { is_expected.to contain_exec('Disable alarm sound on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable alarm sound on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - smartpollinterval=5' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {}, 1 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_smartpollinterval' => 5,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Set smartpollinterval=5 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set smartpollinterval=5 on MegaRAID controller /c1') }
      end

      context 'with storcli, and management of config - controller_patrolread_mode=off' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_patrolread_mode' => 'off',
            'controller_patrolread_delay' => 10,
            'controller_patrolread_rate' => 11,
            'controller_patrolread_includessds' => false,
            'controller_patrolread_uncfgareas' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Disable patrolread on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable patrolread mode=off on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enagle patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'with storcli, and management of config - controller_patrolread_mode=auto' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_patrolread_mode' => 'auto',
            'controller_patrolread_delay' => 10,
            'controller_patrolread_rate' => 11,
            'controller_patrolread_includessds' => false,
            'controller_patrolread_uncfgareas' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Disable patrolread on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable patrolread mode=auto on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'with storcli, and management of config - controller_patrolread_mode=manual' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_patrolread_mode' => 'manual',
            'controller_patrolread_delay' => 10,
            'controller_patrolread_rate' => 11,
            'controller_patrolread_includessds' => false,
            'controller_patrolread_uncfgareas' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Disable patrolread on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable patrolread mode=manual on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'with storcli, and management of config - controller_patrolread_includessds=true' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_patrolread_mode' => 'manual',
            'controller_patrolread_delay' => 10,
            'controller_patrolread_rate' => 11,
            'controller_patrolread_includessds' => true,
            'controller_patrolread_uncfgareas' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Disable patrolread on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable patrolread mode=manual on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'with storcli, and management of config - controller_patrolread_uncfgareas=true' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_patrolread_mode' => 'manual',
            'controller_patrolread_delay' => 10,
            'controller_patrolread_rate' => 11,
            'controller_patrolread_includessds' => false,
            'controller_patrolread_uncfgareas' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Disable patrolread on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable patrolread mode=manual on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'with storcli, and management of config - controller_consistencycheck_mode=off' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_consistencycheck_mode' => 'off',
            'controller_consistencycheck_delay' => 10,
            'controller_consistencycheck_rate' => 11,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Disable consistency check on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Enable consistency check mode=off on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Set consistency check delay=10 on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('Set consistency check rate=11% on MegaRAID controller /c0') }
      end

      context 'with storcli, and management of config - controller_consistencycheck_mode=seq' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_consistencycheck_mode' => 'seq',
            'controller_consistencycheck_delay' => 10,
            'controller_consistencycheck_rate' => 11,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Disable consistency check on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable consistency check mode=seq on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set consistency check delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set consistency check rate=11% on MegaRAID controller /c0') }
      end

      context 'with storcli, and management of config - controller_consistencycheck_mode=conc' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => { 0 => {} } } }) }
        let(:params) do
          {
            'configure_settings' => true,
            'controller_consistencycheck_mode' => 'conc',
            'controller_consistencycheck_delay' => 10,
            'controller_consistencycheck_rate' => 11,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('Disable consistency check on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Enable consistency check mode=conc on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set consistency check delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('Set consistency check rate=11% on MegaRAID controller /c0') }
      end
    end
  end
end
