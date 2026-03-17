# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'storcli')

Puppet::Type.type(:storcli_consistencycheck).provide(
  :storcli,
  parent: Puppet::Provider::Storcli,
) do
  desc 'Manage MegaRAID consistency check settings via storcli/perccli JSON interface'

  def mode
    read_property('cc') do |_cid, props|
      val = lookup_value(props, 'CC Operation Mode')
      next nil if val.nil?

      case val
      when %r{Concurrent}i  then :conc
      when %r{Sequential}i  then :seq
      when %r{Disable}i     then :off
      else val.to_s.downcase.to_sym
      end
    end
  end

  def mode=(val)
    if val == :off
      storcli_set('set cc=off')
    else
      time_str = Time.now.utc.strftime('%Y/%m/%d')
      storcli_set("set cc=#{val} starttime=\"#{time_str} 23\"")
    end
  end

  def delay
    read_property('cc') do |_cid, props|
      val = lookup_value(props, 'CC Execution Delay')
      next nil if val.nil?

      val.to_s.gsub(%r{\s*hours?.*}, '').strip.to_i
    end
  end

  def delay=(val)
    storcli_set("set cc delay=#{val}")
  end

  def rate
    read_property('ccrate') do |_cid, props|
      val = lookup_value(props, 'CC Rate')
      next nil if val.nil?

      val.to_s.delete('%').strip.to_i
    end
  end

  def rate=(val)
    storcli_set("set ccrate=#{val}")
  end
end
