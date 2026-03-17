# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'storcli')

Puppet::Type.type(:storcli_patrolread).provide(
  :storcli,
  parent: Puppet::Provider::Storcli,
) do
  desc 'Manage MegaRAID patrol read settings via storcli/perccli JSON interface'

  def mode
    read_property('patrolread') do |_cid, props|
      val = lookup_value(props, 'PR Mode')
      next nil if val.nil?

      case val
      when %r{Auto}i    then :auto
      when %r{Manual}i  then :manual
      when %r{Disable}i then :off
      else val.to_s.downcase.to_sym
      end
    end
  end

  def mode=(val)
    if val == :off
      storcli_set('set patrolread=off')
    else
      storcli_set("set patrolread=on mode=#{val}")
    end
  end

  def delay
    read_property('patrolread') do |_cid, props|
      val = lookup_value(props, 'PR Execution Delay')
      next nil if val.nil?

      val.to_s.gsub(%r{\s*hours?.*}, '').strip.to_i
    end
  end

  def delay=(val)
    storcli_set("set patrolread delay=#{val}")
  end

  def rate
    read_property('prrate') do |_cid, props|
      val = lookup_value(props, 'Patrol Read Rate')
      next nil if val.nil?

      val.to_s.delete('%').strip.to_i
    end
  end

  def rate=(val)
    storcli_set("set prrate=#{val}")
  end

  def includessds
    read_property('patrolread') do |_cid, props|
      val = lookup_value(props, 'PR on SSD')
      next nil if val.nil?

      enabled_to_bool(val)
    end
  end

  def includessds=(val)
    storcli_set("set patrolread includessds=#{bool_to_onoff(val)}")
  end

  def uncfgareas
    read_property('patrolread') do |_cid, props|
      val = lookup_value(props, 'PR on EPD')
      next :absent if val.nil?

      enabled_to_bool(val)
    end
  end

  def uncfgareas=(val)
    # Only set on controllers that support this feature (have 'PR on EPD')
    controller_ids.each do |cid|
      props = show_property_for(cid, 'patrolread')
      epd = lookup_value(props, 'PR on EPD')
      next if epd.nil?

      storcli_set_for(cid, "set patrolread uncfgareas=#{bool_to_onoff(val)}")
    end
  end
end
