#!/bin/sh
# Install the Yoga Pro 9 speaker fix. Run from this folder: sudo ./install.sh
set -e
cd "$(dirname "$0")"

install -m 755 yoga-speaker-fix.sh /usr/local/bin/yoga-speaker-fix.sh
install -m 644 yoga-speaker-fix.service yoga-speaker-fix-resume.service /etc/systemd/system/
install -m 644 99-yoga-speaker-amp.rules /etc/udev/rules.d/

# Fedora uses SELinux: give the new files the right labels.
restorecon /usr/local/bin/yoga-speaker-fix.sh /etc/systemd/system/yoga-speaker-fix* \
	/etc/udev/rules.d/99-yoga-speaker-amp.rules 2>/dev/null || true

# Remove older versions of this fix, if present.
for u in yoga-speakers.service yoga-amp-check.service yoga-amp-check-resume.service yoga-amp-check.timer; do
	systemctl disable "$u" 2>/dev/null || true
	rm -f /etc/systemd/system/"$u"
done
rm -f /usr/local/bin/yoga-amp-check.sh

systemctl daemon-reload
udevadm control --reload
systemctl enable yoga-speaker-fix.service yoga-speaker-fix-resume.service
echo "Installed. Reboot, log in, then check: journalctl -b -t yoga-speaker-fix"
