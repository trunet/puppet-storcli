# Changelog

All notable changes to this project will be documented in this file.

## Release 0.4.0

**Features**

* Support for mpt3sas cards

## Release 0.3.2

**Features**

* attempt to use perccli on Dell servers
* Booleans for `controller_manage_rebuild` and `controller_manage_alarm`

## Release 0.3.1

**Bugfixes**

* storcli on an EFI host doesn't support JSON mode (for some reason)

## Release 0.3.0

**Features**

* Add ability to set configuration on card

## Release 0.2.2

**Features**

* Updated pdk to 2.4.0
* Package is only installed by default on hosts with card detected
* Binary linked into "/usr/local/sbin" is determined from facts

## Release 0.2.1

**Features**

* Updated pdk to 1.18

**Security**

* CVE-2020-10663

## Release 0.2.0

**Features**

* Add storcli to PATH
* Updated pdk to 1.15.0

**Bugfixes**

* Bump excon from 0.69.1 to 0.71.0 (#1)

## Release 0.1.1

**Features**

* Convert megaraid.controllers to a HASH

## Release 0.1.0

**Features**

* Initial version

**Bugfixes**

**Known Issues**
