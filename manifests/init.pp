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
# @param configure_settings
#   Should this class be able to enforce configuration settings on the controllers?
#   If you've got multiple controllers which should have different configs, you'll want to set this to false.
#   Default value: true
#
# @param controller_manage_rebuild
#   Should this class manage how the controller automatically rebuilds arrays
#   Default value: true
#
# @param controller_autorebuild
#   Should this controller automatically rebuild arrays
#   Default value: true
#
# @param controller_rebuildrate
#   Percentage of IO to dedicate to rebuilding an array
#   Default value: 60
#
# @param sync_time_to_controllers
#   Should controller clock be synced with the system clock?
#   Default value: true
#
# @param controller_use_utc
#   Should controller clock use UTC?
#   Default value: true
#
# @param controller_perfmode
#   Prioritize IOPS(0) or low latency(1)
#   Set as an integer should new modes be added
#   Default value: 0
#
# @param controller_ncq
#   Should Native Command Queue be enabled?
#   Default value: true
#
# @param controller_cacheflushinterval
#   Time in seconds between cache flushes
#   Default value: 4
#
# @param controller_bootwithpinnedcache
#   Continue booting with data stuck in cache?
#   Default value: false
#
# @param controller_manage_alarm
#   Should this class manage the alarm on the controller
#   Set to false if storcli cannot manage the alarm on a particular controller
#   Default value: true
#
# @param controller_alarm
#   Sound alarm when a disk is bad?
#   Datacenters with lots of hosts and noise may want to disable this.
#   Default value: true
#
# @param controller_smartpollinterval
#   Time in seconds between polling drive SMART errors (0-65535)
#   Default value: 60
#
# @param controller_patrolread_mode
#   Run patrolread either, auto, manual, or off
#   Default value: auto
#
# @param controller_patrolread_delay
#   Set the patrolread delay to this many hours
#   Default value: 336
#
# @param controller_patrolread_rate
#   Set the patrolread IO percentage
#   Default value: 30
#
# @param controller_patrolread_includessds
#   Should we patrol SSD devices
#   Default value: false
#
# @param controller_patrolread_uncfgareas
#   Should we patrol unconfigured areas
#   Default value: false
#
# @param controller_consistencycheck_mode
#   One of off, seq, conc
#   Default value: conc
#
# @param controller_consistencycheck_delay
#   Set the consistencycheck delay to this many hours
#   Default value: 672
#
# @param controller_consistencycheck_rate
#   Set the consistencycheck IO percentage
#   Default value: 30
#
class storcli (
  # Hiera can convert facts to strings, but we really want a bool
  # https://tickets.puppetlabs.com/browse/PUP-10259
  Variant[Boolean, Enum['true', 'false']] $package_manage,
  Array[String] $package_name,
  String        $package_ensure,
  Stdlib::Absolutepath $link_storcli_to,
  Boolean         $configure_settings,
  Boolean         $controller_manage_rebuild,
  Boolean         $controller_autorebuild,
  Integer[0, 100] $controller_rebuildrate,
  Boolean         $sync_time_to_controllers,
  Boolean         $controller_use_utc,
  Integer[0]      $controller_perfmode,
  Boolean         $controller_ncq,
  Integer[1]      $controller_cacheflushinterval,
  Boolean         $controller_bootwithpinnedcache,
  Boolean         $controller_manage_alarm,
  Boolean         $controller_alarm,
  Integer[0, 65535]             $controller_smartpollinterval,
  Enum['auto', 'manual', 'off'] $controller_patrolread_mode,
  Integer[0]                    $controller_patrolread_delay,
  Integer[0, 100]               $controller_patrolread_rate,
  Boolean                       $controller_patrolread_includessds,
  Boolean                       $controller_patrolread_uncfgareas,
  Enum['off', 'seq', 'conc']    $controller_consistencycheck_mode,
  Integer[0]                    $controller_consistencycheck_delay,
  Integer[0, 100]               $controller_consistencycheck_rate,
) {
  contain storcli::install
  contain storcli::configure

  Class['storcli::install'] -> Class['storcli::configure']
}
