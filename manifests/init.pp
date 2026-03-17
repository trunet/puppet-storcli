# @summary Manage LSI MegaRAID / Dell PERC RAID controllers
#
# Installs the storcli/perccli package.  Controller configuration is
# handled by the native resource types (`storcli_controller`,
# `storcli_patrolread`, `storcli_consistencycheck`, `storcli_vd`)
# which can be declared directly in your profiles or via the Hiera
# hash parameters on this class.
#
# @example Install the package only
#   include storcli
#
# @example Configure controllers via Hiera
#   storcli::controllers:
#     '/c0':
#       ncq: true
#       perfmode: 0
#       autorebuild: true
#       rebuildrate: 60
#
# @param package_manage
#   Whether to manage the storcli package.
#   Default: value of storcli fact `present` key.
#
# @param package_name
#   Specifies the storcli/perccli package(s) to manage.
#
# @param package_ensure
#   Package ensure value: 'present', 'latest', or a specific version.
#
# @param controllers
#   Hash of `storcli_controller` native resources to create.
#   Keys are resource titles; values are parameter hashes.
#
# @param patrolreads
#   Hash of `storcli_patrolread` native resources to create.
#   Keys are resource titles; values are parameter hashes.
#
# @param consistencychecks
#   Hash of `storcli_consistencycheck` native resources to create.
#   Keys are resource titles; values are parameter hashes.
#
# @param vds
#   Hash of `storcli_vd` native resources to create.
#   Keys are resource titles; values are parameter hashes.
#
class storcli (
  # Hiera can convert facts to strings, but we really want a bool
  # https://tickets.puppetlabs.com/browse/PUP-10259
  Variant[Boolean, Enum['true', 'false']] $package_manage,
  Array[String] $package_name,
  String        $package_ensure,
  Hash          $controllers       = {},
  Hash          $patrolreads       = {},
  Hash          $consistencychecks = {},
  Hash          $vds               = {},
) {
  contain storcli::install

  # Ensure install completes before any controller configuration.
  Class['storcli::install'] -> Storcli_controller <| |>
  Class['storcli::install'] -> Storcli_patrolread <| |>
  Class['storcli::install'] -> Storcli_consistencycheck <| |>
  Class['storcli::install'] -> Storcli_vd <| |>

  # Create native type resources from Hiera hashes.
  # Only when a MegaRAID/PERC controller is present — avoids creating
  # resources that would inevitably fail on nodes without RAID hardware.
  if $facts.dig('storcli', 'present') {
    $controllers.each |$_name, $_params| {
      storcli_controller { $_name:
        * => $_params,
      }
    }
    $patrolreads.each |$_name, $_params| {
      storcli_patrolread { $_name:
        * => $_params,
      }
    }
    $consistencychecks.each |$_name, $_params| {
      storcli_consistencycheck { $_name:
        * => $_params,
      }
    }
    $vds.each |$_name, $_params| {
      storcli_vd { $_name:
        * => $_params,
      }
    }
  }
}
