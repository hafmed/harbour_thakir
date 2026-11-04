#ifndef PRAYERMANAGER_H
#define PRAYERMANAGER_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QDateTime>
#include <cmath>
#include "prayertimes.h"
#include "geocoder.h"

class QQmlEngine;
class QTranslator;
class QCoreApplication;
class QTimer;

// Central backend object exposed to QML as context property "prayerManager".
// It is instantiated both by the normal GUI process and by the headless
// "--play" invocation (see main.cpp), so all state is
// persisted via QSettings (an ini file shared by every invocation) rather
// than kept only in memory. This same binary's --check-and-play mode
// (see main.cpp), triggered periodically by a system timer, reads this
// same settings file directly for actual scheduled playback.
class PrayerManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString cityName READ cityName NOTIFY cityChanged)
    Q_PROPERTY(QString countryName READ countryName NOTIFY cityChanged)
    Q_PROPERTY(bool hasCity READ hasCity NOTIFY cityChanged)
    Q_PROPERTY(int method READ method WRITE setMethod NOTIFY methodChanged)
    Q_PROPERTY(int madhab READ madhab WRITE setMadhab NOTIFY madhabChanged)
    Q_PROPERTY(QVariantMap todayTimes READ todayTimes NOTIFY timesChanged)
    Q_PROPERTY(QVariantMap nightTimes READ nightTimes NOTIFY timesChanged)
    Q_PROPERTY(QString nextPrayerName READ nextPrayerName NOTIFY timesChanged)
    Q_PROPERTY(QString nextPrayerTime READ nextPrayerTime NOTIFY timesChanged)
    Q_PROPERTY(bool isNextPrayerTomorrow READ isNextPrayerTomorrow NOTIFY timesChanged)
    Q_PROPERTY(QString hijriDate READ hijriDate NOTIFY timesChanged)
    Q_PROPERTY(int hijriAdjustment READ hijriAdjustment WRITE setHijriAdjustment NOTIFY hijriAdjustmentChanged)
    Q_PROPERTY(bool isRamadan READ isRamadan NOTIFY timesChanged)
    Q_PROPERTY(QString imsakTime READ imsakTime NOTIFY timesChanged)
    Q_PROPERTY(int imsakMinutes READ imsakMinutes WRITE setImsakMinutes NOTIFY imsakMinutesChanged)
    Q_PROPERTY(bool showImsakAlways READ showImsakAlways WRITE setShowImsakAlways NOTIFY showImsakAlwaysChanged)
    Q_PROPERTY(QVariantMap enabledPrayers READ enabledPrayers NOTIFY enabledChanged)
    Q_PROPERTY(Geocoder *geocoder READ geocoder CONSTANT)
    Q_PROPERTY(QVariantList favorites READ favorites NOTIFY favoritesChanged)
    Q_PROPERTY(QString activeFavoriteId READ activeFavoriteId NOTIFY activeFavoriteChanged)
    Q_PROPERTY(QString activeFavoriteName READ activeFavoriteName NOTIFY activeFavoriteChanged)
    Q_PROPERTY(bool stopWithPowerButton READ stopWithPowerButton WRITE setStopWithPowerButton NOTIFY stopWithPowerButtonChanged)
    Q_PROPERTY(bool stopWithFlipOver READ stopWithFlipOver WRITE setStopWithFlipOver NOTIFY stopWithFlipOverChanged)
    Q_PROPERTY(bool stopWithVolumeButtons READ stopWithVolumeButtons WRITE setStopWithVolumeButtons NOTIFY stopWithVolumeButtonsChanged)
    Q_PROPERTY(bool turnOnScreen READ turnOnScreen WRITE setTurnOnScreen NOTIFY turnOnScreenChanged)
    Q_PROPERTY(bool showNotification READ showNotification WRITE setShowNotification NOTIFY showNotificationChanged)
    Q_PROPERTY(double qiblaBearing READ qiblaBearing NOTIFY cityChanged)
    Q_PROPERTY(double qiblaDistanceKm READ qiblaDistanceKm NOTIFY cityChanged)
    Q_PROPERTY(QString qiblaCompassDirection READ qiblaCompassDirection NOTIFY cityChanged)
    Q_PROPERTY(double latitude READ latitude NOTIFY cityChanged)
    Q_PROPERTY(double longitude READ longitude NOTIFY cityChanged)
    Q_PROPERTY(int compassCalibration READ compassCalibration WRITE setCompassCalibration NOTIFY compassCalibrationChanged)
    Q_PROPERTY(double sunBearing READ sunBearing NOTIFY celestialPositionsChanged)
    Q_PROPERTY(double sunAltitude READ sunAltitude NOTIFY celestialPositionsChanged)
    Q_PROPERTY(bool isDaytime READ isDaytime NOTIFY celestialPositionsChanged)
    Q_PROPERTY(QString sunCompassDirection READ sunCompassDirection NOTIFY celestialPositionsChanged)
    Q_PROPERTY(double moonBearing READ moonBearing NOTIFY celestialPositionsChanged)
    Q_PROPERTY(double moonAltitude READ moonAltitude NOTIFY celestialPositionsChanged)
    Q_PROPERTY(bool isMoonVisible READ isMoonVisible NOTIFY celestialPositionsChanged)
    Q_PROPERTY(QString moonCompassDirection READ moonCompassDirection NOTIFY celestialPositionsChanged)
    Q_PROPERTY(double moonPhase READ moonPhase NOTIFY celestialPositionsChanged)
    Q_PROPERTY(double moonIllumination READ moonIllumination NOTIFY celestialPositionsChanged)
    Q_PROPERTY(QString moonPhaseName READ moonPhaseName NOTIFY celestialPositionsChanged)
    Q_PROPERTY(double shadowBearing READ shadowBearing NOTIFY celestialPositionsChanged)
    Q_PROPERTY(QString shadowCompassDirection READ shadowCompassDirection NOTIFY celestialPositionsChanged)
    Q_PROPERTY(int qiblaMode READ qiblaMode WRITE setQiblaMode NOTIFY qiblaModeChanged)
    Q_PROPERTY(int celestialReference READ celestialReference WRITE setCelestialReference NOTIFY celestialReferenceChanged)
    Q_PROPERTY(int highLatitudeRule READ highLatitudeRule WRITE setHighLatitudeRule NOTIFY highLatitudeRuleChanged)
    Q_PROPERTY(bool use24HourFormat READ use24HourFormat WRITE setUse24HourFormat NOTIFY use24HourFormatChanged)
    Q_PROPERTY(int homeLayout READ homeLayout WRITE setHomeLayout NOTIFY homeLayoutChanged)
    Q_PROPERTY(int backgroundImage READ backgroundImage WRITE setBackgroundImage NOTIFY backgroundImageChanged)
    Q_PROPERTY(double backgroundOpacity READ backgroundOpacity WRITE setBackgroundOpacity NOTIFY backgroundOpacityChanged)
    Q_PROPERTY(QString dailyWisdom READ dailyWisdom NOTIFY timesChanged)
    Q_PROPERTY(bool hasIslamicEvent READ hasIslamicEvent NOTIFY timesChanged)
    Q_PROPERTY(QString islamicEventTitle READ islamicEventTitle NOTIFY timesChanged)
    Q_PROPERTY(QString islamicEventBanner READ islamicEventBanner NOTIFY timesChanged)
    Q_PROPERTY(QString islamicEventContent READ islamicEventContent NOTIFY timesChanged)
    Q_PROPERTY(QString appLanguage READ appLanguage WRITE setAppLanguage NOTIFY appLanguageChanged)
    Q_PROPERTY(bool isArabicLanguage READ isArabicLanguage NOTIFY appLanguageChanged)
    Q_PROPERTY(bool useHindiNumerals READ useHindiNumerals WRITE setUseHindiNumerals NOTIFY useHindiNumeralsChanged)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(QString osVersion READ osVersion CONSTANT)
    Q_PROPERTY(QString buildDate READ buildDate NOTIFY buildDateChanged)
    Q_PROPERTY(bool fridaySilentEnabled READ fridaySilentEnabled WRITE setFridaySilentEnabled NOTIFY fridaySilentChanged)
    Q_PROPERTY(int fridaySilentBeforeMinutes READ fridaySilentBeforeMinutes WRITE setFridaySilentBeforeMinutes NOTIFY fridaySilentChanged)
    Q_PROPERTY(int fridaySilentAfterMinutes READ fridaySilentAfterMinutes WRITE setFridaySilentAfterMinutes NOTIFY fridaySilentChanged)
    Q_PROPERTY(bool morningAthkarEnabled READ morningAthkarEnabled WRITE setMorningAthkarEnabled NOTIFY morningAthkarChanged)
    Q_PROPERTY(int morningAthkarMinutes READ morningAthkarMinutes WRITE setMorningAthkarMinutes NOTIFY morningAthkarChanged)
    Q_PROPERTY(bool eveningAthkarEnabled READ eveningAthkarEnabled WRITE setEveningAthkarEnabled NOTIFY eveningAthkarChanged)
    Q_PROPERTY(int eveningAthkarMinutes READ eveningAthkarMinutes WRITE setEveningAthkarMinutes NOTIFY eveningAthkarChanged)
    Q_PROPERTY(bool showInEventsView READ showInEventsView WRITE setShowInEventsView NOTIFY showInEventsViewChanged)
    Q_PROPERTY(int daylightSaving READ daylightSaving WRITE setDaylightSaving NOTIFY daylightSavingChanged)
    Q_PROPERTY(bool isDaylightSavingActive READ isDaylightSavingActive NOTIFY daylightSavingChanged)
    Q_PROPERTY(QString daylightSavingDescription READ daylightSavingDescription NOTIFY daylightSavingChanged)

