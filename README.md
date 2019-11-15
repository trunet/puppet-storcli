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

This module makes use of storcli. The package needs to be available from some repository to be installed.

## Usage

```
if $::megaraid.present? {
  include storcli
}
```

## Reference

Items not covered by puppet strings are provided below.

See [REFERENCE](REFERENCE.md) for all other reference documentation.

### Facts

- **megaraid** - structured fact
  - **present?** - Boolean - check if /sys/bus/pci/drivers/megaraid_sas is present?
  - **storcli** - String - location of storcli application.
  - **number_of_controllers** - Integer - number of megaraid controllers found
  - **controllers** - Array[Controller] - list of megaraid controller informations
    - **controller** - Integer - Controller Number
    - **product_name** - String - Product name
    - **serial_number** - String - Serial number
    - **fw_package_build** - String - Firmware Package Build
    - **fw_version** - String - Firmware Version
    - **bios_version** - String - Controller BIOS Version
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

## Limitations

For now, this module only provides a custom fact and ways to deal with patrol read and consistency check.

## Development

Contributions are welcome through pull requests. I will only accept PRs with tests covering the parts of the code you touched.

Before sending the PR, run the tests and regenerate puppet strings references:

```
# pdk validate
# pdk test unit
# pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```