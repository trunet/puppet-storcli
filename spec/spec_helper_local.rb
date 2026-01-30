require 'fileutils'

FileUtils.mkdir_p('/etc/facter/facts.d') || true
FileUtils.mkdir_p('/etc/puppetlabs/facter/facts.d') || true
FileUtils.mkdir_p('/opt/puppetlabs/facter/facts.d') || true
