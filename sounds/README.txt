Put your athan audio file(s) here as .ogg (e.g. adhan_court.ogg).
PrayerManager::athanSound() defaults every prayer to
/usr/share/harbour-thakir/sounds/adhan_court.ogg - either supply that
exact filename, or use the Settings page's sound picker to assign a
different one per prayer.

Also add:
- bip.ogg - a short "heads up" beep played some minutes before each
  prayer (configurable per-prayer in Settings, default 10 minutes,
  0/"Off" disables it).
- Beep.ogg (capital B) - played once when Silent mode is automatically
  switched on after a prayer, and again once when it switches back off
  - a confirmation "chime", distinct from the pre-alert bip.ogg.

Both paths are currently hardcoded in main.cpp (search for
"harbour-thakir/sounds/" there) rather than per-prayer configurable
like the athan sounds.

Use only audio you have the rights to redistribute (a Creative-Commons or
public-domain athan recording, or one you recorded/licensed yourself) -
don't bundle a copyrighted commercial reciter's track without permission.
For bip.ogg/Beep.ogg, short synthesized tones are easy to generate
yourself (e.g. via any audio editor or `ffmpeg`/`sox`) and avoid any
licensing question entirely.
