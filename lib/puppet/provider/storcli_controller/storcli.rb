# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'storcli')

Puppet::Type.type(:storcli_controller).provide(
  :storcli,
  parent: Puppet::Provider::Storcli,
) do
  desc 'Manage MegaRAID controller settings via storcli/perccli JSON interface'

  # --- Boolean on/off properties ---

  def autorebuild
    read_property('autorebuild') do |_cid, props|
      val = lookup_value(props, 'AutoRebuild')
      val.nil? ? nil : onoff_to_bool(val)
    end
  end

  def autorebuild=(val)
    storcli_set("set autorebuild=#{bool_to_onoff(val)}")
  end

  def ncq
    read_property('ncq') do |_cid, props|
      val = lookup_value(props, 'NCQ')
      val.nil? ? nil : onoff_to_bool(val)
    end
  end

  def ncq=(val)
    storcli_set("set ncq=#{bool_to_onoff(val)}")
  end

  def bootwithpinnedcache
    read_property('bootwithpinnedcache') do |_cid, props|
      val = lookup_value(props, 'Boot With Pinned Cache')
      val.nil? ? nil : onoff_to_bool(val)
    end
  end

  def bootwithpinnedcache=(val)
    storcli_set("set bootwithpinnedcache=#{bool_to_onoff(val)}")
  end

  def alarm
    read_property('alarm') do |_cid, props|
      val = lookup_value(props, 'Alarm')
      if val.nil? || val.to_s.casecmp('absent').zero?
        :absent
      else
        onoff_to_bool(val)
      end
    end
  end

  def alarm=(val)
    # Skip controllers whose alarm hardware is absent
    controller_ids.each do |cid|
      props = show_property_for(cid, 'alarm')
      raw = lookup_value(props, 'Alarm')
      next if raw.nil? || raw.to_s.casecmp('absent').zero?

      storcli_set_for(cid, "set alarm=#{bool_to_onoff(val)}")
    end
  end

  # --- Integer properties ---

  def rebuildrate
    read_property('rebuildrate') do |_cid, props|
      val = lookup_value(props, 'Rebuild Rate')
      val.nil? ? nil : val.to_s.delete('%').strip.to_i
    end
  end

  def rebuildrate=(val)
    storcli_set("set rebuildrate=#{val}")
  end

  def perfmode
    read_property('perfmode') do |_cid, props|
      val = lookup_value(props, 'Perf Mode')
      val&.to_i
    end
  end

  def perfmode=(val)
    storcli_set("set perfmode=#{val}")
  end

  def cacheflushinterval
    read_property('cacheflushint') do |_cid, props|
      val = lookup_value(props, 'Cache Flush Interval')
      val.nil? ? nil : val.to_s.gsub(%r{\s*sec.*}, '').strip.to_i
    end
  end

  def cacheflushinterval=(val)
    storcli_set("set cacheflushint=#{val}")
  end

  def smartpollinterval
    read_property('smartpollinterval') do |_cid, props|
      val = lookup_value(props, 'SmartPollInterval')
      val.nil? ? nil : val.to_s.gsub(%r{\s*sec.*}, '').strip.to_i
    end
  end

  def smartpollinterval=(val)
    storcli_set("set smartpollinterval=#{val}")
  end

  # --- Time sync ---

  def sync_time
    return :false unless @resource[:sync_time] == :true

    tolerance = (@resource[:time_tolerance] || 120).to_i
    use_utc = (@resource[:use_utc] == :true)

    # All controllers must be within tolerance to be considered in sync
    controller_ids.each do |cid|
      return :false unless controller_time_in_sync?(cid, tolerance, use_utc)
    end
    :true
  end

  def sync_time=(_val)
    use_utc = (@resource[:use_utc] == :true)
    controller_ids.each do |cid|
      if use_utc
        time_str = Time.now.utc.strftime('%Y%m%d %H:%M:%S')
        storcli_set_for(cid, "set time=#{time_str}")
      else
        storcli_set_for(cid, 'set time=systemtime')
      end
    end
  end

  private

  def controller_time_in_sync?(cid, tolerance, use_utc)
    json = storcli_json("/c#{cid} show time")
    return false unless json

    controller_time = nil
    each_controller(json) do |ctrl|
      controller_time = ctrl.dig('Response Data', 'Controller Time') ||
                        ctrl.dig('Response Data', 'System Time')
    end
    return false if controller_time.nil?

    require 'time'
    normalized = controller_time.to_s.tr('/', '-')
    if use_utc
      ct_epoch = Time.parse("#{normalized} UTC").to_i
      sys_epoch = Time.now.utc.to_i
    else
      ct_epoch = Time.parse(normalized).to_i
      sys_epoch = Time.now.to_i
    end
    (sys_epoch - ct_epoch).abs <= tolerance
  rescue StandardError => e
    Puppet.debug("storcli: time parse error for /c#{cid}: #{e.message}")
    false
  end
end
