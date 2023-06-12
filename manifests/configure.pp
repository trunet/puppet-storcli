# @summary Make any controller settings active
#
# Configure the storage controllers with the specified settings
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
class storcli::configure (
  # lint:ignore:parameter_types
  $configure_settings = $storcli::configure_settings,
  $controller_manage_rebuild = $storcli::controller_manage_rebuild,
  $controller_autorebuild = $storcli::controller_autorebuild,
  $controller_rebuildrate = $storcli::controller_rebuildrate,
  $sync_time_to_controllers = $storcli::sync_time_to_controllers,
  $controller_use_utc = $storcli::controller_use_utc,
  $controller_perfmode = $storcli::controller_perfmode,
  $controller_ncq = $storcli::controller_ncq,
  $controller_cacheflushinterval = $storcli::controller_cacheflushinterval,
  $controller_bootwithpinnedcache = $storcli::controller_bootwithpinnedcache,
  $controller_manage_alarm = $storcli::controller_manage_alarm,
  $controller_alarm = $storcli::controller_alarm,
  $controller_smartpollinterval = $storcli::controller_smartpollinterval,
  $controller_patrolread_mode = $storcli::controller_patrolread_mode,
  $controller_patrolread_delay = $storcli::controller_patrolread_delay,
  $controller_patrolread_rate = $storcli::controller_patrolread_rate,
  $controller_patrolread_includessds = $storcli::controller_patrolread_includessds,
  $controller_patrolread_uncfgareas = $storcli::controller_patrolread_uncfgareas,
  $controller_consistencycheck_mode = $storcli::controller_consistencycheck_mode,
  $controller_consistencycheck_delay = $storcli::controller_consistencycheck_delay,
  $controller_consistencycheck_rate = $storcli::controller_consistencycheck_rate,
  # lint:endignore
) inherits storcli {
  # lint:ignore:140chars
  if $configure_settings {
    if $facts['megaraid']['storcli'] {
      keys($facts['megaraid']['controllers']).each |$x| {
        $c = "/c${x}"
        $storcli = $facts['megaraid']['storcli']
        if 'perccli' in $storcli {
          $nolog = ''
        } else {
          $nolog = 'nolog'
        }

        if $controller_manage_rebuild {
          if $controller_autorebuild {
            exec { "Enable autorebuild on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set autorebuild=on ${nolog}",
              unless   => "${storcli} ${c} show autorebuild ${nolog} | grep AutoRebuild |grep ON",
              onlyif   => "${storcli} ${c} show autorebuild ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          } else {
            exec { "Disable autorebuild on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set autorebuild=off ${nolog}",
              unless   => "${storcli} ${c} show autorebuild ${nolog} | grep AutoRebuild |grep OFF",
              onlyif   => "${storcli} ${c} show autorebuild ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          }

          exec { "Set rebuildrate=${controller_rebuildrate}% on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set rebuildrate=${controller_rebuildrate} ${nolog}",
            unless   => "${storcli} ${c} show rebuildrate ${nolog} | grep Rebuildrate | grep ${controller_rebuildrate}%",
            onlyif   => "${storcli} ${c} show rebuildrate ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }

        if $sync_time_to_controllers {
          if $controller_use_utc {
            exec { "Set time on MegaRAID controller ${c} to UTC":
              command  => "${storcli} ${c} set time=$(date -u '+%Y%m%d %H:%M:%S') ${nolog}",
              unless   => "${storcli} ${c} show time ${nolog} | grep Time | grep $(date -u '+%Y/%m/%d') | grep $(date -u '+%H:')",
              onlyif   => "${storcli} ${c} show time ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          } else {
            exec { "Set time on MegaRAID controller ${c} to local time":
              command  => "${storcli} ${c} set time=systemtime ${nolog}",
              unless   => "${storcli} ${c} show time ${nolog} | grep Time | grep $(date '+%Y/%m/%d') | grep $(date '+%H:')",
              onlyif   => "${storcli} ${c} show time ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          }
        }

        exec { "Set perfmode=${controller_perfmode} on MegaRAID controller ${c}":
          command  => "${storcli} ${c} set perfmode=${controller_perfmode} ${nolog}",
          unless   => "${storcli} ${c} show perfmode ${nolog} | grep 'Perf Mode' | cut -d ' ' -f 3 | grep ${controller_perfmode}",
          onlyif   => "${storcli} ${c} show perfmode ${nolog} | grep 'Status = Success'",
          cwd      => '/tmp',
          provider => 'shell',
        }

        if $controller_ncq {
          exec { "Enable NCQ on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set ncq=on ${nolog}",
            unless   => "${storcli} ${c} show ncq ${nolog} | grep NCQ | grep ON",
            onlyif   => "${storcli} ${c} show ncq ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        } else {
          exec { "Disable NCQ on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set ncq=off ${nolog}",
            unless   => "${storcli} ${c} show ncq ${nolog} | grep NCQ | grep OFF",
            onlyif   => "${storcli} ${c} show ncq ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }

        exec { "Set cacheflushinterval=${controller_cacheflushinterval} on MegaRAID controller ${c}":
          command  => "${storcli} ${c} set cacheflushint=${controller_cacheflushinterval} ${nolog}",
          unless   => "${storcli} ${c} show cacheflushint ${nolog} | grep 'Cache Flush Interval' |grep '${controller_cacheflushinterval} sec'",
          onlyif   => "${storcli} ${c} show cacheflushint ${nolog} | grep 'Status = Success'",
          cwd      => '/tmp',
          provider => 'shell',
        }

        if $controller_bootwithpinnedcache {
          exec { "Enable bootwithpinnedcache on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set bootwithpinnedcache=on ${nolog}",
            unless   => "${storcli} ${c} show bootwithpinnedcache ${nolog} | grep 'Boot With Pinned Cache' |grep ON",
            onlyif   => "${storcli} ${c} show bootwithpinnedcache ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        } else {
          exec { "Disable bootwithpinnedcache on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set bootwithpinnedcache=off ${nolog}",
            unless   => "${storcli} ${c} show bootwithpinnedcache ${nolog} | grep 'Boot With Pinned Cache' |grep OFF",
            onlyif   => "${storcli} ${c} show bootwithpinnedcache ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }

        if $controller_manage_alarm {
          if $controller_alarm {
            exec { "Enable alarm sound on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set alarm=on ${nolog}",
              unless   => ["${storcli} ${c} show alarm ${nolog} | grep Alarm | grep ON", "${storcli} ${c} show alarm | grep ABSENT"],
              onlyif   => "${storcli} ${c} show alarm ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          } else {
            exec { "Disable alarm sound on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set alarm=off ${nolog}",
              unless   => ["${storcli} ${c} show alarm ${nolog} | grep Alarm | grep OFF", "${storcli} ${c} show alarm | grep ABSENT"],
              onlyif   => "${storcli} ${c} show alarm ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          }
        }

        exec { "Set smartpollinterval=${controller_smartpollinterval} on MegaRAID controller ${c}":
          command  => "${storcli} ${c} set smartpollinterval=${controller_smartpollinterval} ${nolog}",
          unless   => "${storcli} ${c} show smartpollinterval ${nolog} | grep 'SmartPollInterval' | grep '${controller_smartpollinterval} sec'",
          onlyif   => "${storcli} ${c} show smartpollinterval ${nolog} | grep 'Status = Success'",
          cwd      => '/tmp',
          provider => 'shell',
        }

        if $controller_patrolread_mode == 'off' {
          exec { "Disable patrolread on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set patrolread=off ${nolog}",
            unless   => "${storcli} ${c} show patrolRead ${nolog} | grep 'PR Mode' | grep Disable",
            onlyif   => "${storcli} ${c} show patrolRead ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        } else {
          exec { "Enable patrolread mode=${controller_patrolread_mode} on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set patrolread=on mode=${controller_patrolread_mode} ${nolog}",
            unless   => "${storcli} ${c} show patrolRead ${nolog} | grep 'PR Mode' | grep -i ${controller_patrolread_mode}",
            onlyif   => "${storcli} ${c} show patrolRead ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
          if $controller_patrolread_mode == 'auto' {
            exec { "Set patrolread delay=${controller_patrolread_delay} on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread delay=${controller_patrolread_delay} ${nolog}",
              unless   => "${storcli} ${c} show patrolRead ${nolog} | grep 'PR Execution Delay' | grep ${controller_patrolread_delay}",
              onlyif   => "${storcli} ${c} show patrolRead ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          }
          exec { "Set patrolread rate=${controller_patrolread_rate}% on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set prrate=${controller_patrolread_rate} ${nolog}",
            unless   => "${storcli} ${c} show prrate ${nolog} | grep 'Patrol Read Rate' | grep '${controller_patrolread_rate}%'",
            onlyif   => "${storcli} ${c} show patrolRead ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
          if $controller_patrolread_includessds {
            exec { "Enable patrolread on SSDs on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread includessds=on ${nolog}",
              unless   => "${storcli} ${c} show patrolRead ${nolog} | grep 'PR on SSD' | grep Enabled",
              onlyif   => "${storcli} ${c} show patrolRead ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          } else {
            exec { "Disable patrolread on SSDs on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread includessds=off ${nolog}",
              unless   => "${storcli} ${c} show patrolRead ${nolog} | grep 'PR on SSD' | grep Disabled",
              onlyif   => "${storcli} ${c} show patrolRead ${nolog} | grep 'Status = Success'",
              cwd      => '/tmp',
              provider => 'shell',
            }
          }
          if $controller_patrolread_uncfgareas {
            exec { "Enable patrolread on unconfigured areas on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread uncfgareas=on ${nolog}",
              unless   => "${storcli} ${c} show patrolRead ${nolog} | grep 'PR on EPD' | grep Enabled",
              onlyif   => ["${storcli} ${c} show patrolRead ${nolog} | grep 'Status = Success'", "${storcli} ${c} show patrolRead | grep 'PR on EPD'"],
              cwd      => '/tmp',
              provider => 'shell',
            }
          } else {
            exec { "Disable patrolread on unconfigured areas on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread uncfgareas=off ${nolog}",
              unless   => "${storcli} ${c} show patrolRead ${nolog} | grep 'PR on EPD' | grep Disabled",
              onlyif   => ["${storcli} ${c} show patrolRead ${nolog} | grep 'Status = Success'", "${storcli} ${c} show patrolRead | grep 'PR on EPD'"],
              cwd      => '/tmp',
              provider => 'shell',
            }
          }
        }

        if $controller_consistencycheck_mode == 'off' {
          exec { "Disable consistency check on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set cc=off ${nolog}",
            unless   => "${storcli} ${c} show cc ${nolog} | grep 'CC Operation Mode' | grep Disable",
            onlyif   => "${storcli} ${c} show cc ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        } else {
          # lint:ignore
          exec { "Enable consistency check mode=${controller_consistencycheck_mode} on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set cc=${controller_consistencycheck_mode} starttime=\"$(date -u '+%Y/%m/%d') 23\" ${nolog}",
            unless   => "${storcli} ${c} show cc ${nolog} | grep -e 'CC Mode\|CC Operation Mode' | grep -i ${controller_consistencycheck_mode}",
            onlyif   => "${storcli} ${c} show cc ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
          # lint:endignore
          exec { "Set consistency check delay=${controller_consistencycheck_delay} on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set cc delay=${controller_consistencycheck_delay} ${nolog}",
            unless   => "${storcli} ${c} show cc ${nolog} | grep 'CC Execution Delay' | grep ${controller_consistencycheck_delay}",
            onlyif   => "${storcli} ${c} show cc ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
          exec { "Set consistency check rate=${controller_consistencycheck_rate}% on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set ccrate=${controller_consistencycheck_rate} ${nolog}",
            unless   => "${storcli} ${c} show ccrate ${nolog} | grep 'CC Rate' | grep '${controller_consistencycheck_rate}%'",
            onlyif   => "${storcli} ${c} show ccrate ${nolog} | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }
      }
    }
  }
  # lint:endignore
}
