# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/megaraid'

describe :megaraid, type: :fact do
  subject(:fact) { Facter.fact(:megaraid) }

  before :each do
    # perform any action that should be run before every test
    Facter.clear
  end

  context 'no module present' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(false)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(false)

      expect(Facter::Util::Resolution).not_to receive(:which)
      expect(Facter::Util::Resolution).not_to receive(:exec)
    end

    it do
      expect(fact.value['present?']).to eq(false)
      expect(fact.value['storcli']).to eq(nil)
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers']).to eq({})
    end
  end

  context 'module present, no storcli' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

      expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return(nil).twice
      expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil).twice
      expect(Facter::Util::Resolution).to receive(:which).with('storcli').and_return(nil).twice
      expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil).twice

      expect(Facter::Util::Resolution).not_to receive(:exec)
    end

    it do
      expect(fact.value['present?']).to eq(true)
      expect(fact.value['storcli']).to eq(nil)
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers']).to eq({})
    end
  end

  context 'module present, storcli present' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

      expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return('/example/path').twice
      expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli64')
      expect(Facter::Util::Resolution).not_to receive(:which).with('storcli')
      expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli')

      expect(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show J').and_return(File.read('spec/fixtures/storcli_call_show.json'))
      expect(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show patrolread J').and_return(File.read('spec/fixtures/storcli_call_show_patrolread.json'))
      expect(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show cc J').and_return(File.read('spec/fixtures/storcli_call_show_cc.json'))
    end

    it do
      expect(fact.value['present?']).to eq(true)
      expect(fact.value['storcli']).to eq('/example/path')
      expect(fact.value['number_of_controllers']).to eq(2)
    end
    it 'controllers structure' do
      expect(fact.value['controllers'].count).to eq(2)

      # key product_name
      expect(fact.value.fetch('controllers')['0']['product_name']).to eq('AVAGO 3108 MegaRAID')
      expect(fact.value.fetch('controllers')['1']['product_name']).to eq('AVAGO 3108 MegaRAID')

      # key patrol_read/PR Next Start time
      expect(fact.value.fetch('controllers')['0']['patrol_read']['PR Next Start time']).to eq('Saturday at 03:00:00')
      expect(fact.value.fetch('controllers')['1']['patrol_read']['PR Next Start time']).to eq('Saturday at 03:00:00')

      # key consistency_check/CC Next Starttime
      expect(fact.value.fetch('controllers')['0']['consistency_check']['CC Next Starttime']).to eq('Saturday at 03:00:00')
      expect(fact.value.fetch('controllers')['1']['consistency_check']['CC Next Starttime']).to eq('Saturday at 03:00:00')
    end
  end
end
