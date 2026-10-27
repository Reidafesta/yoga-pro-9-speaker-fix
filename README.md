# Lenovo Yoga Pro 9 (16IMH9) on Linux: fixing thin, quiet speakers

On Linux, the speakers of the Lenovo Yoga Pro 9 16IMH9 sound thin, tinny and much too quiet
on about **half of all boots**. On the other boots they sound fine. This repo explains why and
contains a small fix that makes every boot sound good.

## Tested on

| | |
|---|---|
| Laptop | Lenovo Yoga Pro 9 16IMH9 (Yoga Pro 9i Gen 9, machine type **83DN**), Intel Meteor Lake |
| BIOS | NKCN32WW |
| OS | Fedora 44, KDE Plasma |
| Kernel | 7.2.11 |
| Audio | PipeWire 1.6.10, EasyEffects 8.2.8 (optional) |

Other laptops with Texas Instruments **TAS2781** speaker amps may have the same problem, but
they haven't been tested.

To find out whether you have these amps, run:

```sh
ls /sys/bus/i2c/devices/ | grep TIAS2781
```

If this prints `i2c-TIAS2781:00`, you have them.

## The problem

- **Symptom:** sometimes, after you turn the laptop on, the speakers sound thin, have no bass
  and are very quiet, even at 100 % volume. Reboot, and they may sound fine again. It's
  random, roughly 50/50.
- **What's not the cause:** volume, ALSA mixer settings, PipeWire settings and EasyEffects.
  These were compared on good and bad boots and were identical.

## The cause

The laptop has four speakers:

- **2 tweeters** (high notes), driven directly by the Realtek sound chip. These always work.
- **2 woofers** (bass and most of the loudness), driven by two separate amplifier chips, the
  **TI TAS2781**. They are connected over I2C (bus 2, addresses `0x3f` and `0x38`) and are set
  up by the kernel driver `snd_hda_scodec_tas2781_i2c`.

On a bad boot, the driver doesn't set the two woofer amps up properly, so they stay off. All
you hear are the tweeters, which explains the thin, quiet sound.

Reading the amps' power register (book 0, page 0, register `0x02`) on a bad boot often gives
`0x1a`, the amp's power-on default: the driver never set the amp up. On a good boot, the
register reads `0x00` while sound is playing and `0x02` when nothing is playing. Some bad
boots also show normal values, so the register can't reliably tell whether a boot is bad. It's
probably a timing bug in the driver at boot, but the exact bug in the driver hasn't been found.

What **does** fix it, every time:

1. **Unload and reload the amp driver** (`modprobe -r` then `modprobe`), and
2. **make PipeWire close and reopen the speaker output.** When the output opens again, the
   driver sets the amps up correctly.

**Timing matters.** This only works if it happens *after you log in*, once your user's
PipeWire is running. Reloading the driver earlier in boot, before login, doesn't help. An
older version of this fix did that and the sound stayed thin.

## The fix

A small script runs automatically at every boot and after waking from sleep. It:

1. waits until the sound card has picked up the amps,
2. waits until you log in and your audio is running (usually about 20 s after power-on),
3. unloads the amp driver, retrying for a few seconds if it is still busy loading its firmware,
4. loads the driver again,
5. tells PipeWire to close and reopen the speaker output.

The script runs on every boot, good or bad, because a bad boot can't be detected reliably.
Reloading on a good boot does no harm.

**What you'll notice:** for a few seconds after you log in, the sound may still be thin. It
gets fixed about 5 seconds after your desktop appears.

### Files in this repo

| File | What it is |
|---|---|
| `yoga-speaker-fix.sh` | The fix script (the steps above). Installed to `/usr/local/bin/`. |
| `yoga-speaker-fix.service` | Runs the script at every boot. |
| `yoga-speaker-fix-resume.service` | Runs the script after waking from sleep or hibernation. |
| `99-yoga-speaker-amp.rules` | Keeps the amps' I2C device from going into power saving. |
| `install.sh` / `uninstall.sh` | Install or remove everything above in one go. |
| `easyeffects/Yoga Speakers Tuned.json` | Optional EQ preset for better sound (see below). |
| `extras/amp-status.sh` | Optional: shows the amps' power register, for diagnosing. |

## Install (quick way)

```sh
git clone https://github.com/Reidafesta/yoga-pro-9-speaker-fix.git
cd yoga-pro-9-speaker-fix
sudo ./install.sh
reboot
```

No git? On the repo's GitHub page, click **Code → Download ZIP**, unzip it, open a terminal in
the folder, and run `sudo ./install.sh`.

## Install (by hand, step by step)

This does exactly what `install.sh` does. Run these commands from inside the repo folder.

**Step 1: copy the script into place and make it executable.**
```sh
sudo install -m 755 yoga-speaker-fix.sh /usr/local/bin/yoga-speaker-fix.sh
```
`/usr/local/bin` is the standard place for scripts you add yourself. `-m 755` makes the
script executable.

