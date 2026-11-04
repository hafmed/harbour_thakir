# harbour-thakir

A single Sailfish OS app: pick any city in the world, get accurate
prayer times, and have the athan play automatically - GUI and
background playback are the same binary, one package.

## How it works

1. **GUI** (Silica/QML, `qml/`): pick a city either by text search or by
   tapping a point on a map (`qml/pages/CityMapPage.qml`, using
   `QtLocation`'s `osm` map plugin - see "Map picker" below for details
   and a caveat), see today's times plus tonight's Midnight/last-third
   and today's Hijri date, toggle which prayers play a sound, choose
   calculation method/madhab (auto-selected based on the picked city's
   country - see "Auto method selection" below - but always
   overridable), pick a per-prayer athan sound, set a per-prayer
   pre-alert beep lead time (see "Pre-alert beep" below), and configure
   automatic Silent-mode-after-prayer (see "Silent mode after prayer"
   below) (`src/prayertimes.cpp`, `src/prayermanager.cpp`).
2. **Storage**: all of the above is written to a plain QSettings ini
   file (`~/.config/org.hafsoftdz/harbour-thakir/harbour-thakir.conf`,
   complying with Sailjail sandboxing for `org.hafsoftdz`).
3. **Background playback**: `harbour-thakir --check-and-play` (see
   `main.cpp`'s `runCheckAndPlayMode()`) is a quick, one-shot check -
   "is any enabled prayer due right now and not already played today?
   if so, play it via `paplay`, then exit." It's triggered every minute
   by a **system-level** systemd timer
   (`systemd/harbour-thakir-check.timer`) using `WakeSystem=true`, which
   wakes the device from real suspend via the hardware RTC alarm. No
   long-running process, no GUI window needed.
4. **Manual test / on-demand play**: `harbour-thakir --play <prayer>`
   plays a given prayer's sound immediately and shows an on-screen Stop
   button (`qml/pages/StopPage.qml`) - handy for previewing.
   `--check-and-play` does not use this path itself (it calls `paplay`
   directly).

### Why a periodic RTC-wake check, and not a long-running daemon?

Two earlier approaches were tried and abandoned - worth knowing if
you're picking this project back up:

- **`timed` system alarms** (the daemon behind the stock Clock app),
  via both the `timedclient-qt5` CLI and the in-process `libtimed-qt5`
  C++ API. Every attempt was consistently rejected by `timed`
  (`cookie 0`) regardless of Sailjail sandboxing, argument-bearing vs.
  bare-path commands, or event flags - most likely a server-side policy
  restricting the `runCommand` action to a small set of trusted system
  apps, undocumented anywhere accessible.
- **A long-running `--daemon` process** holding an MCE "cpu keepalive"
  (`com.nokia.mce.request` / `req_cpu_keepalive_start`) for the whole
  wait between prayers, renewed every 4 minutes. This worked reliably
  for waits up to ~74 minutes in testing, but a real overnight test
  showed the renewals themselves silently stopped firing after
  ~75-80 minutes, well before the several-hour wait to the next prayer
  completed - strong evidence that Sailfish/systemd-logind was freezing
  the entire user session's process group once it was considered idle,
  independent of `cpu_keepalive` (which only prevents CPU/hardware
  suspend, not that separate freezing).

`WakeSystem=true` on a **system-level** timer sidesteps this: it uses
the hardware RTC alarm to wake the actual system, at a level below
whatever software session-freezing defeated the keepalive approach.
The trade-off is up to ~3 minutes of lateness (bounded by the 1-minute
check interval and a matching 3-minute tolerance window in
`runCheckAndPlayMode()`) rather than exact-second timing - reasonable
for an athan reminder, and also far more battery-friendly than the old
approach, since the device fully suspends between checks instead of
stashing awake for hours.

## Map picker

`qml/pages/CityMapPage.qml` (reached via "Pick on map instead" in the
city search page's pulldown menu) shows a pannable/zoomable
`QtLocation` `Map` using the free `osm` plugin (OpenStreetMap tiles, no
API key). Tap a point, tap "Use this location", and it:

1. Reverse-geocodes the tapped coordinate to a place name via
   OpenStreetMap's free Nominatim service (`Geocoder::reverseSearch()`
   in `src/geocoder.cpp`) - the geocoding API used for text search
   (Open-Meteo) is forward-only, so this is a separate service.
2. Re-runs that resolved name through the normal forward search, which
   does return a timezone (Nominatim doesn't), and auto-picks the
   first/closest match rather than showing a second list - tapping a
   map point is meant to be a faster path than text search, not an
   extra step.

**Caveat**: this is built against `QtLocation`/`QtPositioning` with the
`osm` geoservices plugin - confirmed as genuinely available and
Harbour-allowed on Sailfish (it's on Sailfish's own documented
"Allowed APIs" list, and used in several real third-party apps found
while researching this), but **not tested on-device** in this project
specifically. If the map doesn't render, check that
`qt5-plugin-geoservices-osm` and `qt5-qtlocation` are actually
installed on your SDK target/device (they should be, per the above,
but Sailfish's package set has varied across OS versions in the past).

## Auto method selection

`PrayerManager::defaultMethodForCountryCode()` (in
`src/prayermanager.cpp`) picks a calculation method automatically
whenever a city is selected (by search or map), based on commonly-used
regional conventions:

| Country/countries | Method |
|---|---|
| Saudi Arabia | Umm al-Qura (Makkah) |
| Algeria | Ministry of Religious Affairs & Wakfs (ALGERIA_MARWDZ) |
| Morocco | Ministry of Habous and Islamic Affairs, Morocco |
| Tunisia | Ministry of Religious Affairs (TUNISIA_MAIAMTU) |
| Libya | General Authority of Awqaf and Islamic Affairs (LIBYA_MARALI) |
| Jordan | Ministry of Awqaf & Islamic Affairs (JORDAN_MAIAHPJ) |
| Kuwait | Ministry of Awqaf and Islamic Affairs (KUWAIT_MARAKU) |
| Qatar | Qatar Calendar House (QATAR_TAQWMQAT) |
| Oman | Ministry of Endowments & Religious Affairs (OMAN_MARAOM) |
| Turkey | Presidency of Religious Affairs (TURKEY_DIYANET) |
| Malaysia | Department of Islamic Development (MALAYSIA_JAKIM) |
| France | Union of Islamic Organisations of France (FRANCE_UOIF) |
| Egypt, Syria, Lebanon, Sudan | Egyptian General Authority |
| USA, Canada | ISNA |
| Pakistan, India, Bangladesh, Afghanistan, Sri Lanka | University of Islamic Sciences, Karachi |
| Iran | Institute of Geophysics, Tehran |
| UK, Sweden, Norway, Finland, Denmark, Iceland | Prayer Times for High Latitudes |
| everywhere else | Muslim World League (MWL) |

This is a reasonable default, not a claim about what's "correct" for
any given place - the user can always override it afterward in
Settings, and doing so isn't overwritten again unless a *different*
city is subsequently selected.

## Respect phone's Silent mode

When enabled (default: on, toggleable in Settings via
`PrayerManager::respectSilentMode()`/`setRespectSilentMode()`), both the
athan and pre-alert beep are skipped - not forced - while the phone is
already in the "Silent" profile, whether the user set that manually or
this app's own "Silent mode after prayer" feature is currently holding
it. Checked via the same `getCurrentProfile()` (`profiled` over D-Bus)
used by that feature. When a prayer/pre-alert is skipped this way, it's
still marked as handled for the day (no retry within the tolerance
window), consistent with treating silence as intentional rather than
something to work around.

## Silent mode after prayer

`--check-and-play` can also automatically switch the phone to the
"Silent" profile for a while after each prayer, then switch back to
whatever profile was active before - configurable in Settings as a
single global delay ("starts N minutes after prayer") and duration,
plus a per-prayer on/off toggle (e.g. you might want it off for Fajr
if you rely on other alarms right after waking).

Implemented via Sailfish's profile daemon, `profiled`
(`com.nokia.profiled` on the **session** bus - a different service from
MCE, which is on the system bus - confirmed against Sailfish's own
`nemo-qml-plugin-dbus` example docs and a real-world working C++
implementation, both agreeing on the `set_profile`/`get_profile` API).
The switch only ever tracks one active window globally (not per-prayer)
since the phone only has one current profile regardless of which
prayer triggered it - if a window is already active when another
prayer's trigger fires, that trigger is marked handled for the day but
doesn't stack a second window on top. A short confirmation sound
(`sounds/Beep.ogg` - not included, add your own) plays once when it
switches on and once when it switches back off.

## Friday Dhuhr uses the pre-alert beep instead of the full athan

On Fridays, `--check-and-play` plays `sounds/bip.ogg` (the same short
beep used for the pre-alert - see below) for Dhuhr instead of the
full configured athan sound - not currently a user-configurable
setting, just hardcoded in `runCheckAndPlayMode()`
(`QDate::dayOfWeek() == 5`, ISO-8601 Friday). Only applies to the real
scheduled playback; the manual `harbour-thakir --play dhuhr` preview
mode always plays the assigned athan sound regardless of what day
it's run on.

## Pre-alert beep

In addition to the athan itself, `--check-and-play` can play a short
beep (`sounds/bip.ogg` - not included, add your own; see
`sounds/README.txt`) some configurable number of minutes before each
prayer - a "heads up, prayer soon" reminder. Set per-prayer in
Settings (default 10 minutes, "Off" disables it for that prayer). Uses
the same due/tolerance/de-duplication pattern as the main athan check,
just anchored to (prayer time - lead time) instead of the prayer time
itself, with its own `prealerted/<prayer>` settings key so it doesn't
interfere with the athan's own `played/<prayer>` tracking.

## Ramadan Isha adjustment (Umm al-Qura method)

`PrayerTimes::isRamadan()` (in `src/prayertimes.cpp`) implements the
standard tabular/civil Gregorian→Hijri calendar conversion (a fixed
arithmetic approximation - not true moon-sighting, since sighting-based
dates vary by locale and can't be computed with certainty in advance;
this is the same practical approach almost all prayer-time software
uses). When the Umm al-Qura (Makkah) calculation method is selected,
Isha automatically uses 120 minutes after Maghrib during Ramadan
instead of the normal 90 - matching Umm al-Qura's own published rule.
Accuracy is typically within a day of the locally-observed calendar,
which doesn't meaningfully affect this 90-vs-120-minute adjustment.

## Build (Sailfish SDK)

1. Install the [Sailfish OS SDK](https://sailfishos.org/wiki/Application_installation)
   and open this folder as a project in Sailfish IDE (or `mb2` from the CLI).
2. Targets needed: `Qt5Core`, `Qt5Qml`, `Qt5Quick`, `Qt5Network`,
   `Qt5Multimedia` (all standard on-device).
3. Build & deploy to emulator or a real device as usual.
4. Add your own `.ogg` athan recording(s) under `sounds/` before building
   (see `sounds/README.txt` - only use audio you have rights to
   redistribute). Multiple files let you assign different sounds per
   prayer from the Settings page.

## Enabling the timer

The package's `%post` install scriptlet (see `rpm/harbour-thakir.spec`)
now runs `systemctl daemon-reload` and
`systemctl enable --now harbour-thakir-check.timer` automatically -
this works because it's a **system-level** timer, whose systemd
instance (unlike a `--user` one) is always available even during a
background package install, so no manual step should be needed after
installing.

If it doesn't seem to be running for some reason (check with the
commands in the next section), you can always do it by hand over SSH:

```
devel-su systemctl daemon-reload
devel-su systemctl enable --now harbour-thakir-check.timer
```

Uninstalling the package (`%preun`) correspondingly disables the timer
automatically too.

## Checking it's working

```
systemctl status harbour-thakir-check.timer
systemctl list-timers harbour-thakir-check.timer
```

The second command shows when it last ran and when it'll run next. The
service logs to a plain file (see `Environment=QT_LOGGING_TO_CONSOLE=1`
and the shell-redirected `ExecStart` in
`systemd/harbour-thakir-check.service` - without both, Qt routes its
debug output into the systemd journal instead, which then needs
`journalctl` and its on-device permission quirks to read at all).
Check what the **most recent** run did (this file is overwritten each
run, since it fires every minute - it won't show history from before
now):

```
cat ~/.cache/harbour-thakir-check.log
```

You should see lines like:
```
harbour-thakir --check-and-play: playing athan for "fajr" "/usr/share/harbour-thakir/sounds/..." ( 42 s after scheduled time )
```
on the runs where a prayer was actually due, plus per-prayer diagnostic
lines every run (`due:`, `alreadyPlayedToday:`, silent-mode
starts/due/alreadyTriggeredToday, etc.) - useful for seeing exactly
why something did or didn't fire on the most recent check.

### Quick manual test without waiting for a real prayer time

Temporarily set the device clock (Settings > Date & Time, disable
auto-sync) to a minute or two after an enabled prayer's computed time,
then run:
```
harbour-thakir --check-and-play
```
directly - it should print a `playing athan for ...` line and you
should hear it. Remember to re-enable automatic time sync afterward.

## Things to double check on a real device/emulator

- **App icons**: `rpm/harbour-thakir.spec` expects
  `/usr/share/icons/hicolor/*/apps/harbour-thakir.png` at several sizes -
  add real artwork (86x86, 108x108, 128x128, 172x172 px are the usual
  Sailfish sizes; placeholders are already generated and wired up).
- **Nemo notifications**: `main.cpp` guards the notification code behind
  `HAVE_NEMONOTIFICATIONS` - install `nemonotifications-qt5` dev package,
  uncomment the two lines in `harbour-thakir.pro`, to get a proper
  lock-screen notification alongside the sound (currently only used by
  the on-demand `--play` mode, not by `--check-and-play`).
- **The hardcoded username/UID**: `systemd/harbour-thakir-check.service`
  has `User=defaultuser` and two `Environment=` lines referencing UID
  `100000` (`XDG_RUNTIME_DIR=/run/user/100000` and
  `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/100000/dbus/user_bus_socket`).
  These aren't values specific to any one device - `defaultuser`/UID
  `100000` are Sailfish OS's standard convention for the primary user
  account on essentially every stock installation, so this should work
  as-is for the vast majority of users without needing to change
  anything. That said, this has only actually been confirmed on one
  device/OS version (by reading it directly from a running session
  process - see below), not verified across every Sailfish release, so
  treat it as "very likely correct, but checkable" rather than
  guaranteed. If silent mode logs `could not reach profiled` (see
  `~/.cache/harbour-thakir-check.log`) on some device, confirm the real
  values there:
  ```
  id -u <username>                          # confirm the UID
  pgrep -l lipstick                         # find a running session process
  devel-su cat /proc/<pid>/environ | tr '\0' '\n' | grep -E 'XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS'
  ```
  and update the `.service` file to match, then `daemon-reload`.
- **Lateness window**: a prayer can play up to ~3 minutes after its
  exact calculated time (bounded by the 1-minute check interval and
  3-minute tolerance - tightened from an initial 5 min / 10 min once
  the underlying mechanism was confirmed reliable). Waking every
  minute uses somewhat more battery than every 5 minutes, though each
  wake is still just a quick check-and-exit, not a sustained hold, so
  the cost is far smaller than the old continuous-keepalive approach.
  For genuinely exact-second timing you'd need a per-day-regenerated
  exact-time timer instead of a periodic check - that needs root-level
  access to rewrite/reload a system timer daily, a real standing
  privilege trade-off that wasn't taken here; not implemented.
- Needs `paplay` (part of pulseaudio-utils, normally present on
  Sailfish).

## Project layout

```
harbour-thakir.pro          Qt project file
harbour-thakir.desktop      Launcher entry (Sailjail Internet permission)
rpm/harbour-thakir.spec     RPM packaging
systemd/                   The system-level WakeSystem timer + service
src/                       C++ backend (calc engine, geocoder, settings,
                            GUI entry point, and the check-and-play
                            logic - all in one binary)
qml/                       Silica UI
sounds/                    Drop your athan audio file(s) here
```
