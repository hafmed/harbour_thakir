TARGET = harbour-thakir

CONFIG += sailfishapp sailfishapp_i18n qt5 link_pkgconfig
QT += network multimedia positioning location dbus sensors sql svg
PKGCONFIG += sailfishapp

TRANSLATIONS += \
    translations/harbour-thakir-ar.ts \
    translations/harbour-thakir-tr.ts \
    translations/harbour-thakir-fr.ts

# If you package nemo notifications support, uncomment and add:
#   PKGCONFIG += nemonotifications-qt5
# DEFINES += HAVE_NEMONOTIFICATIONS

SOURCES += \
    src/main.cpp \
    src/prayertimes.cpp \
    src/geocoder.cpp \
    src/prayermanager.cpp \
    src/playbackcontroller.cpp \
    src/islamicevents.cpp \
    src/quranmanager.cpp

HEADERS += \
    src/prayertimes.h \
    src/geocoder.h \
    src/prayermanager.h \
    src/playbackcontroller.h \
    src/settingshelper.h \
    src/powerbuttonwatcher.h \
    src/athannotification.h \
    src/silentmodehelper.h \
    src/eventsviewstatus.h \
    src/appdbusadaptor.h \
    src/islamicevents.h \
    src/quranmanager.h \
    src/quranpageimageprovider.h

OTHER_FILES += \
    qml/harbour-thakir.qml \
    qml/pages/*.qml \
    qml/cover/*.qml \
    qml/icons/*.svg \
    qml/icons/*.png \
    rpm/harbour-thakir.spec \
    harbour-thakir.desktop \
    dbus/*.service \
    sounds/Athkar/*.ogg \
    sounds/Athkar/*.mp3 \
    qml/pages/Images/*.png \
    qml/Images/*.png \
    qml/pages/Images/*.jpg \
    qml/Images/*.jpg \
    qml/pages/Images/*.svg \
    qml/Images/*.svg \
    qml/fonts/*

DISTFILES += \
    sounds/Athkar/*.ogg \
    sounds/Athkar/*.mp3 \
    qml/harbour-thakir.qml \
    qml/pages/MainPage.qml \
    qml/pages/Athkar.qml \
    qml/pages/CitySearchPage.qml \
    qml/pages/CityMapPage.qml \
    qml/pages/FavoritesPage.qml \
    qml/pages/SaveFavoriteDialog.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/AppearancePage.qml \
    qml/pages/LocationSettingsPage.qml \
    qml/pages/AlertSettingsPage.qml \
    qml/pages/SilentModeSettingsPage.qml \
    qml/pages/TimeAdjustmentsPage.qml \
    qml/pages/IslamicEventPage.qml \
    qml/pages/StopPage.qml \
    qml/pages/QiblaPage.qml \
    qml/pages/AboutPage.qml \
    qml/pages/QuranIndexPage.qml \
    qml/pages/QuranReaderPage.qml \
    qml/pages/QuranDownloadPage.qml \
    qml/pages/QuranTafsirPage.qml \
    qml/pages/QuranSearchStatsPage.qml \
    qml/pages/QuranListeningStatsPage.qml \
    qml/pages/TextModeDisclaimerDialog.qml \
    qml/pages/Images/*.png \
    qml/Images/*.png \
    qml/pages/Images/*.jpg \
    qml/Images/*.jpg \
    qml/pages/Images/*.svg \
    qml/Images/*.svg \
    qml/icons/*.svg \
    qml/fonts/* \
    qml/cover/CoverPage.qml

# Athan audio files - drop your own .ogg files here (see sounds/README.txt)
# and they will be installed under /usr/share/harbour-thakir/sounds/
sounds.files = sounds/*.ogg
sounds.path = /usr/share/harbour-thakir/sounds
INSTALLS += sounds

athkarsounds.files = $$files($$PWD/sounds/Athkar/*.ogg) $$files($$PWD/sounds/Athkar/*.mp3) sounds/Athkar/*.ogg sounds/Athkar/*.mp3
athkarsounds.path = /usr/share/harbour-thakir/sounds/Athkar
INSTALLS += athkarsounds

files.files = files/*
files.path = /usr/share/harbour-thakir/files
INSTALLS += files

data.files = data/quran.db data/audio_fixes
data.path = /usr/share/harbour-thakir/data
INSTALLS += data

quransvg.files = quran_svg
quransvg.path = /usr/share/harbour-thakir
INSTALLS += quransvg

translations.files = translations/*.qm
translations.path = /usr/share/harbour-thakir/translations
INSTALLS += translations

# App icons at Sailfish's standard sizes (placeholder artwork generated -
# swap these PNGs out for real icon art whenever you like).
icon86.files = icons/86x86/apps/harbour-thakir.png
icon86.path = /usr/share/icons/hicolor/86x86/apps
icon108.files = icons/108x108/apps/harbour-thakir.png
icon108.path = /usr/share/icons/hicolor/108x108/apps
icon128.files = icons/128x128/apps/harbour-thakir.png
icon128.path = /usr/share/icons/hicolor/128x128/apps
icon172.files = icons/172x172/apps/harbour-thakir.png
icon172.path = /usr/share/icons/hicolor/172x172/apps
INSTALLS += icon86 icon108 icon128 icon172

# SYSTEM-level (not --user) timer + service pair that wakes the device
# from real suspend every minute via WakeSystem=true and runs
# `harbour-thakir --check-and-play`. Installed automatically, but still
# needs a one-time, root-level enable after install (RPM installation
# can't do this for you) - see README.md.
checktimer.files = systemd/harbour-thakir-check.timer
checktimer.path = /usr/lib/systemd/system
INSTALLS += checktimer
checkservice.files = systemd/harbour-thakir-check.service
checkservice.path = /usr/lib/systemd/system
INSTALLS += checkservice

dbusservice.files = dbus/org.hafsoftdz.harbour-thakir.service dbus/org.hafsoftdz.harbour_thakir.service
dbusservice.path = /usr/share/dbus-1/services
INSTALLS += dbusservice
