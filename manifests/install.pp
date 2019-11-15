# @summary
#   This class handles storcli packages.
#
# @api private
#
class storcli::install {

  if $storcli::package_manage {

    package { $storcli::package_name:
      ensure => $storcli::package_ensure,
    }

  }

}
