require 'spec_helper'

describe 'storcli' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'with card detected' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => '/usr/local/sbin/storcli64', 'controllers' => {} } }) }

        it { is_expected.to compile }

        it { is_expected.to contain_class('storcli::install') }
        it { is_expected.to contain_class('storcli::configure') }

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

          describe 'should allow the package to be unmanaged' do
            let(:params) { { package_manage: false, package_name: ['storcli'] } }

            it { is_expected.not_to contain_package('storcli') }
          end

          describe 'is storcli binary already in "/usr/local/sbin"' do
            it { is_expected.not_to contain_file('/usr/local/sbin/storcli64') }
          end
        end
      end

      context 'with card detected, non-default link target' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => '/non/default/storcli', 'controllers' => {} } }) }

        it { is_expected.to compile }

        it { is_expected.to contain_class('storcli::install') }

        describe 'storcli::install' do
          let(:params) { { link_storcli_to: '/tmp/sbin' } }

          describe 'is storcli binary symlinked to target location' do
            it {
              is_expected.to contain_file('/tmp/sbin/storcli') \
                .with_ensure('link') \
                .with_target('/non/default/storcli')
            }
          end
        end
      end

      context 'with card not detected' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => false, 'controllers' => {} } }) }

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
    end
  end
end
