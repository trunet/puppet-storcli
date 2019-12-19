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

    # Create a symbolic link to /usr/local/sbin
    file { '/usr/local/sbin/storcli64':
      ensure => 'link',
      target => '/opt/MegaRAID/storcli/storcli64',
    }

  }

}
