require 'spec_helper'

describe 'storcli' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it { is_expected.to contain_class('storcli::install') }

      describe 'storcli::install' do
        let(:params) { { package_ensure: 'present', package_name: ['storcli'], package_manage: true } }

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

        describe 'is storcli64 symlinked to /usr/local/sbin/storcli64' do
          it {
            is_expected.to contain_file('/usr/local/sbin/storcli64') \
              .with_ensure('link') \
              .with_target('/opt/MegaRAID/storcli/storcli64')
          }
        end
      end
    end
  end
end
