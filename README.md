# puppet-storcli

Puppet module to generate facts with types and providers to manage LSI MegaRAID controllers.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

#### Table of Contents

- [puppet-storcli](#puppet-storcli)
      - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Setup](#setup)
    - [Setup Requirements](#setup-requirements)
  - [Usage](#usage)
  - [Reference](#reference)
    - [Facts](#facts)
  - [Limitations](#limitations)
  - [Development](#development)

## Description

This puppet module generate facts and provides types and providers to manage LSI MegaRAID controllers.

## Setup

### Setup Requirements

This module makes use of `storcli`.  If running on a Dell server, the module will look to use `perccli` instead.

The package needs to be available from some repository to be installed.

## Usage

```puppet
include storcli
```

Optionally, to skip over configuration of the card.

```yaml
storcli::configure_settings: false
```

## Reference

Items not covered by puppet strings are provided below.

See [REFERENCE](REFERENCE.md) for all other reference documentation.

### Facts

- **megaraid** - structured fact
  - **present?** - Boolean - check if `/sys/bus/pci/drivers/megaraid_sas` is present?
  - **storcli** - String - location of `storcli`/`perccli` application.
  - **number_of_controllers** - Integer - number of megaraid controllers found
  - **controllers** - Hash[Controller number] - structured fact of megaraid controller informations
    - **product_name** - String - Product name
    - **serial_number** - String - Serial number
    - **fw_package_build** - String - Firmware Package Build
    - **fw_version** - String - Firmware Version
    - **bios_version** - String - Controller BIOS Version
    - **virtual_drives** - Hash - Drive settings per virtual drive
      - **Name** - String - Name of Virtual Disk
      - **Type** - String - Type of RAID
      - **State** - String - State of Virtual Disk
      - **Strip Size** - String - Strip Size of Virtual Disk
      - **Write Cache** - String - Write Cache Mode of Virtual Disk
      - **Read Cache** - String - Read Cache Mode of Virtual Disk
      - **IO Policy** - String - IO Policy of Virtual Disk
      - **Physical Drive Cache** - String - Physical Drive Cache Mode of Virtual Disk
      - **Encryption** - String - Encryption Mode of Virtual Disk
    - **patrol_read** - Hash - Patrol read information
      - **PR Mode** - String - Mode
      - **PR Execution Delay** - Integer - Execution delay in hours
      - **PR iterations completed** - Integer - How many times patrol read ran?
      - **PR Next Start time** - DateTime - Next time patrol read will run
      - **PR on SSD** - Boolean - Run on SSDs?
      - **PR Current State** - String - Is it running or stopped?
      - **PR Excluded VDs** - String - VDs that will not run patrol read
      - **PR MaxConcurrentPd** - Integer - Maximum number of concurrent PDs
    - **consistency_check** - Hash - Consistency check information
      - **CC Operation Mode** - String - Mode
      - **CC Execution Delay** - Integer - Execution delay in hours
      - **CC Next Starttime** - DateTime - Next time patrol read will run
      - **CC Current State** - String - Is it running or stopped?
      - **CC Number of iterations** - Integer - How many times patrol read ran?
      - **CC Number of VD completed** - Integer - Number of VDs completed
      - **CC Excluded VDs** - String - VDs that will not run patrol read

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

      controller_settings:               # numerics -> Integer, On/Off -> bool
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


## Limitations

For now, this module only provides a custom fact and ways to deal with patrol read and consistency check.

This module does not provide the `storcli` or `perccli` packages, you must do that yourself.  If the `package` provider can load them, they will be installed automatically.

The card configuration has not been tested on systems with multiple MegaRAID cards.  It should work, but it will set all cards to identical values.

Minimum `storcli`/`perccli` versions:

```
PercCli SAS Customization Utility Ver 007.2313.0000.0000 Mar 07, 2023
StorCli SAS Customization Utility Ver 007.2508.0000.0000 Feb 27, 2023
```

Older versions may work, but may not...

## Development

Contributions are welcome through pull requests. I will only accept PRs with tests covering the parts of the code you touched.

Before sending the PR, run the tests and regenerate puppet strings references:

```
# pdk validate
# pdk test unit
# pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```
