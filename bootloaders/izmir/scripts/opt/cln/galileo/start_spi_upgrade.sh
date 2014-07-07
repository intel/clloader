#!/bin/sh
# start_spi_upgrade.sh
# 
# The purpose of this script is to start the SPI Flash update mechanism
# Krzysztof.M.Sywula@intel.com
set -e

log()
{
    # Unfortunately $$ is the parent ID in subprocesses
    printf '%s: %s.%s: ' "$(date +%F.%T)" "$0" "$$" # prefix
    printf "$@"        # actual log message
    # + klog?
}

log_error()
{
    local fst="$1"; shift || true
    1>&2 log "FAILED: $fst" "$@"
}

die()
{
    log_error "$@"
    exit 1
}

main()
{
    local MODULE="efi_capsule_update.ko"
    local SYSFS_PATH="/sys/firmware/efi_capsule/"
    local PATH_TO_FIRMWARE="/tmp/spi_upgrade/galileo_firmware.bin"
    [ -f $PATH_TO_FIRMWARE ] || die '%s does not exist' $PATH_TO_FIRMWARE

    #there might be another module providing the same sysfs interface
    #loaded before this script, so $MODULE does not have to load correctly
    modprobe $MODULE || true

    [ -d $SYSFS_PATH ] || die '%s does not exist. If running on < 0.9 release make sure to execute backward-compatibility script first.\n' $SYSFS_PATH

    # Setup path to new galileo capsule firmware image
    echo -n $PATH_TO_FIRMWARE > $SYSFS_PATH/capsule_path

    # Begin Capsule Update
    echo 1 > $SYSFS_PATH/capsule_update || die 'Upgrade trigger failed %s' $?
    log 'Upgrade trigger successfull %s, reboot the system' $?
}

main "$@"
