# @summary Make any controller settings active
#
# Configure the storage controllers with the specified settings
#
# @param configure_settings
#   Should this class be able to enforce configuration settings on the controllers?
#   If you've got multiple controllers which should have different configs, you'll want to set this to false.
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
  $configure_settings = $storcli::configure_settings,
  $controller_autorebuild = $storcli::controller_autorebuild,
  $controller_rebuildrate = $storcli::controller_rebuildrate,
  $sync_time_to_controllers = $storcli::sync_time_to_controllers,
  $controller_use_utc = $storcli::controller_use_utc,
  $controller_perfmode = $storcli::controller_perfmode,
  $controller_ncq = $storcli::controller_ncq,
  $controller_cacheflushinterval = $storcli::controller_cacheflushinterval,
  $controller_bootwithpinnedcache = $storcli::controller_bootwithpinnedcache,
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
) inherits storcli{
  if $configure_settings {
    if $facts['megaraid']['storcli'] {
      keys($facts['megaraid']['controllers']).each |$x| {
        $c = "/c${x}"
        $storcli = $facts['megaraid']['storcli']

        if $controller_autorebuild {
          exec { "Enable autorebuild on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set autorebuild=on",
            unless   => "${storcli} ${c} show autorebuild J | grep '\"Value\" : \"ON\"'",
            provider => 'shell',
          }
        } else {
          exec { "Disable autorebuild on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set autorebuild=off",
            unless   => "${storcli} ${c} show autorebuild J | grep '\"Value\" : \"OFF\"'",
            provider => 'shell',
          }
        }

        exec { "Set rebuildrate=${controller_rebuildrate}% on MegaRAID controller ${c}":
          command  => "${storcli} ${c} set rebuildrate=${controller_rebuildrate}",
          unless   => "${storcli} ${c} show autorebuild | grep '\"Value\" : \"${controller_rebuildrate}%\"'",
          provider => 'shell',
        }

        if $sync_time_to_controllers {
          if $controller_use_utc {
            exec { "Set time on MegaRAID controller ${c} to UTC":
              command  => "${storcli} ${c} set time=$(date -u +%Y%m%d %H:%M:%S)",
              unless   => "${storcli} ${c} show time J | grep Value | grep $(date -u '+%Y/%m/%d') | grep $(date -u '+%H:')",
              provider => 'shell',
            }
          } else {
            exec { "Set time on MegaRAID controller ${c} to local time":
              command  => "${storcli} ${c} set time=systemtime",
              unless   => "${storcli} ${c} show time J | grep Value | grep $(date '+%Y/%m/%d') | grep $(date '+%H:')",
              provider => 'shell',
            }
          }
        }

        exec { "Set perfmode=${controller_perfmode} on MegaRAID controller ${c}":
          command  => "${storcli} ${c} set perfmode=${controller_perfmode}",
          unless   => "${storcli} ${c} show perfmode J | grep '\"Value\" : \"${controller_perfmode}'",
          provider => 'shell',
        }

        if $controller_ncq {
          exec { "Enable NCQ on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set ncq=on",
            unless   => "${storcli} ${c} show ncq J | grep '\"Value\" : \"ON\"'",
            provider => 'shell',
          }
        } else {
          exec { "Disable NCQ on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set ncq=off",
            unless   => "${storcli} ${c} show ncq J | grep '\"Value\" : \"OFF\"'",
            provider => 'shell',
          }
        }

        exec { "Set cacheflushinterval=${controller_cacheflushinterval} on MegaRAID controller ${c}":
          command  => "${storcli} ${c} set cacheflushint=${controller_cacheflushinterval}",
          unless   => "${storcli} ${c} show cacheflushint J | grep '\"Value\" : \"${controller_cacheflushinterval}'",
          provider => 'shell',
        }

        if $controller_bootwithpinnedcache {
          exec { "Enable bootwithpinnedcache on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set bootwithpinnedcache=on",
            unless   => "${storcli} ${c} show bootwithpinnedcache J | grep '\"Value\" : \"ON\"'",
            provider => 'shell',
          }
        } else {
          exec { "Disable bootwithpinnedcache on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set bootwithpinnedcache=off",
            unless   => "${storcli} ${c} show bootwithpinnedcache J | grep '\"Value\" : \"OFF\"'",
            provider => 'shell',
          }
        }

        if $controller_alarm {
          exec { "Enable alarm sound on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set alarm=on",
            unless   => "${storcli} ${c} show alarm J | grep '\"Value\" : \"ON\"'",
            provider => 'shell',
          }
        } else {
          exec { "Disable alarm sound on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set alarm=off",
            unless   => "${storcli} ${c} show alarm J | grep '\"Value\" : \"OFF\"'",
            provider => 'shell',
          }
        }

        exec { "Set smartpollinterval=${controller_smartpollinterval} on MegaRAID controller ${c}":
          command  => "${storcli} ${c} set smartpollinterval=${controller_smartpollinterval}",
          unless   => "${storcli} ${c} show smartpollinterval J | grep '\"Value\" : \"${controller_smartpollinterval}'",
          provider => 'shell',
        }

        if $controller_patrolread_mode == 'off' {
          exec { "Disable patrolread on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set patrolread=off",
            unless   => "${storcli} ${c} show patrolRead | grep 'PR Mode' | grep Disable",
            provider => 'shell',
          }
        } else {
          exec { "Enable patrolread mode=${controller_patrolread_mode} on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set patrolread=on mode=${controller_patrolread_mode}",
            unless   => "${storcli} ${c} show patrolRead | grep 'PR Mode' | grep -i ${controller_patrolread_mode}",
            provider => 'shell',
          }
          if $controller_patrolread_mode == 'auto' {
            exec { "Set patrolread delay=${controller_patrolread_delay} on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread delay=${controller_patrolread_delay}",
              unless   => "${storcli} ${c} show patrolRead | grep 'PR Execution Delay' | grep ${controller_patrolread_delay}",
              provider => 'shell',
            }
          }
          exec { "Set patrolread rate=${controller_patrolread_rate}% on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set prrate=${controller_patrolread_rate}",
            unless   => "${storcli} ${c} show prrate J | grep '\"Value\" : \"${controller_patrolread_rate}'",
            provider => 'shell',
          }
          if $controller_patrolread_includessds {
            exec { "Enable patrolread on SSDs on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread includessds=on",
              unless   => "${storcli} ${c} show patrolRead | grep 'PR on SSD' | grep Enabled",
              provider => 'shell',
            }
          } else {
            exec { "Disable patrolread on SSDs on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread includessds=off",
              unless   => "${storcli} ${c} show patrolRead | grep 'PR on SSD' | grep Disabled",
              provider => 'shell',
            }
          }
          if $controller_patrolread_uncfgareas {
            exec { "Enable patrolread on unconfigured areas on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread uncfgareas=on",
              unless   => "${storcli} ${c} show patrolRead | grep 'PR on EPD' | grep Enabled",
              provider => 'shell',
            }
          } else {
            exec { "Disable patrolread on unconfigured areas on MegaRAID controller ${c}":
              command  => "${storcli} ${c} set patrolread uncfgareas=off",
              unless   => "${storcli} ${c} show patrolRead | grep 'PR on EPD' | grep Disabled",
              provider => 'shell',
            }
          }
        }

        if $controller_consistencycheck_mode == 'off' {
          exec { "Disable consistency check on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set cc=off",
            unless   => "${storcli} ${c} show cc | grep 'CC Operation Mode' | grep Disable",
            provider => 'shell',
          }
        } else {
          exec { "Enable consistency check mode=${controller_consistencycheck_mode} on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set cc=${controller_consistencycheck_mode} startime=$(date -u '+%Y/%m/%d') 23",
            unless   => "${storcli} ${c} show cc | grep 'CC Mode' | grep -i ${controller_consistencycheck_mode}",
            provider => 'shell',
          }
          exec { "Set consistency check delay=${controller_consistencycheck_delay} on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set cc delay=${controller_consistencycheck_delay}",
            unless   => "${storcli} ${c} show cc | grep 'PR Execution Delay' | grep ${controller_consistencycheck_delay}",
            provider => 'shell',
          }
          exec { "Set consistency check rate=${controller_consistencycheck_rate}% on MegaRAID controller ${c}":
            command  => "${storcli} ${c} set ccrate=${controller_consistencycheck_rate}",
            unless   => "${storcli} ${c} show ccrate J | grep '\"Value\" : \"${controller_consistencycheck_rate}'",
            provider => 'shell',
          }
        }
      }
    }
  }
}
