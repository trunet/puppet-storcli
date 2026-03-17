# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/storcli_vd'

describe Puppet::Type.type(:storcli_vd) do
  describe 'namevar derivation of controller' do
    it 'derives controller 0 from title /c0/v1' do
      resource = described_class.new(name: '/c0/v1')
      expect(resource[:controller]).to eq(0)
    end

    it 'derives controller 1 from title /c1/v0' do
      resource = described_class.new(name: '/c1/v0')
      expect(resource[:controller]).to eq(1)
    end

    it "defaults to 'all' when title does not match /c<ID>" do
      resource = described_class.new(name: 'fleet_policy')
      expect(resource[:controller]).to eq('all')
    end

    it "derives 'all' from title /call/vall" do
      resource = described_class.new(name: '/call/vall')
      expect(resource[:controller]).to eq('all')
    end
  end

  describe 'namevar derivation of virtual_disk' do
    it 'derives virtual_disk 1 from title /c0/v1' do
      resource = described_class.new(name: '/c0/v1')
      expect(resource[:virtual_disk]).to eq(1)
    end

    it 'derives virtual_disk 0 from title /c1/v0' do
      resource = described_class.new(name: '/c1/v0')
      expect(resource[:virtual_disk]).to eq(0)
    end

    it "defaults to 'all' when title does not match /v<ID>" do
      resource = described_class.new(name: 'fleet_policy')
      expect(resource[:virtual_disk]).to eq('all')
    end

    it "derives 'all' from title /c0/vall" do
      resource = described_class.new(name: '/c0/vall')
      expect(resource[:virtual_disk]).to eq('all')
    end

    it "derives 'all' from title /call/vall" do
      resource = described_class.new(name: '/call/vall')
      expect(resource[:virtual_disk]).to eq('all')
    end
  end

  describe 'combined controller and virtual_disk derivation' do
    it 'derives both from /c2/v3' do
      resource = described_class.new(name: '/c2/v3')
      expect(resource[:controller]).to eq(2)
      expect(resource[:virtual_disk]).to eq(3)
    end

    it 'derives controller all and virtual_disk all from /call/vall' do
      resource = described_class.new(name: '/call/vall')
      expect(resource[:controller]).to eq('all')
      expect(resource[:virtual_disk]).to eq('all')
    end

    it 'defaults both to all for a generic title' do
      resource = described_class.new(name: 'fleet_settings')
      expect(resource[:controller]).to eq('all')
      expect(resource[:virtual_disk]).to eq('all')
    end

    it 'allows explicit overrides for both' do
      resource = described_class.new(name: '/c0/v1', controller: 2, virtual_disk: 3)
      expect(resource[:controller]).to eq(2)
      expect(resource[:virtual_disk]).to eq(3)
    end
  end

  describe 'storcli_cmd default from fact' do
    it 'uses the storcli_tool from the matching controller in the fact' do
      allow(Facter).to receive(:value).with(:storcli).and_return(
        'present' => true,
        'controllers' => {
          0 => { 'storcli_tool' => '/opt/MegaRAID/storcli/storcli64' },
        },
      )
      resource = described_class.new(name: '/c0/v1')
      expect(resource[:storcli_cmd]).to eq('/opt/MegaRAID/storcli/storcli64')
    end

    it 'uses the storcli_tool from the first controller when controller is all' do
      allow(Facter).to receive(:value).with(:storcli).and_return(
        'present' => true,
        'controllers' => {
          0 => { 'storcli_tool' => '/usr/sbin/perccli64' },
        },
      )
      resource = described_class.new(name: 'fleet_policy')
      expect(resource[:storcli_cmd]).to eq('/usr/sbin/perccli64')
    end

    it 'falls back to /usr/local/sbin/storcli when fact is nil' do
      allow(Facter).to receive(:value).with(:storcli).and_return(nil)
      resource = described_class.new(name: '/c0/v1')
      expect(resource[:storcli_cmd]).to eq('/usr/local/sbin/storcli')
    end

    it 'allows explicit storcli_cmd to override the fact' do
      allow(Facter).to receive(:value).with(:storcli).and_return(
        'present' => true,
        'controllers' => {
          0 => { 'storcli_tool' => '/opt/MegaRAID/storcli/storcli64' },
        },
      )
      resource = described_class.new(name: '/c0/v1', storcli_cmd: '/usr/local/bin/storcli')
      expect(resource[:storcli_cmd]).to eq('/usr/local/bin/storcli')
    end
  end

  describe 'ignore_unsupported parameter' do
    it 'defaults to false' do
      resource = described_class.new(name: '/c0/v0')
      expect(resource[:ignore_unsupported]).to eq(:false)
    end

    it 'accepts true' do
      resource = described_class.new(name: '/c0/v0', ignore_unsupported: true)
      expect(resource[:ignore_unsupported]).to eq(:true)
    end

    it 'accepts false' do
      resource = described_class.new(name: '/c0/v0', ignore_unsupported: false)
      expect(resource[:ignore_unsupported]).to eq(:false)
    end
  end
end
