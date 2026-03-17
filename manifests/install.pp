# @summary
#   This class handles storcli packages.
#
# @api private
#
class storcli::install (
  # lint:ignore:parameter_types
  $package_manage = $storcli::package_manage,
  $package_name   = $storcli::package_name,
  $package_ensure = $storcli::package_ensure,
  # lint:endignore
) inherits storcli {
  assert_private()

  # https://tickets.puppetlabs.com/browse/PUP-10259
  if Boolean($package_manage) {
    package { $package_name:
      ensure => $package_ensure,
    }
  }
}
