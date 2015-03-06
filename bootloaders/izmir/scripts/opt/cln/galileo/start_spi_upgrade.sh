#!/bin/sh
# start_spi_upgrade.sh
# 
# The purpose of this script is to start the SPI Flash update mechanism
# Krzysztof.M.Sywula@intel.com
# manoel.c.ramon@intel.com - added firmware update control
set -e

validate_firmware_update ()
{
# this validation must be done only to Galileo Gen2
boardID=$(cat /sys/devices/virtual/dmi/id/board_name|sed "s:\\r::"|sed "s: ::"||sed "s:\\n::")

if [ $boardID != "GalileoGen2" ]
then
   # is not Gen 2 so the flash is ok to proceed
   echo "it is not gen 2!"
   return 0
else
   echo "it is a gen 2"
fi

# checking where the Flash Image Version starts
octal_offset=$(strings -o /tmp/spi_upgrade/galileo_firmware.bin |grep "Flash Image"|awk '{split($0,a," "); print a[1]}')
offset=$(printf "%d" 0$octal_offset)

# we have the offset available, let obtain only the release info
image_info=$(tail -c +$offset /tmp/spi_upgrade/galileo_firmware.bin|head|grep value|awk '{split($offset_text,a,"="); print a[2]}')

#let's clean any possible invalid char
image_info=$(echo $image_info|sed "s:\\r::"|sed "s: ::"||sed "s:\\n::")

echo "Candidate Release Version:"$image_info
candidate_dec=$(printf %u $image_info)

# checking the current version of this board
aux=$(cat /sys/firmware/board_data/flash_version)
board_dec=$(printf "%u" $aux)

echo "Board Release Version....:"$aux

# comparing the versions
if [ $board_dec -eq $candidate_dec ]
then
   echo "same version"
elif [ $board_dec -gt $candidate_dec ]
then
   echo "downgrade"
   # ops.. it is a downgrade it is under 1.0.2 we need to block it
   base=$(printf %u 0x01000200)
   if [ $candidate_dec -lt $base ]
   then
      echo "ABORTING!! this downgrade will brick galileo!"
      exit -1
   fi
else
   echo "upgrade"
fi

return 0

}


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

    #avoiding to brick the board
    validate_firmware_update
    

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