public:
    explicit PrayerManager(QObject *parent = nullptr);

    QString appVersion() const { return QStringLiteral("3.5.9-1"); }
    QString osVersion() const;
    QString buildDate() const;
    QString cityName() const;
    QString countryName() const;
    bool hasCity() const;
    double latitude() const { return m_lat; }
    double longitude() const { return m_lon; }
    double qiblaBearing() const;
    double qiblaDistanceKm() const;
    QString qiblaCompassDirection() const;

    double sunBearing() const { return m_sunBearing; }
    double sunAltitude() const { return m_sunAltitude; }
    bool isDaytime() const { return m_isDaytime; }
    QString sunCompassDirection() const { return PrayerTimes::compassDirectionName(m_sunBearing); }

    double shadowBearing() const;
    QString shadowCompassDirection() const;

    double moonBearing() const { return m_moonBearing; }
    double moonAltitude() const { return m_moonAltitude; }
    bool isMoonVisible() const { return m_isMoonVisible; }
    QString moonCompassDirection() const { return PrayerTimes::compassDirectionName(m_moonBearing); }
    double moonPhase() const { return m_moonPhase; }
    double moonIllumination() const { return m_moonIllumination; }
    QString moonPhaseName() const { return m_moonPhaseName; }

    int qiblaMode() const;
    void setQiblaMode(int mode);
    int celestialReference() const;
    void setCelestialReference(int ref);
    int highLatitudeRule() const;
    void setHighLatitudeRule(int rule);
    bool use24HourFormat() const;
    void setUse24HourFormat(bool enabled);
    int homeLayout() const;
    void setHomeLayout(int layout);
    int backgroundImage() const;
    void setBackgroundImage(int index);
    double backgroundOpacity() const;
    void setBackgroundOpacity(double opacity);
    int daylightSaving() const { return m_daylightSaving; }
    void setDaylightSaving(int mode);
    bool isDaylightSavingActive() const;
    QString daylightSavingDescription() const;
    Q_INVOKABLE double effectiveDaylightOffset(const QDate &date = QDate()) const;
    static double staticTimezoneOffsetHoursFor(const QString &ianaId, const QString &countryCode,
                                               const QString &countryName, double lon,
                                               int daylightSavingMode, const QDate &date);

    Q_INVOKABLE void updateCelestialPositions();
    int method() const;
    void setMethod(int m);
    int madhab() const;
    void setMadhab(int m);
    QVariantMap todayTimes() const;
    // "midnight" (the midpoint of the night, Maghrib to next day's
    // Fajr) and "lastThird" (when the final third of that night
    // begins) - commonly shown alongside the five daily prayers, though
    // neither is a prayer with its own athan/enable toggle, purely
    // informational.
    QVariantMap nightTimes() const;
    QString nextPrayerName() const;
    QString nextPrayerTime() const;
    bool isNextPrayerTomorrow() const;
    QString hijriDate() const;
    QVariantMap enabledPrayers() const;
    Geocoder *geocoder();

    Q_INVOKABLE void selectCity(const QString &name, const QString &country,
                                 double latitude, double longitude,
                                 const QString &timezoneId, const QString &countryCode);
    Q_INVOKABLE void setPrayerEnabled(const QString &prayer, bool enabled);
    Q_INVOKABLE bool prayerEnabled(const QString &prayer) const;
    Q_INVOKABLE void setAthanSound(const QString &prayer, const QString &filePath);
    Q_INVOKABLE QString athanSound(const QString &prayer) const;
    // Lists .ogg files under /usr/share/harbour-thakir/sounds/ as
    // {"name": <display name>, "path": <full path>} entries, for the
    // Settings page's per-prayer sound picker.
    Q_INVOKABLE QVariantList availableSounds() const;
    // Minutes before a prayer to play a short "heads up" beep
    // (sounds/bip.ogg) - 0 means no pre-alert for that prayer. Defaults
    // to 10. Read/applied by the --check-and-play mode in main.cpp, not
    // by anything in this class directly.
    Q_INVOKABLE void setPreAlertMinutes(const QString &prayer, int minutes);
    Q_INVOKABLE int preAlertMinutes(const QString &prayer) const;
    Q_INVOKABLE int nextPrayerRemainingSeconds() const;
    Q_INVOKABLE bool isPreAlertWindow() const;
    Q_INVOKABLE QString dailyWisdom() const;
    bool hasIslamicEvent() const;
    QString islamicEventTitle() const;
    QString islamicEventBanner() const;
    QString islamicEventContent() const;

    // Silent-mode-after-prayer: a single global delay/duration (applies
    // whichever prayer triggers it), plus a per-prayer on/off toggle so
    // specific prayers (e.g. Fajr, if you rely on other alarms right
    // after) can be excluded. Actually switching the phone's profile
    // happens in main.cpp's --check-and-play mode, not in this class -
    // these are just the settings accessors the Settings page UI uses.
    Q_INVOKABLE void setSilentEnabled(const QString &prayer, bool enabled);
    Q_INVOKABLE bool silentEnabled(const QString &prayer) const;
    Q_INVOKABLE void setSilentDelayMinutes(int minutes);
    Q_INVOKABLE int silentDelayMinutes() const;
    Q_INVOKABLE void setSilentDelayMinutes(const QString &prayer, int minutes);
    Q_INVOKABLE int silentDelayMinutes(const QString &prayer) const;
    Q_INVOKABLE void setSilentDurationMinutes(int minutes);
    Q_INVOKABLE int silentDurationMinutes() const;
    Q_INVOKABLE void setSilentDurationMinutes(const QString &prayer, int minutes);
    Q_INVOKABLE int silentDurationMinutes(const QString &prayer) const;
    Q_INVOKABLE bool fridaySilentEnabled() const;
    Q_INVOKABLE void setFridaySilentEnabled(bool enabled);
    Q_INVOKABLE int fridaySilentBeforeMinutes() const;
    Q_INVOKABLE void setFridaySilentBeforeMinutes(int minutes);
    Q_INVOKABLE int fridaySilentAfterMinutes() const;
    Q_INVOKABLE void setFridaySilentAfterMinutes(int minutes);

    Q_INVOKABLE bool morningAthkarEnabled() const;
    Q_INVOKABLE void setMorningAthkarEnabled(bool enabled);
    Q_INVOKABLE int morningAthkarMinutes() const;
    Q_INVOKABLE void setMorningAthkarMinutes(int minutes);

    Q_INVOKABLE bool eveningAthkarEnabled() const;
    Q_INVOKABLE void setEveningAthkarEnabled(bool enabled);
    Q_INVOKABLE int eveningAthkarMinutes() const;
    Q_INVOKABLE void setEveningAthkarMinutes(int minutes);

    Q_INVOKABLE QStringList morningAthkarAudioPaths() const;
    Q_INVOKABLE QStringList eveningAthkarAudioPaths() const;
    Q_INVOKABLE QString resolveAthkarPath(const QString &relPath) const;

    Q_INVOKABLE bool showInEventsView() const;
    Q_INVOKABLE void setShowInEventsView(bool enabled);
    Q_INVOKABLE void updateEventsViewStatus();

    // Whether --check-and-play should skip playing the athan/pre-alert
    // entirely when the phone is currently in the "Silent" profile
    // (checked via profiled - see main.cpp) - respects a silent mode the
    // user set manually (or one this app's own
    // silent-mode-after-prayer feature is currently holding), rather
    // than forcing sound over it. Defaults to on; user-toggleable in
    // Settings. Read/applied in main.cpp, not by anything in this class
    // directly.
    Q_INVOKABLE void setRespectSilentMode(bool respect);
    Q_INVOKABLE bool respectSilentMode() const;

    Q_INVOKABLE void setStopWithPowerButton(bool enabled);
    Q_INVOKABLE bool stopWithPowerButton() const;

    Q_INVOKABLE void setStopWithFlipOver(bool enabled);
    Q_INVOKABLE bool stopWithFlipOver() const;

    Q_INVOKABLE void setStopWithVolumeButtons(bool enabled);
    Q_INVOKABLE bool stopWithVolumeButtons() const;

    Q_INVOKABLE void setTurnOnScreen(bool enabled);
    Q_INVOKABLE bool turnOnScreen() const;

    Q_INVOKABLE void setShowNotification(bool enabled);
    Q_INVOKABLE bool showNotification() const;

    Q_INVOKABLE void setHijriAdjustment(int days);
    Q_INVOKABLE int hijriAdjustment() const;
    Q_INVOKABLE bool isRamadan() const;
    Q_INVOKABLE QString imsakTime() const;
    Q_INVOKABLE int imsakMinutes() const;
    Q_INVOKABLE void setImsakMinutes(int mins);
    Q_INVOKABLE bool showImsakAlways() const;
    Q_INVOKABLE void setShowImsakAlways(bool always);

    Q_INVOKABLE void setCompassCalibration(int offset);
    Q_INVOKABLE int compassCalibration() const;

    Q_INVOKABLE int prayerAdjustment(const QString &prayer) const;
    Q_INVOKABLE void setPrayerAdjustment(const QString &prayer, int minutes);

    // Recomputed fresh on every call (not cached via NOTIFY) since it
    // changes continuously with real time, not just on settings changes
    // - call this periodically from a QML Timer to keep a displayed
    // countdown live. Returns e.g. "2h 15m" or "45m", or an empty
    // string if there's no city configured.
    Q_INVOKABLE QString nextPrayerCountdown() const;
    Q_INVOKABLE QString localizedPrayerName(const QString &prayerKey, bool isFriday = false, bool isTomorrow = false) const;
    Q_INVOKABLE QString localizedRemainingTime() const;
    Q_INVOKABLE QString randomWisdom(bool forceNew = false) const;

    // Progress towards next prayer (0.0 to 1.0) and percentages (0 to 100)
    Q_INVOKABLE double nextPrayerProgress() const;
    Q_INVOKABLE int nextPrayerRemainingPercentage() const;
    Q_INVOKABLE int nextPrayerElapsedPercentage() const;
    Q_INVOKABLE QString previousPrayerName() const;
    Q_INVOKABLE QString previousPrayerTime() const;

    // Recomputes today's and tomorrow's times (used to keep
    // todayTimes()/nextPrayerName() current for the UI). Call after any
    // setting change and on app start.
    Q_INVOKABLE void recalculateAndSchedule();

    // Called by the headless --play invocation for a specific prayer name.
    Q_INVOKABLE QString audioPathFor(const QString &prayer) const;

    // Favorites support: each favorite encapsulates a complete location
    // and all associated preferences (calculation method, madhab, sound
    // picks, pre-alerts, silent-mode settings).
    QVariantList favorites() const;
    QString activeFavoriteId() const;
    QString activeFavoriteName() const;

    Q_INVOKABLE QString saveCurrentAsFavorite(const QString &customName = QString());
    Q_INVOKABLE bool applyFavorite(const QString &favoriteId);
    Q_INVOKABLE bool updateFavorite(const QString &favoriteId);
    Q_INVOKABLE bool renameFavorite(const QString &favoriteId, const QString &newName);
    Q_INVOKABLE bool deleteFavorite(const QString &favoriteId);
    Q_INVOKABLE QString methodName(int methodIndex) const;
    Q_INVOKABLE QString madhabName(int madhabIndex) const;
    Q_INVOKABLE QString highLatitudeRuleName(int ruleIndex) const;
    Q_INVOKABLE double qiblaBearingFor(double lat, double lon) const;
    Q_INVOKABLE double qiblaDistanceFor(double lat, double lon) const;
    Q_INVOKABLE QString qiblaDirectionNameFor(double bearing) const;
    Q_INVOKABLE QString appLanguage() const;
    Q_INVOKABLE void setAppLanguage(const QString &lang);
    bool isArabicLanguage() const;
    bool useHindiNumerals() const;
    void setUseHindiNumerals(bool enable);
    Q_INVOKABLE QString formatDigits(const QString &str) const;
    Q_INVOKABLE QString formatDate(const QDate &date = QDate()) const;
    Q_INVOKABLE QString formatCurrentDateTime(const QDateTime &dt = QDateTime()) const;
    Q_INVOKABLE void checkNextPrayer();
    void setQmlEngine(QQmlEngine *engine);
    static void applyLanguage(const QString &lang);
    static void installAppTranslator(QCoreApplication *app = nullptr);

