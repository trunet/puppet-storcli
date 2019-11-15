# storcli
#
# Main class, include all other classes.
#
# @param package_manage
#   Whether to manage the storcli package. Default value: true.
#
# @param package_name
#   Specifies the storcli package to manage. Default value: ['storcli'].
#
# @param package_ensure
#   Whether to install the storcli package, and what version to install. Values: 'present', 'latest', or a specific version number.
#   Default value: 'present'.
#
class storcli (
  Boolean       $package_manage,
  Array[String] $package_name,
  String        $package_ensure,
) {
  contain storcli::install
}
