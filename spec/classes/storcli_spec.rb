require 'spec_helper'

describe 'storcli' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'with card detected' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'number_of_controllers' => 0,
                             'controllers' => {},
                           },
                         })
        end

        it { is_expected.to compile }

        it { is_expected.to contain_class('storcli::install') }

        describe 'storcli::install' do
          let(:params) { { package_ensure: 'present', package_name: ['storcli'] } }

          it {
            is_expected.to contain_package('storcli').with(
              ensure: 'present',
            )
          }

          describe 'should allow package ensure to be overridden' do
            let(:params) { { package_ensure: 'latest', package_name: ['storcli'], package_manage: true } }

            it { is_expected.to contain_package('storcli').with_ensure('latest') }
          end

          describe 'should allow the package name to be overridden' do
            let(:params) { { package_ensure: 'present', package_name: ['hambaby'], package_manage: true } }

            it { is_expected.to contain_package('hambaby') }
          end

          describe 'should allow multiple packages' do
            let(:params) { { package_ensure: 'present', package_name: ['storcli', 'libstoragemgmt'], package_manage: true } }

            it { is_expected.to contain_package('storcli').with_ensure('present') }
            it { is_expected.to contain_package('libstoragemgmt').with_ensure('present') }
          end

          describe 'should allow the package to be unmanaged' do
            let(:params) { { package_manage: false, package_name: ['storcli'] } }

            it { is_expected.not_to contain_package('storcli') }
          end

          describe 'is storcli binary already in "/usr/local/sbin"' do
            it { is_expected.not_to contain_file('/usr/local/sbin/storcli64') }
          end
        end
      end

      context 'with card not detected' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => false,
                           },
                         })
        end

        it { is_expected.to compile }

        it { is_expected.to contain_class('storcli::install') }

        describe 'storcli::install' do
          let(:params) { { package_ensure: 'present', package_name: ['storcli'] } }

          it {
            is_expected.not_to contain_package('storcli').with(
              ensure: 'present',
            )
          }
        end
      end

      context 'with package unmanaged but controllers detected' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => { 'storcli_tool' => '/usr/local/sbin/storcli64' } },
                           },
                         })
        end
        let(:params) do
          {
            package_manage: false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_package('storcli') }
        it { is_expected.to contain_class('storcli::install') }
      end

      context 'with hiera hash for controllers' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => { 'storcli_tool' => '/usr/local/sbin/storcli64' } },
                           },
                         })
        end
        let(:params) do
          {
            controllers: {
              '/c0' => {
                'ncq' => true,
                'perfmode' => 0,
              },
            },
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('/c0').with(ncq: true, perfmode: 0) }
      end

      context 'with hiera hash for patrolreads' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => { 'storcli_tool' => '/usr/local/sbin/storcli64' } },
                           },
                         })
        end
        let(:params) do
          {
            patrolreads: {
              '/c0' => {
                'mode' => 'auto',
                'rate' => 30,
              },
            },
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_patrolread('/c0').with(mode: 'auto', rate: 30) }
      end

      context 'with hiera hash for consistencychecks' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => { 'storcli_tool' => '/usr/local/sbin/storcli64' } },
                           },
                         })
        end
        let(:params) do
          {
            consistencychecks: {
              '/c0' => {
                'mode' => 'conc',
                'delay' => 672,
              },
            },
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_consistencycheck('/c0').with(mode: 'conc', delay: 672) }
      end

      context 'with hiera hash for vds' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => { 'storcli_tool' => '/usr/local/sbin/storcli64' } },
                           },
                         })
        end
        let(:params) do
          {
            vds: {
              '/c0/v0' => {
                'write_policy' => 'wt',
                'read_policy' => 'ra',
              },
            },
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_vd('/c0/v0').with(write_policy: 'wt', read_policy: 'ra') }
      end

      context 'with hiera hashes but no controller present' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => false,
                           },
                         })
        end
        let(:params) do
          {
            controllers: {
              '/c0' => { 'ncq' => true },
            },
            patrolreads: {
              '/c0' => { 'mode' => 'auto' },
            },
            consistencychecks: {
              '/c0' => { 'mode' => 'conc' },
            },
            vds: {
              '/c0/v0' => { 'write_policy' => 'wt' },
            },
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_storcli_controller('/c0') }
        it { is_expected.not_to contain_storcli_patrolread('/c0') }
        it { is_expected.not_to contain_storcli_consistencycheck('/c0') }
        it { is_expected.not_to contain_storcli_vd('/c0/v0') }
      end
    end
  end
end