signals:
    void cityChanged();
    void methodChanged();
    void madhabChanged();
    void highLatitudeRuleChanged();
    void timesChanged();
    void enabledChanged();
    void soundsChanged();
    void favoritesChanged();
    void activeFavoriteChanged();
    void stopWithPowerButtonChanged();
    void stopWithFlipOverChanged();
    void stopWithVolumeButtonsChanged();
    void turnOnScreenChanged();
    void showNotificationChanged();
    void hijriAdjustmentChanged();
    void imsakMinutesChanged();
    void showImsakAlwaysChanged();
    void compassCalibrationChanged();
    void celestialPositionsChanged();
    void qiblaModeChanged();
    void celestialReferenceChanged();
    void use24HourFormatChanged();
    void homeLayoutChanged();
    void backgroundImageChanged();
    void backgroundOpacityChanged();
    void appLanguageChanged();
    void useHindiNumeralsChanged();
    void buildDateChanged();
    void fridaySilentChanged();
    void silentSettingsChanged();
    void morningAthkarChanged();
    void eveningAthkarChanged();
    void showInEventsViewChanged();
    void daylightSavingChanged();

private:
    double timezoneOffsetHoursFor(const QString &ianaId, const QDate &date) const;
    void configureCalculator(PrayerTimes &calc, const QDate &date) const;
    QVariantMap timesToMap(const PrayerTimes::Times &t) const;
    static bool isEuropeanDst(const QDate &date);
    static bool isEgyptDst(const QDate &date);
    static bool isNorthAmericanDst(const QDate &date);
    static double automaticDaylightOffset(const QString &countryCode, const QString &countryName, const QString &ianaId, const QDate &date);
    static double fallbackStandardOffset(const QString &countryCode, double lon);
    // Reasonable default calculation method per country, based on
    // commonly-used regional conventions (e.g. Umm al-Qura in Saudi
    // Arabia, ISNA in the US/Canada). Falls back to MWL (method 0) for
    // any country not specifically listed - not a judgment that MWL is
    // universally standard, just a reasonable global default. The user
    // can always override it afterward in Settings.
    static int defaultMethodForCountryCode(const QString &countryCode);
    static bool defaultHindiNumeralsForCountry(const QString &countryCode, const QString &countryName = QString(), const QString &timezoneId = QString());
    static int defaultBackgroundImageForCountry(const QString &countryCode, const QString &countryName = QString(), const QString &timezoneId = QString());

    // Shared by nextPrayerName()/nextPrayerTime()/nextPrayerCountdown()
    // so all three agree on exactly the same occurrence - checks today
    // first, then tomorrow, correctly rolling over (e.g. if every
    // enabled prayer today has already passed, this returns tomorrow's
    // first enabled one with tomorrow's actual date, not today's
    // already-passed time relabelled).
    struct NextOccurrence {
        QString prayer;
        QDateTime when; // invalid if hasCity() is false
    };
    struct PrayerInterval {
        NextOccurrence prev;
        NextOccurrence next;
        bool valid = false;
    };
    NextOccurrence computeNextOccurrence() const;
    PrayerInterval computePrayerInterval() const;

    static QJsonArray loadFavoritesJson();
    static void saveFavoritesJson(const QJsonArray &arr);

    Geocoder m_geocoder;
    QString m_cityName;
    QString m_countryName;
    QString m_countryCode;
    double m_lat = 0.0;
    double m_lon = 0.0;
    QString m_tzId;
    int m_daylightSaving = 0; // 0 = Auto (by country & city), 1 = Standard (Off), 2 = Daylight (+1h)
    int m_method = 0;
    int m_madhab = 0;
    int m_highLatitudeRule = 1;
    double m_sunBearing = 0.0;
    double m_sunAltitude = 0.0;
    bool m_isDaytime = false;
    double m_moonBearing = 0.0;
    double m_moonAltitude = 0.0;
    bool m_isMoonVisible = false;
    double m_moonPhase = 0.0;
    double m_moonIllumination = 0.0;
    QString m_moonPhaseName;

    mutable QStringList m_wisdomLines;
    void loadWisdomLines() const;

    QQmlEngine *m_engine = nullptr;
    QTranslator *m_translator = nullptr;
    QTimer *m_silentModeTimer = nullptr;
    QTimer *m_periodicTimer = nullptr;
    mutable QString m_lastNextPrayer;
    mutable bool m_lastIsNextPrayerTomorrow = false;
    mutable QDate m_lastDate;

private slots:
    void onPeriodicCheck();
};

#endif // PRAYERMANAGER_H
