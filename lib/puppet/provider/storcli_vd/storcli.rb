# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'storcli')

Puppet::Type.type(:storcli_vd).provide(
  :storcli,
  parent: Puppet::Provider::Storcli,
) do
  desc 'Manage MegaRAID virtual disk settings via storcli/perccli JSON interface'

  # Maps the compact cache token from VD LIST into discrete policies.
  # Token format examples: "RWTD", "NRWTD", "RAWBC"
  #   First char(s): R (ReadAhead) or NR (No ReadAhead)
  #   Then:          WB (WriteBack) / WT (WriteThrough) / AWB (AlwaysWriteBack)
  #   Last char:     D (Direct) or C (Cached)
  WRITE_POLICY_MAP = {
    'awb' => :awb,
    'wb'  => :wb,
    'wt'  => :wt,
  }.freeze

  READ_POLICY_MAP = {
    'ra'   => :ra,
    'nora' => :nora,
  }.freeze

  IO_POLICY_MAP = {
    'direct' => :direct,
    'cached' => :cached,
  }.freeze

  DISK_CACHE_MAP = {
    "disk's default" => :default,
    'default'        => :default,
    'enabled'        => :on,
    'disabled'       => :off,
  }.freeze

  # --- Property getters ---

  def write_policy
    read_vd_property do |_cid, _vid, vd_props, vd_info|
      # First try the detailed properties
      raw = vd_props['Write Cache(initial setting)']
      if raw
        case raw
        when %r{AlwaysWriteBack}i then :awb
        when %r{WriteBack}i       then :wb
        when %r{WriteThrough}i    then :wt
        else
          # Parse from the compact Cache token in VD LIST
          parse_write_from_cache_token(vd_info)
        end
      else
        parse_write_from_cache_token(vd_info)
      end
    end
  end

  def write_policy=(val)
    storcli_vd_set("set wrcache=#{val}")
  end

  def read_policy
    read_vd_property do |_cid, _vid, _vd_props, vd_info|
      parse_read_from_cache_token(vd_info)
    end
  end

  def read_policy=(val)
    storcli_vd_set("set rdcache=#{val}")
  end

  def io_policy
    read_vd_property do |_cid, _vid, _vd_props, vd_info|
      parse_io_from_cache_token(vd_info)
    end
  end

  def io_policy=(val)
    storcli_vd_set("set iopolicy=#{val}")
  end

  def disk_cache
    read_vd_property do |_cid, _vid, vd_props, _vd_info|
      raw = vd_props['Disk Cache Policy']
      next nil if raw.nil?

      DISK_CACHE_MAP[raw.to_s.downcase] || :default
    end
  end

  def disk_cache=(val)
    storcli_vd_set("set pdcache=#{val}")
  end

  private

  # Parse the compact "Cache" token from the VD LIST entry.
  # Token examples: "RWTD", "NRWTD", "RAWBC", "RFWBC"
  def cache_token(vd_info)
    return nil unless vd_info.is_a?(Array) && !vd_info.empty?

    vd_info.first&.fetch('Cache', nil)
  end

  def parse_write_from_cache_token(vd_info)
    token = cache_token(vd_info)
    return nil unless token

    t = token.upcase
    if t.include?('AWB')
      :awb
    elsif t.include?('FWB') || t.include?('WB')
      # FWB = Forced WriteBack (equivalent to wb for our purposes)
      :wb
    elsif t.include?('WT')
      :wt
    end
  end

  def parse_read_from_cache_token(vd_info)
    token = cache_token(vd_info)
    return nil unless token

    # NR prefix means No ReadAhead, R prefix means ReadAhead
    token.upcase.start_with?('NR') ? :nora : :ra
  end

  def parse_io_from_cache_token(vd_info)
    token = cache_token(vd_info)
    return nil unless token

    # Last character: D = Direct, C = Cached
    token.upcase.end_with?('D') ? :direct : :cached
  end
end
