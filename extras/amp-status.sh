#!/bin/sh
# Show the power register (book 0, page 0, register 0x02) of both woofer amps.
# Needs i2c-tools. Run with: sudo ./amp-status.sh
#   0x1a = the driver never set the amp up (woofers off: a bad boot)
#   0x02 = set up by the driver, idle (nothing playing)
#   0x00 = set up by the driver, playing
# Note: some bad boots show 0x00/0x02 too, so a "good" value doesn't prove the sound is good.
# The script switches the amp to page 0 / book 0 to read, then puts back what was selected.

AMPS="0x3f 0x38"   # I2C addresses of the two amps on the Yoga Pro 9 16IMH9

modprobe i2c-dev
dev=$(readlink -f /sys/bus/i2c/devices/i2c-TIAS2781:00) || { echo "TAS2781 amps not found"; exit 1; }
bus=${dev%/*}
bus=${bus##*/i2c-}

for a in $AMPS; do
	p=$(i2cget -f -y "$bus" "$a" 0x00) || { echo "$a: read error"; continue; }
	i2cset -f -y "$bus" "$a" 0x00 0x00
	b=$(i2cget -f -y "$bus" "$a" 0x7f)
	[ "$b" != 0x00 ] && i2cset -f -y "$bus" "$a" 0x7f 0x00
	echo "amp $a (bus $bus): reg 0x02 = $(i2cget -f -y "$bus" "$a" 0x02)"
	[ "$b" != 0x00 ] && i2cset -f -y "$bus" "$a" 0x7f "$b"
	i2cset -f -y "$bus" "$a" 0x00 "$p"
done
