# frozen_string_literal: true

require 'puppet/parameter/boolean'

Puppet::Type.newtype(:storcli_controller) do
  @doc = <<-DOC
    @summary
      Manages settings on a single MegaRAID / Dell PERC controller.

    Uses storcli/perccli JSON output for reliable idempotent management.
    Each property is independently managed — leave a property unset to
    skip management of that setting.

    The controller ID is derived from the title when it matches `/c<ID>`.
    If unset and not derivable from the title, it defaults to 'all'.

    @example Enable NCQ and set rebuild rate on controller 0
      storcli_controller { '/c0':
        autorebuild    => true,
        rebuildrate    => 60,
        ncq            => true,
      }

    @example Target all controllers (default when title is not /c<ID>)
      storcli_controller { 'fleet_settings':
        ncq => true,
      }
  DOC

  newparam(:name, namevar: true) do
    desc 'Resource title. When it matches "/c<ID>" the controller is derived automatically.'
  end

  newparam(:controller) do
    desc <<-DESC
      Integer controller ID (e.g. 0) or 'all' to target every detected controller.
      Derived from the title when it matches /c<ID>. Defaults to 'all' when unset.
    DESC
    defaultto do
      name = resource[:name].to_s
      if name =~ %r{/c(\d+)(?:/|$)}
        Regexp.last_match(1).to_i
      elsif %r{/call(?:/|$)}.match?(name)
        'all'
      else
        'all'
      end
    end
    validate do |value|
      unless value.to_s =~ %r{^\d+$} || value.to_s == 'all'
        raise Puppet::Error, "controller must be a non-negative integer or 'all'"
      end
    end
    munge { |v| (v.to_s == 'all') ? 'all' : v.to_i }
  end

  newparam(:storcli_cmd) do
    desc 'Path to the storcli or perccli binary. Defaults to the tool discovered by the storcli fact.'
    defaultto do
      storcli_fact = Facter.value(:storcli)
      tool = nil
      if storcli_fact.is_a?(Hash) && storcli_fact['controllers'].is_a?(Hash)
        ctrl_id = resource[:controller]
        controllers = storcli_fact['controllers']
        # Try to find the tool for the specific controller
        if ctrl_id.to_s != 'all'
          ctrl_data = controllers[ctrl_id] || controllers[ctrl_id.to_s]
          tool = ctrl_data['storcli_tool'] if ctrl_data.is_a?(Hash)
        end
        # Fall back to the first controller's tool
        if tool.nil?
          first_ctrl = controllers.values.first
          tool = first_ctrl['storcli_tool'] if first_ctrl.is_a?(Hash)
        end
      end
      tool || '/usr/local/sbin/storcli'
    end

    validate do |value|
      raise Puppet::Error, 'storcli_cmd must be an absolute path' unless value.start_with?('/')
    end
  end

  # --- Boolean on/off properties ---

  newproperty(:autorebuild) do
    desc 'Enable or disable automatic array rebuilds.'
    newvalues(:true, :false)
  end

  newproperty(:ncq) do
    desc 'Enable or disable Native Command Queue.'
    newvalues(:true, :false)
  end

  newproperty(:bootwithpinnedcache) do
    desc 'Continue booting with data stuck in cache.'
    newvalues(:true, :false)
  end

  newproperty(:alarm) do
    desc 'Enable or disable audible alarm. Silently ignored on controllers with no alarm hardware (ABSENT).'
    newvalues(:true, :false)

    def insync?(is)
      return true if is == :absent

      super
    end
  end

  # --- Integer properties ---

  newproperty(:rebuildrate) do
    desc 'Percentage of IO to dedicate to rebuilds (0-100).'
    validate do |value|
      v = value.to_i
      raise Puppet::Error, 'rebuildrate must be between 0 and 100' unless v >= 0 && v <= 100
    end
    munge { |v| v.to_i }

    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:perfmode) do
    desc 'Performance mode (0 = IOPS, higher values favour low latency).'
    validate do |value|
      raise Puppet::Error, 'perfmode must be a non-negative integer' unless %r{^\d+$}.match?(value.to_s)
    end
    munge { |v| v.to_i }

    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:cacheflushinterval) do
    desc 'Seconds between cache flushes (minimum 1).'
    validate do |value|
      v = value.to_i
      raise Puppet::Error, 'cacheflushinterval must be >= 1' unless v >= 1
    end
    munge { |v| v.to_i }

    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:smartpollinterval) do
    desc 'Seconds between SMART error polls (0-65535).'
    validate do |value|
      v = value.to_i
      raise Puppet::Error, 'smartpollinterval must be between 0 and 65535' unless v >= 0 && v <= 65_535
    end
    munge { |v| v.to_i }

    def insync?(is)
      is.to_i == should.to_i
    end
  end

  # --- Time sync (special property) ---

  newproperty(:sync_time) do
    desc 'Sync controller clock with the system clock. Set to :true to enable.'
    newvalues(:true, :false)
  end

  newparam(:use_utc) do
    desc 'Use UTC for the controller clock (only relevant when sync_time is true).'
    newvalues(:true, :false)
    defaultto :true
  end

  newparam(:time_tolerance) do
    desc 'Seconds of drift allowed before a time sync is triggered.'
    defaultto 120
    validate do |value|
      raise Puppet::Error, 'time_tolerance must be a non-negative integer' unless %r{^\d+$}.match?(value.to_s)
    end
    munge { |v| v.to_i }
  end

  newparam(:ignore_unsupported) do
    desc <<-DESC
      When true, silently downgrades errors from unsupported settings to
      warnings instead of failing the resource.  Useful for fleet-wide
      defaults across heterogeneous hardware — e.g. a 3008 controller
      that lacks a BBU or certain cache features will not cause a Puppet
      failure when this is enabled.  Non-applicable settings still generate
      a warning so they are visible in reports.
    DESC
    newvalues(:true, :false)
    defaultto :false
  end

  # Ordering is handled by init.pp: Class['storcli::install'] -> Storcli_controller <| |>
  # autorequire(:class) is not supported by Puppet's type system (Class is not a
  # regular Puppet::Type), so we rely on the explicit ordering in init.pp instead.
end
