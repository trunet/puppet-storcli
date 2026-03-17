# frozen_string_literal: true

Puppet::Type.newtype(:storcli_patrolread) do
  @doc = <<-DOC
    @summary
      Manages patrol read settings on a single MegaRAID / Dell PERC controller.

    Uses storcli/perccli JSON output for reliable idempotent management.

    The controller ID is derived from the title when it matches `/c<ID>`.
    If unset and not derivable from the title, it defaults to 'all'.

    @example Enable automatic patrol reads on controller 0
      storcli_patrolread { '/c0':
        mode        => 'auto',
        delay       => 336,
        rate        => 30,
        includessds => false,
        uncfgareas  => false,
      }

    @example Target all controllers
      storcli_patrolread { 'fleet_pr':
        mode => 'auto',
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

  newproperty(:mode) do
    desc "Patrol read mode: 'auto', 'manual', or 'off'."
    newvalues(:auto, :manual, :off)
  end

  newproperty(:delay) do
    desc 'Hours between automatic patrol reads (only applies when mode is auto).'
    validate do |value|
      raise Puppet::Error, 'delay must be a non-negative integer' unless %r{^\d+$}.match?(value.to_s)
    end
    munge { |v| v.to_i }

    def insync?(is)
      # Delay only applies when mode is auto; skip check otherwise
      return true if [:off, :manual].include?(@resource[:mode])

      is.to_i == should.to_i
    end
  end

  newproperty(:rate) do
    desc 'Percentage of IO to dedicate to patrol reads (0-100).'
    validate do |value|
      v = value.to_i
      raise Puppet::Error, 'rate must be between 0 and 100' unless v >= 0 && v <= 100
    end
    munge { |v| v.to_i }

    def insync?(is)
      # Rate only applies when mode is not off
      return true if @resource[:mode] == :off

      is.to_i == should.to_i
    end
  end

  newproperty(:includessds) do
    desc 'Whether to include SSD devices in patrol reads.'
    newvalues(:true, :false)

    def insync?(is)
      return true if @resource[:mode] == :off

      super
    end
  end

  newproperty(:uncfgareas) do
    desc 'Whether to patrol unconfigured areas on drives.'
    newvalues(:true, :false)

    def insync?(is)
      return true if is == :absent
      return true if @resource[:mode] == :off

      super
    end
  end

  newparam(:ignore_unsupported) do
    desc <<-DESC
      When true, silently downgrades errors from unsupported settings to
      warnings instead of failing the resource.  Useful for fleet-wide
      defaults across heterogeneous hardware.
    DESC
    newvalues(:true, :false)
    defaultto :false
  end

  validate do
    raise Puppet::Error, 'mode is required' unless self[:mode]
  end

  # Ordering is handled by init.pp: Class['storcli::install'] -> Storcli_patrolread <| |>
  # autorequire(:class) is not supported by Puppet's type system (Class is not a
  # regular Puppet::Type), so we rely on the explicit ordering in init.pp instead.
end
