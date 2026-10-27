#!/bin/sh
# Remove the Yoga Pro 9 speaker fix: sudo ./uninstall.sh
systemctl disable yoga-speaker-fix.service yoga-speaker-fix-resume.service
rm -f /usr/local/bin/yoga-speaker-fix.sh \
	/etc/systemd/system/yoga-speaker-fix.service \
	/etc/systemd/system/yoga-speaker-fix-resume.service \
	/etc/udev/rules.d/99-yoga-speaker-amp.rules
systemctl daemon-reload
udevadm control --reload
echo "Removed. Reboot to go back to the default behaviour."
