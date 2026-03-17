# frozen_string_literal: true

Puppet::Type.newtype(:storcli_vd) do
  @doc = <<-DOC
    @summary
      Manages virtual disk (VD) settings on MegaRAID / Dell PERC controllers.

    Controls per-VD cache policies and I/O behaviour.  Both `controller` and
    `virtual_disk` accept the string 'all' to target every detected item,
    making it easy to enforce a fleet-wide policy.

    The controller and VD IDs are derived from the title when it matches
    `/c<ID>/v<ID>`.  If unset and not derivable, they default to 'all'.

    If a setting cannot be applied (e.g. requesting write-back without a BBU),
    storcli itself will report the error and Puppet will flag the resource as
    failed so sysadmins can see it in their reports.

    @example Set write-back cache on all VDs of controller 0
      storcli_vd { '/c0/vall':
        write_policy => 'wb',
      }

    @example Uniform policy across every VD on every controller (default)
      storcli_vd { 'fleet_policy':
        write_policy => 'wt',
        read_policy  => 'ra',
        io_policy    => 'direct',
        disk_cache   => 'default',
      }

    @example Target a single VD
      storcli_vd { '/c0/v1':
        write_policy => 'awb',
      }
  DOC

  newparam(:name, namevar: true) do
    desc 'Resource title. When it matches "/c<ID>/v<ID>" both controller and virtual_disk are derived automatically.'
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

  newparam(:virtual_disk) do
    desc <<-DESC
      Integer VD ID (e.g. 0) or 'all' to target every VD on the controller(s).
      Derived from the title when it matches /v<ID>. Defaults to 'all' when unset.
    DESC
    defaultto do
      name = resource[:name].to_s
      if name =~ %r{/v(\d+)(?:/|$)}
        Regexp.last_match(1).to_i
      elsif %r{/vall(?:/|$)}.match?(name)
        'all'
      else
        'all'
      end
    end
    validate do |value|
      unless value.to_s =~ %r{^\d+$} || value.to_s == 'all'
        raise Puppet::Error, "virtual_disk must be a non-negative integer or 'all'"
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

  # --- Cache policy properties ---

  newproperty(:write_policy) do
    desc "Write cache policy: 'wt' (WriteThrough), 'wb' (WriteBack), or 'awb' (AlwaysWriteBack)."
    newvalues(:wt, :wb, :awb)
  end

  newproperty(:read_policy) do
    desc "Read cache policy: 'ra' (ReadAhead) or 'nora' (No ReadAhead)."
    newvalues(:ra, :nora)
  end

  newproperty(:io_policy) do
    desc "I/O policy: 'direct' or 'cached'."
    newvalues(:direct, :cached)
  end

  newproperty(:disk_cache) do
    desc "Physical disk cache: 'on', 'off', or 'default' (use disk's built-in setting)."
    newvalues(:on, :off, :default)
  end

  newparam(:ignore_unsupported) do
    desc <<-DESC
      When true, silently downgrades errors from unsupported settings to
      warnings instead of failing the resource.  Useful for fleet-wide
      defaults across heterogeneous hardware — e.g. a controller without
      IO policy support will not cause a Puppet failure.
    DESC
    newvalues(:true, :false)
    defaultto :false
  end

  # Ordering is handled by init.pp: Class['storcli::install'] -> Storcli_vd <| |>
  # autorequire(:class) is not supported by Puppet's type system (Class is not a
  # regular Puppet::Type), so we rely on the explicit ordering in init.pp instead.
end
