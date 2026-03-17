# puppet-storcli

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Puppet module providing a structured fact and four native resource types for
managing MegaRAID and PERC RAID controllers via `storcli`/`perccli`.

- [Limitations](#limitations)
- [Notes](#notes)
- [Resource types](#resource-types)
  - [Title resolution](#title-resolution)
  - [storcli\_controller](#storcli_controller)
  - [storcli\_patrolread](#storcli_patrolread)
  - [storcli\_consistencycheck](#storcli_consistencycheck)
  - [storcli\_vd](#storcli_vd)
- [Package management](#package-management)
- [Hiera](#hiera)
- [Recommended configuration](#recommended-configuration)
- [Facts](#facts)
- [Development](#development)

---

## Limitations

- Requires `storcli` ≥ `007.2508.0000.0000` (2023-02-27), or `perccli` ≥ `007.2313.0000.0000` (2023-03-07) on Dell systems.
- This module does not provide the `storcli` or `perccli` packages.
  The `storcli` class can install them if the package is available in a configured repository (see [Package management](#package-management)).
- Not all controllers support every property.  The `alarm` property is silently skipped when the controller reports `ABSENT` alarm hardware.
  Other unsupported properties surface as Puppet failures by default so misconfigurations are visible during the run.
- Mixing `all` with specifically identified controllers / virtual disks, will result in flapping and ambigious behavior.
- `storcli2`/`perccli2` are not supported — both tools start controller numbering at zero, making reconciliation with existing resources ambiguous.

---

## Notes

- Controller presence is detected via `/sys/bus/pci/drivers/megaraid_sas` and `/sys/bus/pci/drivers/mpt3sas`.
- Set `ignore_unsupported => true` to downgrade configuration errors to warnings (see [Heterogeneous fleets](#heterogeneous-fleets)).

---

## Resource types

All four types are independently usable without declaring the `storcli` class.
Each property is managed independently: omitting a property leaves that setting unchanged on the controller.

### Title resolution

The resource title controls which controller or virtual disk is targeted:

| Title format | Resolved target |
|---|---|
| `/c<N>` | Controller N |
| `/c<N>/v<M>` | Virtual disk M on controller N |
| Any other string | All controllers (`all`); override with the `controller` parameter |

### storcli\_controller

General controller settings.

```puppet
storcli_controller { '/c0':
  autorebuild         => true,
  rebuildrate         => 60,       # percent, 0–100
  perfmode            => 0,        # 0 = tuned, 1 = balanced
  ncq                 => true,
  cacheflushinterval  => 4,        # seconds
  bootwithpinnedcache => false,
  alarm               => true,     # silently skipped if hardware absent
  smartpollinterval   => 600,      # seconds
  sync_time           => true,     # sync controller clock from system
  use_utc             => true,
  time_tolerance      => 180,      # seconds before sync triggers
}
```

### storcli\_patrolread

```puppet
storcli_patrolread { '/c0':
  mode        => 'auto',   # 'auto' or 'manual'
  delay       => 336,      # hours between runs
  rate        => 30,       # percent IO budget
  includessds => false,
  uncfgareas  => false,
}
```

### storcli\_consistencycheck

```puppet
storcli_consistencycheck { '/c0':
  mode  => 'conc',   # 'conc' (concurrent) or 'seq' (sequential)
  delay => 672,      # hours between runs
  rate  => 30,       # percent IO budget
}
```

### storcli\_vd

```puppet
storcli_vd { '/c0/v0':
  write_policy => 'wt',      # 'wt' (WriteThrough), 'wb' (WriteBack), 'awb' (AlwaysWriteBack)
  read_policy  => 'ra',      # 'ra' (ReadAhead), 'nora' (NoReadAhead)
  io_policy    => 'direct',  # 'direct' or 'cached'
  disk_cache   => 'default', # 'default', 'on', or 'off'
}
```

---

## Package management

```puppet
include storcli
```

Installs `storcli` (or `perccli` on Dell systems) when `$facts['storcli']['present']` is `true`.
The package must be available in a configured repository; this module does not provide it.

The native types may be used without `include storcli`.
In that case, ensure the binary is present before the Puppet run -
the `Class['storcli::install'] ->` ordering relationship will not exist.

You are responsible for updating `PATH` unless `storcli`/`perccli` starts
doing it for you.

---

## Hiera

All four types can be instantiated from Hiera via the `storcli` class parameters.
Resources are only created when `$facts['storcli']['present']` is `true`,
so these hashes are safe to set in shared layers -
nodes without RAID hardware silently skip them.

Hash keys become resource titles and follow the same
[title resolution](#title-resolution) rules as direct declarations.

```yaml
storcli::controllers:
  '/c0':
    ncq: true
    perfmode: 0
    autorebuild: true
    rebuildrate: 60
    sync_time: true
    use_utc: true
    alarm: true
  '/c1':
    ncq: false
    perfmode: 1

storcli::patrolreads:
  '/c0':
    mode: auto
    delay: 336
    rate: 30
    includessds: false
    uncfgareas: false

storcli::consistencychecks:
  '/c0':
    mode: conc
    delay: 672
    rate: 30

storcli::vds:
  '/c0/v0':
    write_policy: wt
    read_policy: ra
    io_policy: direct
    disk_cache: default
```

---

## Recommended configuration

Fleet-wide defaults targeting all controllers.  Adapt to your needs.

```puppet
include storcli

storcli_controller { '/call':
  autorebuild         => true,
  rebuildrate         => 60,
  perfmode            => 0,
  ncq                 => true,
  cacheflushinterval  => 4,
  bootwithpinnedcache => false,
  alarm               => true,
  smartpollinterval   => 600,
  sync_time           => true,
  use_utc             => true,
  time_tolerance      => 180,
}

# Patrol read: automatic, every 14 days, 30% IO budget
storcli_patrolread { '/call':
  mode        => 'auto',
  delay       => 336,
  rate        => 30,
  includessds => false,
  uncfgareas  => false,
}

# Consistency check: concurrent, every 28 days, 30% IO budget
storcli_consistencycheck { '/call':
  mode  => 'conc',
  delay => 672,
  rate  => 30,
}
```

---

## Heterogeneous fleets

When managing a mix of controller models (e.g. 9560 with BBU alongside
3008 without), some properties may not exist on every card.  By default
these surface as Puppet failures so you notice misconfigurations.

Set `ignore_unsupported => true` to downgrade storcli execution failures
to **warnings** instead.  Unsupported settings still appear in Puppet
reports, but no longer fail the run:

```puppet
storcli_controller { 'fleet_defaults':
  ignore_unsupported  => true,  # skip unsupported settings with a warning
  autorebuild         => true,
  rebuildrate         => 60,
  ncq                 => true,
  alarm               => true,
  sync_time           => true,
}

storcli_vd { 'fleet_vd_policy':
  ignore_unsupported => true,
  write_policy       => 'wt',
  read_policy        => 'ra',
  io_policy          => 'direct',   # ignored with a warning on cards without IO policy support
  disk_cache         => 'default',
}
```

The same parameter is available on all four `storcli_` resource types.

---

## Facts

The `storcli` structured fact is populated on every node.
On nodes without RAID hardware, only `present` is set; all other keys are absent.

```yaml
storcli:
  present: true
  number_of_controllers: 1
  controllers:
    '0':
      product_name: 'PERC H730P Adapter'
      serial_number: 'SV30703527'
      fw_package_build: '25.5.9.0001'
      fw_version: '4.300.00-8516'
      bios_version: '7.11.03.1_4.19.08.00_0x07250000'
      driver_name: megaraid_sas
      device_interface: PCIE
      drive_groups_count: 1
      physical_drive_count: 5
      storcli_tool: /usr/bin/perccli64

      controller_settings:               # snake_case key/value from `show all`; numerics → Integer, On/Off → bool
        rebuild_rate: 60
        patrol_read_rate: 30
        auto_rebuild: true
        # ... (all remaining storcli properties)

      drive_groups:
        '0':
          virtual_disks:
            '0':
              name: /c0/v0
              raid_level: RAID5
              state: Optl
              size: '3.637 TB'
              os_drive_name: /dev/sda
              properties:               # absent if storcli cannot retrieve VD properties
                stripe_size: '256 KB'
                span_depth: 1
                number_of_drives_per_span: 5
                current_write_policy: WriteThrough   # AlwaysWriteBack | WriteBack | WriteThrough
                current_read_policy: ReadAhead        # ReadAhead | ReadAheadNone
                io_policy: Direct                     # Direct | Cached
                disk_cache_policy: default            # default | on | off
                is_vd_boot_drive: 'Yes'
                encryption: None
                exposed_to_os: 'Yes'
                unmap_enabled: 'No'
                data_protection: Disabled

      bbu_info:                          # absent if no BBU present
        state: Optimal
        type: 'CVPM02'
        replacement_needed: false
        learn_cycle_active: false

      patrol_read:                       # absent if controller does not support patrol read
        mode: auto
        execution_delay: 336             # hours
        on_ssd: false
        next_start_time: '2025-03-22 03:00:00'

      consistency_check:                 # absent if controller does not support consistency check
        operation_mode: conc
        execution_delay: 672             # hours
        next_start_time: '2025-03-29 03:00:00'
```

---

## Development

PRs are welcome.  Tests are required for any code you touch.

```sh
pdk validate
pdk test unit
pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```

See [REFERENCE.md](REFERENCE.md) for full parameter documentation generated
by puppet-strings.
