#!/bin/sh
# Install the Yoga Pro 9 speaker fix. Run from this folder: sudo ./install.sh [SECONDS]
#
# SECONDS (optional): how long the speaker output stays open after sound stops, before it
# closes and the amps power down. Default 300 (5 minutes). 0 = never close. Reopening costs
# a ~2.5 s delay before sound starts. Example: sudo ./install.sh 600
# Without SECONDS, a value you set earlier is kept.
set -e
cd "$(dirname "$0")"

WP_CONF=/etc/wireplumber/wireplumber.conf.d/51-yoga-speaker-suspend.conf
if [ -n "$1" ]; then
	TIMEOUT=$1
elif [ -f "$WP_CONF" ]; then
	TIMEOUT=$(sed -n 's/.*suspend-timeout-seconds = \([0-9]*\).*/\1/p' "$WP_CONF")
fi
TIMEOUT=${TIMEOUT:-300}
case $TIMEOUT in
	''|*[!0-9]*) echo "SECONDS must be a whole number (got '$TIMEOUT')" >&2; exit 1 ;;
esac

install -m 755 yoga-speaker-fix.sh /usr/local/bin/yoga-speaker-fix.sh
install -m 644 yoga-speaker-fix.service yoga-speaker-fix-resume.service /etc/systemd/system/
install -m 644 99-yoga-speaker-amp.rules /etc/udev/rules.d/
mkdir -p "$(dirname "$WP_CONF")"
sed "s/suspend-timeout-seconds = [0-9]*/suspend-timeout-seconds = $TIMEOUT/" \
	51-yoga-speaker-suspend.conf > "$WP_CONF"
chmod 644 "$WP_CONF"

# Fedora uses SELinux: give the new files the right labels.
restorecon -R /usr/local/bin/yoga-speaker-fix.sh /etc/systemd/system/yoga-speaker-fix* \
	/etc/udev/rules.d/99-yoga-speaker-amp.rules /etc/wireplumber 2>/dev/null || true

# Remove older versions of this fix, if present.
for u in yoga-speakers.service yoga-amp-check.service yoga-amp-check-resume.service yoga-amp-check.timer; do
	systemctl disable "$u" 2>/dev/null || true
	rm -f /etc/systemd/system/"$u"
done
rm -f /usr/local/bin/yoga-amp-check.sh

systemctl daemon-reload
udevadm control --reload
systemctl enable yoga-speaker-fix.service yoga-speaker-fix-resume.service
echo "Installed. Speaker output stays open $TIMEOUT s after sound stops (0 = never closes)."
echo "Reboot, log in, then check: journalctl -b -t yoga-speaker-fix"
echo "(If only the time changed, no reboot needed: run 'systemctl --user restart wireplumber' as yourself.)"
