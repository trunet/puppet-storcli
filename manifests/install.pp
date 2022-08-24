# @summary
#   This class handles storcli packages and binary link.
#
# @api private
#
class storcli::install (
  # lint:ignore:parameter_types
  $package_manage  = $storcli::package_manage,
  $package_name    = $storcli::package_name,
  $package_ensure  = $storcli::package_ensure,
  $link_storcli_to = $storcli::link_storcli_to,
  # lint:endignore
) inherits storcli {
  assert_private()

  # https://tickets.puppetlabs.com/browse/PUP-10259
  if Boolean($package_manage) {
    package { $package_name:
      ensure => $package_ensure,
    }

    unless $facts['megaraid']['storcli'].empty {
      unless dirname($facts['megaraid']['storcli']) == $link_storcli_to {
        $basename_storcli = basename($facts['megaraid']['storcli'])
        file { "${link_storcli_to}/${basename_storcli}":
          ensure => 'link',
          target => $facts['megaraid']['storcli'],
        }
      }
    }
  }
}
