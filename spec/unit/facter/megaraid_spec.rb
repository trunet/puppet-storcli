require 'spec_helper'

RSpec.configure do |c|
  c.include PuppetlabsSpec::Files

  c.before :each do
    # Ensure that we don't accidentally cache facts and environment
    # between test cases.
    allow(Facter::Util::Loader).to receive(:any_instance).and_return(:load_all)

    Facter.clear
    Facter.clear_messages

    # Store any environment variables away to be restored later
    @old_env = {}
    ENV.each_key { |k| @old_env[k] = ENV[k] }
  end

  c.after :each do
    PuppetlabsSpec::Files.cleanup
  end
end

describe 'megaraid fact' do
  describe 'megaraid_sas driver and storcli unavailable' do
    it 'key present?' do
      expect(Facter.fact(:megaraid).value.fetch('present?')).to eq(false)
    end
    it 'key storcli' do
      expect(Facter.fact(:megaraid).value.fetch('storcli')).to eq(nil)
    end
    it 'key number_of_controllers' do
      expect(Facter.fact(:megaraid).value.fetch('number_of_controllers')).to eq(0)
    end
    it 'key controllers' do
      expect(Facter.fact(:megaraid).value.fetch('controllers')).to eq({})
    end
  end

  describe 'megaraid_sas unavailable and storcli available' do
    before :each do
      allow(Facter::Util::Resolution).to receive(:which).and_call_original
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return('/opt/MegaRAID/storcli/storcli64')
    end
    it 'key present?' do
      expect(Facter.fact(:megaraid).value.fetch('present?')).to eq(false)
    end
    it 'key storcli' do
      expect(Facter.fact(:megaraid).value.fetch('storcli')).to eq(nil)
    end
    it 'key number_of_controllers' do
      expect(Facter.fact(:megaraid).value.fetch('number_of_controllers')).to eq(0)
    end
    it 'key controllers' do
      expect(Facter.fact(:megaraid).value.fetch('controllers')).to eq({})
    end
  end

  describe 'megaraid_sas and storcli available' do
    before :each do
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)
      allow(Facter::Util::Resolution).to receive(:which).and_call_original
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return('/opt/MegaRAID/storcli/storcli64')
      allow(Facter::Util::Resolution).to receive(:exec).with('/opt/MegaRAID/storcli/storcli64 /call show J').and_return(File.read('spec/fixtures/storcli_call_show.json'))
      allow(Facter::Util::Resolution).to receive(:exec).with('/opt/MegaRAID/storcli/storcli64 /call show patrolread J').and_return(File.read('spec/fixtures/storcli_call_show_patrolread.json'))
      allow(Facter::Util::Resolution).to receive(:exec).with('/opt/MegaRAID/storcli/storcli64 /call show cc J').and_return(File.read('spec/fixtures/storcli_call_show_cc.json'))
    end

    it 'key present?' do
      expect(Facter.fact(:megaraid).value.fetch('present?')).to eq(true)
    end
    it 'key storcli' do
      expect(Facter.fact(:megaraid).value.fetch('storcli')).to eq('/opt/MegaRAID/storcli/storcli64')
    end
    it 'key number_of_controllers' do
      expect(Facter.fact(:megaraid).value.fetch('number_of_controllers')).to eq(2)
    end
    it 'key controllers' do
      expect(Facter.fact(:megaraid).value.fetch('controllers').count).to eq(2)
    end
    it 'key product_name' do
      expect(Facter.fact(:megaraid).value.fetch('controllers')[0]['product_name']).to eq('AVAGO 3108 MegaRAID')
      expect(Facter.fact(:megaraid).value.fetch('controllers')[1]['product_name']).to eq('AVAGO 3108 MegaRAID')
    end
    it 'key patrol_read/PR Next Start time' do
      expect(Facter.fact(:megaraid).value.fetch('controllers')[0]['patrol_read']['PR Next Start time']).to eq('Saturday at 03:00:00')
      expect(Facter.fact(:megaraid).value.fetch('controllers')[1]['patrol_read']['PR Next Start time']).to eq('Saturday at 03:00:00')
    end
    it 'key consistency_check/CC Next Starttime' do
      expect(Facter.fact(:megaraid).value.fetch('controllers')[0]['consistency_check']['CC Next Starttime']).to eq('Saturday at 03:00:00')
      expect(Facter.fact(:megaraid).value.fetch('controllers')[1]['consistency_check']['CC Next Starttime']).to eq('Saturday at 03:00:00')
    end
  end
end
