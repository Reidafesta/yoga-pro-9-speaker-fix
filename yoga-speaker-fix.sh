#!/bin/sh
# Yoga Pro 9 speaker fix (see README.md).
# On about half of all boots the two TAS2781 woofer amps are not set up properly, so only
# the tweeters play and the sound is thin and quiet. Reloading the amp driver AFTER the
# user's audio (PipeWire) is running, and then making PipeWire close and reopen the speaker
# output, makes the driver set the amps up correctly.
# Usage: yoga-speaker-fix.sh [delay-seconds]

MOD=snd_hda_scodec_tas2781_i2c   # kernel driver for the woofer amps
SINK_MATCH=Speaker__sink         # part of the speaker output's name in PipeWire

sleep "${1:-0}"

# Run pactl as user $1 (root can't talk to a user's PipeWire directly).
upactl() {
	uid=$1; shift
	runuser -u "$(id -nu "$uid")" -- env XDG_RUNTIME_DIR=/run/user/"$uid" pactl "$@"
}

# Print "uid sink-name" for every logged-in user whose PipeWire has the speaker output.
speaker_users() {
	for s in /run/user/*/pulse/native; do
		[ -S "$s" ] || continue
		uid=$(stat -c %u "$s")
		# Skip system users such as the login screen.
		[ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] || continue
		sink=$(upactl "$uid" list short sinks 2>/dev/null |
			awk -v m="$SINK_MATCH" 'index($2, m) {print $2; exit}')
		[ -n "$sink" ] && echo "$uid $sink"
	done
}

# 1. Wait until the sound card has picked up the amps.
i=0
until journalctl -k -b -o cat | grep -q 'bound i2c-TIAS2781'; do
	i=$((i + 1))
	[ $i -gt 120 ] && { echo "amps never bound to the sound card; giving up"; exit 1; }
	sleep 0.5
done

# 2. Wait (as long as it takes) for a user to log in and their PipeWire to show the speakers.
#    Doing the reload before this point does not fix the sound.
i=0
until [ -n "$(speaker_users)" ]; do
	i=$((i + 1))
	sleep 1
done
echo "user audio up after ${i} s wait"

# 3. Unload the amp driver. Right after boot it can still be busy loading its firmware
#    ("Module is in use"), so keep trying for up to 30 s.
i=0
until modprobe -r $MOD 2>/dev/null; do
	i=$((i + 1))
	[ $i -gt 60 ] && { echo "driver still in use after 30 s; giving up"; exit 1; }
	sleep 0.5
done
echo "driver unloaded after $i retries"

# 4. Load it again.
modprobe $MOD
sleep 2

# 5. Close and reopen the speaker output, so the driver sets the amps up again.
speaker_users | while read -r uid sink; do
	upactl "$uid" suspend-sink "$sink" 1
	sleep 1
	upactl "$uid" suspend-sink "$sink" 0
	echo "speakers reopened for $(id -nu "$uid")"
done
echo "done"