**Step 2: copy the two systemd services.**
```sh
sudo install -m 644 yoga-speaker-fix.service yoga-speaker-fix-resume.service /etc/systemd/system/
```
systemd starts programs at boot. The first service runs the script at boot. The second runs it
5 seconds after the laptop wakes from sleep, because the amps can come back badly from sleep
too.

**Step 3: copy the udev rule.**
```sh
sudo install -m 644 99-yoga-speaker-amp.rules /etc/udev/rules.d/
```
This stops the kernel from putting the amps' I2C connection into power-saving mode. It was part
of the setup the fix was tested with.

**Step 4 (Fedora and other SELinux systems): fix the file labels.**
```sh
sudo restorecon /usr/local/bin/yoga-speaker-fix.sh /etc/systemd/system/yoga-speaker-fix* /etc/udev/rules.d/99-yoga-speaker-amp.rules
```
If you skip this, SELinux may block the script. On distros without SELinux (Ubuntu, Arch),
skip this step.

**Step 5: tell systemd and udev about the new files, and turn the services on.**
```sh
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo systemctl enable yoga-speaker-fix.service yoga-speaker-fix-resume.service
```
`enable` means the services start automatically from now on.

**Step 6: reboot and log in.**

## Check that it worked

After logging in, wait about 10 seconds, then run:

```sh
journalctl -b -t yoga-speaker-fix
```

You should see something like this:

```
yoga-speaker-fix[996]: user audio up after 15 s wait
yoga-speaker-fix[996]: driver unloaded after 0 retries
yoga-speaker-fix[996]: speakers reopened for yourname
yoga-speaker-fix[996]: done
```

Then play some music. It should sound full, with bass.

## Sound still thin? Run the fix by hand

```sh
sudo /usr/local/bin/yoga-speaker-fix.sh
```

This does the same reload and reopen right away. If this fixes the sound but the automatic run
doesn't, check the log (above) for errors.

If the sound is *still* thin after a manual run, check that:

- the speaker output exists: `pactl list short sinks | grep Speaker__sink`. If it has a
  different name, change `SINK_MATCH=` at the top of `/usr/local/bin/yoga-speaker-fix.sh`.
- the driver loads: `lsmod | grep tas2781`.
- the amp firmware is installed: `ls /lib/firmware/ | grep TAS2XXX`. On Fedora it comes with
  the `linux-firmware` package.

## Optional: better sound with EasyEffects

The fix above makes the woofers work. To make the speakers sound even better, you can add an
equalizer. The preset in this repo uses the EQ curve from
[maximmaxim345/yoga_pro_9i_gen9_linux](https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux)
(v2), plus loudness compensation and a limiter with +6 dB input gain.

1. Install EasyEffects: `sudo dnf install easyeffects` (Fedora) or use your distro's package.
2. Copy the preset:
   ```sh
   mkdir -p ~/.local/share/easyeffects/output
   cp "easyeffects/Yoga Speakers Tuned.json" ~/.local/share/easyeffects/output/
   ```
   (Flatpak EasyEffects uses `~/.var/app/com.github.wwmm.easyeffects/data/easyeffects/output/`.)
3. Open EasyEffects. In **Presets**, load **Yoga Speakers Tuned**.
4. In the same Presets menu, set **Yoga Speakers Tuned** as the **autoload** preset for the
   **Speaker** output device. If an older autoload rule points at a different preset, change it
   or delete it, so EasyEffects doesn't load the wrong preset at startup.
5. In EasyEffects **Preferences**, turn on **Launch service at system startup**.

## Optional: look at the amps' registers

```sh
sudo dnf install i2c-tools        # provides i2cget/i2cset
sudo ./extras/amp-status.sh
```

`0x1a` means the amp was never set up (a bad boot). `0x00` means it's playing and `0x02` means
it's idle. Some bad boots also show normal values, which is why the fix doesn't rely on this
check.

## Uninstall

```sh
sudo ./uninstall.sh
reboot
```

## Things that did *not* fix it

To save you time:

- Raising volume, or changing ALSA mixer levels or EasyEffects gain: the woofers are off, so
  there's nothing to turn up.
- Reloading the driver early in boot (a common tip): at that point the sound card hasn't picked
  up the amps yet, so the reload does nothing.
- Reloading the driver after the amps are picked up but before login: the register looks
  configured, but the sound stays thin.
- Flipping the power register to "on" by hand with `i2cset`: it gets louder, but the sound is
  distorted, because the rest of the amp's settings are still missing.

## Credits

- [maximmaxim345/yoga_pro_9i_gen9_linux](https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux):
  EQ curve and community notes on the TAS2781 woofer problem.

## License

MIT. See `LICENSE`.
