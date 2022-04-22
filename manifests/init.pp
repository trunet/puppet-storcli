# storcli
#
# Main class, include all other classes.
#
# @param package_manage
#   Whether to manage the storcli package. Default value: value of megaraid['present?'].
#
# @param package_name
#   Specifies the storcli package to manage. Default value: ['storcli'].
#
# @param package_ensure
#   Whether to install the storcli package, and what version to install. Values: 'present', 'latest', or a specific version number.
#   Default value: 'present'.
#
# @param link_storcli_to
#   The official package puts the binary into /opt/MegaRAID/storcli which isn't usually in `$PATH`.
#   This module will put a link into another location so the binary is easily found.
#   Default value: /usr/local/sbin
#
class storcli (
  # Hiera can convert facts to strings, but we really want a bool
  # https://tickets.puppetlabs.com/browse/PUP-10259 
  Variant[Boolean, Enum['true', 'false']] $package_manage,
  Array[String] $package_name,
  String        $package_ensure,
  Stdlib::Absolutepath $link_storcli_to,
) {
  contain storcli::install
}
