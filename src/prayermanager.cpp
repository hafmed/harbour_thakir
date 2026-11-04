#include "prayermanager.h"
#include "settingshelper.h"
#include "eventsviewstatus.h"
#include "islamicevents.h"

#include <QSettings>
#include <QDateTime>
#include <QTimeZone>
#include <QTimer>
#include "silentmodehelper.h"
#include <QDir>
#include <QFileInfo>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QTextStream>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QTranslator>
#include <sailfishapp.h>
#include <cmath>
#include <cstdlib>
#include <algorithm>
#include <random>

static const char *PRAYER_NAMES[6] = {"fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"};

PrayerManager::PrayerManager(QObject *parent) : QObject(parent)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    SettingsHelper::ensureSanity(s);
    m_cityName = s.value("city/name").toString();
    m_countryName = s.value("city/country").toString();
    m_countryCode = s.value("city/countryCode").toString();
    m_lat = s.value("city/lat", 0.0).toDouble();
    m_lon = s.value("city/lon", 0.0).toDouble();
    m_tzId = s.value("city/tz", "UTC").toString();
    m_daylightSaving = s.value("prefs/daylightSaving", 0).toInt();
    m_method = s.value("prefs/method", 0).toInt();
    m_madhab = s.value("prefs/madhab", 0).toInt();
    m_highLatitudeRule = s.value("prefs/highLatitudeRule", 1).toInt();
    updateCelestialPositions();

    m_silentModeTimer = new QTimer(this);
    m_silentModeTimer->setInterval(30000);
    connect(m_silentModeTimer, &QTimer::timeout, this, []() {
        SilentModeHelper::checkAllSilentModes();
    });
    m_silentModeTimer->start();
    SilentModeHelper::checkAllSilentModes();

    m_lastDate = QDate::currentDate();
    m_lastNextPrayer = nextPrayerName();
    m_lastIsNextPrayerTomorrow = isNextPrayerTomorrow();

    m_periodicTimer = new QTimer(this);
    m_periodicTimer->setInterval(1000);
    connect(m_periodicTimer, &QTimer::timeout, this, &PrayerManager::onPeriodicCheck);
    m_periodicTimer->start();
}

QString PrayerManager::cityName() const { return m_cityName; }
QString PrayerManager::countryName() const { return m_countryName; }
bool PrayerManager::hasCity() const { return !m_cityName.isEmpty(); }
int PrayerManager::method() const { return m_method; }
int PrayerManager::madhab() const { return m_madhab; }
int PrayerManager::highLatitudeRule() const { return m_highLatitudeRule; }
Geocoder *PrayerManager::geocoder() { return &m_geocoder; }

void PrayerManager::setMethod(int m)
{
    if (m_method == m) return;
    m_method = m;
    SettingsHelper::setValue("prefs/method", m_method);
    emit methodChanged();
    recalculateAndSchedule();
}

void PrayerManager::setMadhab(int m)
{
    if (m_madhab == m) return;
    m_madhab = m;
    SettingsHelper::setValue("prefs/madhab", m_madhab);
    emit madhabChanged();
    recalculateAndSchedule();
}

void PrayerManager::setHighLatitudeRule(int rule)
{
    if (rule < 0 || rule > 3) rule = 1;
    if (m_highLatitudeRule == rule) return;
    m_highLatitudeRule = rule;
    SettingsHelper::setValue("prefs/highLatitudeRule", m_highLatitudeRule);
    emit highLatitudeRuleChanged();
    recalculateAndSchedule();
}

void PrayerManager::selectCity(const QString &name, const QString &country,
                                double latitude, double longitude,
                                const QString &timezoneId, const QString &countryCode)
{
    m_cityName = name;
    m_countryName = country;
    m_lat = latitude;
    m_lon = longitude;
    m_tzId = timezoneId;
    m_countryCode = countryCode.trimmed().toUpper();
    m_method = defaultMethodForCountryCode(countryCode);

    bool useHindi = defaultHindiNumeralsForCountry(countryCode, country, timezoneId);
    setUseHindiNumerals(useHindi);

    if (!SettingsHelper::value(QStringLiteral("backgroundImageCustomized"), false).toBool()) {
        int defBg = defaultBackgroundImageForCountry(countryCode, country, timezoneId);
        int currentBg = backgroundImage();
        SettingsHelper::setValue(QStringLiteral("backgroundImage"), defBg);
        SettingsHelper::setValue(QStringLiteral("backgroundImageCustomized"), false);
        if (currentBg != defBg) {
            emit backgroundImageChanged();
        }
    }

    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    s.setValue("city/name", m_cityName);
    s.setValue("city/country", m_countryName);
    s.setValue("city/countryCode", m_countryCode);
    s.setValue("city/lat", m_lat);
    s.setValue("city/lon", m_lon);
    s.setValue("city/tz", m_tzId);
    s.setValue("prefs/method", m_method);

    SettingsHelper::setValue("favorites/activeId", QString());

    emit cityChanged();
    emit methodChanged();
    emit daylightSavingChanged();
    emit activeFavoriteChanged();
    emit favoritesChanged();
    recalculateAndSchedule();
}

int PrayerManager::defaultMethodForCountryCode(const QString &countryCode)
{
    const QString cc = countryCode.toUpper();

    // Umm al-Qura, Makkah
    if (cc == QStringLiteral("SA")) return PrayerTimes::Makkah;

    // Algeria - Ministry of Religious Affairs and Wakfs
    if (cc == QStringLiteral("DZ")) return PrayerTimes::AlgeriaMARWDZ;

    // Morocco - Ministry of Habous and Islamic Affairs
    if (cc == QStringLiteral("MA")) return PrayerTimes::Morocco;

    // Tunisia - Ministry of Religious Affairs
    if (cc == QStringLiteral("TN")) return PrayerTimes::TunisiaMAIAMTU;

    // Libya - General Authority of Awqaf and Islamic Affairs
    if (cc == QStringLiteral("LY")) return PrayerTimes::LibyaMARALI;

    // Egypt, Syria, Lebanon, Sudan
    if (cc == QStringLiteral("EG") || cc == QStringLiteral("SY")
        || cc == QStringLiteral("LB") || cc == QStringLiteral("SD"))
        return PrayerTimes::Egyptian;

    // Jordan - Ministry of Awqaf, Islamic Affairs and Holy Places
    if (cc == QStringLiteral("JO")) return PrayerTimes::JordanMAIAHPJ;

    // Kuwait - Ministry of Awqaf and Islamic Affairs
    if (cc == QStringLiteral("KW")) return PrayerTimes::KuwaitMARAKU;

    // Qatar - Qatar Calendar House
    if (cc == QStringLiteral("QA")) return PrayerTimes::QatarTAQWMQAT;

    // Oman - Ministry of Endowments and Religious Affairs
    if (cc == QStringLiteral("OM")) return PrayerTimes::OmanMARAOM;

    // Turkey - Presidency of Religious Affairs (Diyanet)
    if (cc == QStringLiteral("TR")) return PrayerTimes::TurkeyDiyanet;

    // Malaysia - Department of Islamic Development (JAKIM)
    if (cc == QStringLiteral("MY")) return PrayerTimes::MalaysiaJAKIM;

    // France - Union of Islamic Organisations of France (UOIF)
    if (cc == QStringLiteral("FR")) return PrayerTimes::FranceUOIF;

    // Islamic Society of North America
    if (cc == QStringLiteral("US") || cc == QStringLiteral("CA"))
        return PrayerTimes::ISNA;

    // University of Islamic Sciences, Karachi
    if (cc == QStringLiteral("PK") || cc == QStringLiteral("IN")
        || cc == QStringLiteral("BD") || cc == QStringLiteral("AF")
        || cc == QStringLiteral("LK"))
        return PrayerTimes::Karachi;

    // Institute of Geophysics, Tehran
    if (cc == QStringLiteral("IR")) return PrayerTimes::Tehran;

    // High Latitude countries (UK, Scandinavia, Iceland)
    if (cc == QStringLiteral("GB") || cc == QStringLiteral("SE")
        || cc == QStringLiteral("NO") || cc == QStringLiteral("FI")
        || cc == QStringLiteral("DK") || cc == QStringLiteral("IS"))
        return PrayerTimes::HighLatitude;

    // Muslim World League - reasonable global default, and already
    // matches most of North Africa, the Gulf (outside Saudi), Turkey,
    // Southeast Asia, and Europe in common practice.
    return PrayerTimes::MWL;
}

bool PrayerManager::defaultHindiNumeralsForCountry(const QString &countryCode, const QString &countryName, const QString &timezoneId)
{
    const QString cc = countryCode.trimmed().toUpper();

    // Middle East, Gulf, Egypt, Sudan, and related regions where Eastern Arabic / Hindi numerals are standard:
    // Saudi Arabia (SA), Egypt (EG), United Arab Emirates (AE), Kuwait (KW), Qatar (QA),
    // Bahrain (BH), Oman (OM), Yemen (YE), Iraq (IQ), Jordan (JO), Syria (SY), Lebanon (LB),
    // Palestine (PS), Sudan (SD), Iran (IR), Afghanistan (AF), Pakistan (PK)
    if (cc == QStringLiteral("SA") || cc == QStringLiteral("EG") || cc == QStringLiteral("AE")
        || cc == QStringLiteral("KW") || cc == QStringLiteral("QA") || cc == QStringLiteral("BH")
        || cc == QStringLiteral("OM") || cc == QStringLiteral("YE") || cc == QStringLiteral("IQ")
        || cc == QStringLiteral("JO") || cc == QStringLiteral("SY") || cc == QStringLiteral("LB")
        || cc == QStringLiteral("PS") || cc == QStringLiteral("SD") || cc == QStringLiteral("IR")
        || cc == QStringLiteral("AF") || cc == QStringLiteral("PK")) {
        return true;
    }

    QString c = countryName.trimmed().toLower();
    if (c.contains(QStringLiteral("saudi")) || countryName.contains(QString::fromUtf8("السعودية"))
        || c.contains(QStringLiteral("egypt")) || countryName.contains(QString::fromUtf8("مصر"))
        || c.contains(QStringLiteral("emirates")) || countryName.contains(QString::fromUtf8("الإمارات"))
        || c.contains(QStringLiteral("kuwait")) || countryName.contains(QString::fromUtf8("الكويت"))
        || c.contains(QStringLiteral("qatar")) || countryName.contains(QString::fromUtf8("قطر"))
        || c.contains(QStringLiteral("bahrain")) || countryName.contains(QString::fromUtf8("البحرين"))
        || c.contains(QStringLiteral("oman")) || countryName.contains(QString::fromUtf8("عمان"))
        || c.contains(QStringLiteral("yemen")) || countryName.contains(QString::fromUtf8("اليمن"))
        || c.contains(QStringLiteral("iraq")) || countryName.contains(QString::fromUtf8("العراق"))
        || c.contains(QStringLiteral("jordan")) || countryName.contains(QString::fromUtf8("الأردن"))
        || c.contains(QStringLiteral("syria")) || countryName.contains(QString::fromUtf8("سوريا"))
        || c.contains(QStringLiteral("lebanon")) || countryName.contains(QString::fromUtf8("لبنان"))
        || c.contains(QStringLiteral("palestine")) || countryName.contains(QString::fromUtf8("فلسطين"))
        || c.contains(QStringLiteral("sudan")) || countryName.contains(QString::fromUtf8("السودان"))) {
        return true;
    }

    QString tz = timezoneId.trimmed().toLower();
    if (tz.contains(QStringLiteral("riyadh")) || tz.contains(QStringLiteral("cairo"))
        || tz.contains(QStringLiteral("dubai")) || tz.contains(QStringLiteral("kuwait"))
        || tz.contains(QStringLiteral("qatar")) || tz.contains(QStringLiteral("bahrain"))
        || tz.contains(QStringLiteral("muscat")) || tz.contains(QStringLiteral("aden"))
        || tz.contains(QStringLiteral("baghdad")) || tz.contains(QStringLiteral("amman"))
        || tz.contains(QStringLiteral("damascus")) || tz.contains(QStringLiteral("beirut"))
        || tz.contains(QStringLiteral("gaza")) || tz.contains(QStringLiteral("hebron"))
        || tz.contains(QStringLiteral("khartoum")) || tz.contains(QStringLiteral("tehran"))) {
        return true;
    }

    return false;
}

int PrayerManager::defaultBackgroundImageForCountry(const QString &countryCode, const QString &countryName, const QString &timezoneId)
{
    const QString cc = countryCode.trimmed().toUpper();
    const QString c = countryName.trimmed().toLower();
    const QString tz = timezoneId.trimmed().toLower();

    // Djamaa el Djazaïr (Great Mosque of Algiers, index 17) is default for Algeria
    if (cc == QStringLiteral("DZ")
        || c.contains(QStringLiteral("algeria"))
        || countryName.contains(QString::fromUtf8("الجزائر"))
        || tz.contains(QStringLiteral("algiers"))) {
        return 17;
    }

    return 1;
}

void PrayerManager::setPrayerEnabled(const QString &prayer, bool enabled)
{
    SettingsHelper::setValue(QString("enabled/%1").arg(prayer), enabled);
    emit enabledChanged();
    recalculateAndSchedule();
}

bool PrayerManager::prayerEnabled(const QString &prayer) const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    bool def = (prayer != QLatin1String("sunrise"));
    return s.value(QString("enabled/%1").arg(prayer), def).toBool();
}

QVariantMap PrayerManager::enabledPrayers() const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QVariantMap m;
    for (const char *p : PRAYER_NAMES) {
        // sunrise has no athan by default, everything else defaults on
        bool def = (QString(p) != "sunrise");
        m[p] = s.value(QString("enabled/%1").arg(p), def).toBool();
    }
    return m;
}

void PrayerManager::setAthanSound(const QString &prayer, const QString &filePath)
{
    SettingsHelper::setValue(QString("sound/%1").arg(prayer), filePath);
    emit soundsChanged();
}

QString PrayerManager::athanSound(const QString &prayer) const
{
    return SettingsHelper::value(QString("sound/%1").arg(prayer),
                                 "/usr/share/harbour-thakir/sounds/adhan_court.ogg").toString();
}

void PrayerManager::setPreAlertMinutes(const QString &prayer, int minutes)
{
    if (minutes < 0) minutes = 0;
    SettingsHelper::setValue(QString("prealert/%1").arg(prayer), minutes);
}

int PrayerManager::preAlertMinutes(const QString &prayer) const
{
    return SettingsHelper::value(QString("prealert/%1").arg(prayer), 10).toInt();
}

void PrayerManager::setSilentEnabled(const QString &prayer, bool enabled)
{
    SettingsHelper::setValue(QString("silentenabled/%1").arg(prayer), enabled);
    if (enabled) {
        SettingsHelper::setValue(QString("silenttriggered/%1").arg(prayer), QString());
    }
    emit silentSettingsChanged();
    SilentModeHelper::checkAllSilentModes();
}

bool PrayerManager::silentEnabled(const QString &prayer) const
{
    return SettingsHelper::value(QString("silentenabled/%1").arg(prayer), true).toBool();
}

void PrayerManager::setSilentDelayMinutes(int minutes)
{
    if (minutes < 0) minutes = 0;
    SettingsHelper::setValue("silent/delayMinutes", minutes);
    emit silentSettingsChanged();
    SilentModeHelper::checkAllSilentModes();
}

int PrayerManager::silentDelayMinutes() const
{
    return SettingsHelper::value("silent/delayMinutes", 10).toInt();
}

void PrayerManager::setSilentDelayMinutes(const QString &prayer, int minutes)
{
    if (minutes < 0) minutes = 0;
    SettingsHelper::setValue(QString("silentdelay/%1").arg(prayer), minutes);
    SettingsHelper::setValue(QString("silenttriggered/%1").arg(prayer), QString());
    emit silentSettingsChanged();
    SilentModeHelper::checkAllSilentModes();
}

int PrayerManager::silentDelayMinutes(const QString &prayer) const
{
    int def = silentDelayMinutes();
    return SettingsHelper::value(QString("silentdelay/%1").arg(prayer), def).toInt();
}

void PrayerManager::setSilentDurationMinutes(int minutes)
{
    if (minutes < 0) minutes = 0;
    SettingsHelper::setValue("silent/durationMinutes", minutes);
    emit silentSettingsChanged();
    SilentModeHelper::checkAllSilentModes();
}

int PrayerManager::silentDurationMinutes() const
{
    return SettingsHelper::value("silent/durationMinutes", 15).toInt();
}

void PrayerManager::setSilentDurationMinutes(const QString &prayer, int minutes)
{
    if (minutes < 0) minutes = 0;
    SettingsHelper::setValue(QString("silentduration/%1").arg(prayer), minutes);
    emit silentSettingsChanged();
    SilentModeHelper::checkAllSilentModes();
}

int PrayerManager::silentDurationMinutes(const QString &prayer) const
{
    int def = silentDurationMinutes();
    return SettingsHelper::value(QString("silentduration/%1").arg(prayer), def).toInt();
}

bool PrayerManager::fridaySilentEnabled() const
{
    return SettingsHelper::value(QStringLiteral("fridaySilent/enabled"), true).toBool();
}

void PrayerManager::setFridaySilentEnabled(bool enabled)
{
    if (fridaySilentEnabled() == enabled)
        return;
    SettingsHelper::setValue(QStringLiteral("fridaySilent/enabled"), enabled);
    if (enabled) {
        SettingsHelper::setValue(QStringLiteral("silenttriggered/friday_dhuhr"), QString());
    }
    emit fridaySilentChanged();
    SilentModeHelper::checkAllSilentModes();
}

int PrayerManager::fridaySilentBeforeMinutes() const
{
    return SettingsHelper::value(QStringLiteral("fridaySilent/beforeMinutes"), 30).toInt();
}

void PrayerManager::setFridaySilentBeforeMinutes(int minutes)
{
    if (minutes < 0) minutes = 0;
    if (fridaySilentBeforeMinutes() == minutes)
        return;
    SettingsHelper::setValue(QStringLiteral("fridaySilent/beforeMinutes"), minutes);
    SettingsHelper::setValue(QStringLiteral("silenttriggered/friday_dhuhr"), QString());
    emit fridaySilentChanged();
    SilentModeHelper::checkAllSilentModes();
}

int PrayerManager::fridaySilentAfterMinutes() const
{
    return SettingsHelper::value(QStringLiteral("fridaySilent/afterMinutes"), 30).toInt();
}

void PrayerManager::setFridaySilentAfterMinutes(int minutes)
{
    if (minutes < 0) minutes = 0;
    if (fridaySilentAfterMinutes() == minutes)
        return;
    SettingsHelper::setValue(QStringLiteral("fridaySilent/afterMinutes"), minutes);
    emit fridaySilentChanged();
    SilentModeHelper::checkAllSilentModes();
}

void PrayerManager::setRespectSilentMode(bool respect)
{
    SettingsHelper::setValue("respectSilentMode", respect);
}

bool PrayerManager::respectSilentMode() const
{
    return SettingsHelper::value("respectSilentMode", true).toBool();
}

void PrayerManager::setStopWithPowerButton(bool enabled)
{
    SettingsHelper::setValue("stopWithPowerButton", enabled);
    emit stopWithPowerButtonChanged();
}

bool PrayerManager::stopWithPowerButton() const
{
    return SettingsHelper::value("stopWithPowerButton", true).toBool();
}

void PrayerManager::setStopWithFlipOver(bool enabled)
{
    SettingsHelper::setValue("stopWithFlipOver", enabled);
    emit stopWithFlipOverChanged();
}

bool PrayerManager::stopWithFlipOver() const
{
    return SettingsHelper::value("stopWithFlipOver", true).toBool();
}

void PrayerManager::setStopWithVolumeButtons(bool enabled)
{
    SettingsHelper::setValue("stopWithVolumeButtons", enabled);
    emit stopWithVolumeButtonsChanged();
}

bool PrayerManager::stopWithVolumeButtons() const
{
    return SettingsHelper::value("stopWithVolumeButtons", true).toBool();
}

void PrayerManager::setTurnOnScreen(bool enabled)
{
    SettingsHelper::setValue("turnOnScreenDuringPlayback", enabled);
    emit turnOnScreenChanged();
}

bool PrayerManager::turnOnScreen() const
{
    return SettingsHelper::value("turnOnScreenDuringPlayback", false).toBool();
}

void PrayerManager::setShowNotification(bool enabled)
{
    SettingsHelper::setValue("showNotification", enabled);
    emit showNotificationChanged();
}

bool PrayerManager::showNotification() const
{
    return SettingsHelper::value("showNotification", true).toBool();
}

void PrayerManager::setUse24HourFormat(bool enabled)
{
    SettingsHelper::setValue("use24HourFormat", enabled);
    emit use24HourFormatChanged();
    emit timesChanged();
}

bool PrayerManager::use24HourFormat() const
{
    return SettingsHelper::value("use24HourFormat", false).toBool();
}

void PrayerManager::setHomeLayout(int layout)
{
    if (layout < 0 || layout > 3) layout = 0;
    SettingsHelper::setValue("homeLayout", layout);
    emit homeLayoutChanged();
}

int PrayerManager::homeLayout() const
{
    return SettingsHelper::value("homeLayout", 0).toInt();
}

int PrayerManager::backgroundImage() const
{
    if (!SettingsHelper::contains(QStringLiteral("backgroundImage"))) {
        const QString tz = m_tzId.isEmpty() ? QString::fromUtf8(QTimeZone::systemTimeZoneId()) : m_tzId;
        return defaultBackgroundImageForCountry(QString(), m_countryName, tz);
    }
    int stored = SettingsHelper::value(QStringLiteral("backgroundImage"), 1).toInt();
    if (stored == 1 && !SettingsHelper::value(QStringLiteral("backgroundImageCustomized"), false).toBool()) {
        const QString tz = m_tzId.isEmpty() ? QString::fromUtf8(QTimeZone::systemTimeZoneId()) : m_tzId;
        if (defaultBackgroundImageForCountry(QString(), m_countryName, tz) == 17) {
            return 17;
        }
    }
    return stored;
}

void PrayerManager::setBackgroundImage(int index)
{
    if (index < 0 || index > 17) index = 0;
    SettingsHelper::setValue(QStringLiteral("backgroundImageCustomized"), true);
    int current = backgroundImage();
    SettingsHelper::setValue(QStringLiteral("backgroundImage"), index);
    if (current != index) {
        emit backgroundImageChanged();
    }
}

double PrayerManager::backgroundOpacity() const
{
    return SettingsHelper::value(QStringLiteral("backgroundOpacity"), 0.35).toDouble();
}

void PrayerManager::setBackgroundOpacity(double opacity)
{
    double clamped = qBound(0.05, opacity, 1.0);
    if (std::abs(backgroundOpacity() - clamped) > 0.001) {
        SettingsHelper::setValue(QStringLiteral("backgroundOpacity"), clamped);
        emit backgroundOpacityChanged();
    }
}

void PrayerManager::setHijriAdjustment(int days)
{
    if (days < -3) days = -3;
    if (days > 3) days = 3;
    SettingsHelper::setValue("hijriAdjustment", days);
    emit hijriAdjustmentChanged();
    emit timesChanged();
}

int PrayerManager::hijriAdjustment() const
{
    return SettingsHelper::value("hijriAdjustment", 0).toInt();
}

bool PrayerManager::isRamadan() const
{
    QDate adjustedDate = QDate::currentDate().addDays(hijriAdjustment());
    return PrayerTimes::gregorianToHijri(adjustedDate).month == 9;
}

QString PrayerManager::imsakTime() const
{
    return todayTimes().value(QStringLiteral("imsak")).toString();
}

int PrayerManager::imsakMinutes() const
{
    int val = SettingsHelper::value(QStringLiteral("imsakMinutes"), 10).toInt();
    return (val > 0) ? val : 10;
}

void PrayerManager::setImsakMinutes(int mins)
{
    if (mins <= 0) mins = 10;
    if (imsakMinutes() != mins) {
        SettingsHelper::setValue(QStringLiteral("imsakMinutes"), mins);
        emit imsakMinutesChanged();
        emit timesChanged();
    }
}

bool PrayerManager::showImsakAlways() const
{
    return SettingsHelper::value(QStringLiteral("showImsakAlways"), false).toBool();
}

void PrayerManager::setShowImsakAlways(bool always)
{
    if (showImsakAlways() != always) {
        SettingsHelper::setValue(QStringLiteral("showImsakAlways"), always);
        emit showImsakAlwaysChanged();
        emit timesChanged();
    }
}

void PrayerManager::setCompassCalibration(int offset)
{
    if (offset < -180) offset = -180;
    if (offset > 180) offset = 180;
    SettingsHelper::setValue("compassCalibrationOffset", offset);
    emit compassCalibrationChanged();
}

int PrayerManager::compassCalibration() const
{
    return SettingsHelper::value("compassCalibrationOffset", 0).toInt();
}

int PrayerManager::prayerAdjustment(const QString &prayer) const
{
    return SettingsHelper::value(QStringLiteral("adjustments/%1").arg(prayer), 0).toInt();
}

void PrayerManager::setPrayerAdjustment(const QString &prayer, int minutes)
{
    SettingsHelper::setValue(QStringLiteral("adjustments/%1").arg(prayer), minutes);
    recalculateAndSchedule();
}

int PrayerManager::qiblaMode() const
{
    return SettingsHelper::value("qiblaMode", 0).toInt();
}

void PrayerManager::setQiblaMode(int mode)
{
    if (mode < 0 || mode > 1) mode = 0;
    if (mode == qiblaMode()) return;
    SettingsHelper::setValue("qiblaMode", mode);
    emit qiblaModeChanged();
}

int PrayerManager::celestialReference() const
{
    return SettingsHelper::value("celestialReference", 0).toInt();
}

void PrayerManager::setCelestialReference(int ref)
{
    if (ref < 0 || ref > 4) ref = 0;
    if (ref == celestialReference()) return;
    SettingsHelper::setValue("celestialReference", ref);
    emit celestialReferenceChanged();
}

double PrayerManager::qiblaBearing() const
{
    if (!hasCity())
        return 0.0;
    return PrayerTimes::computeQiblaBearing(m_lat, m_lon);
}

double PrayerManager::qiblaDistanceKm() const
{
    if (!hasCity())
        return 0.0;
    return PrayerTimes::computeQiblaDistanceKm(m_lat, m_lon);
}

QString PrayerManager::qiblaCompassDirection() const
{
    if (!hasCity())
        return QString();
    return PrayerTimes::compassDirectionName(qiblaBearing());
}

double PrayerManager::shadowBearing() const
{
    return std::fmod(m_sunBearing + 180.0, 360.0);
}

QString PrayerManager::shadowCompassDirection() const
{
    return PrayerTimes::compassDirectionName(shadowBearing());
}

double PrayerManager::qiblaBearingFor(double lat, double lon) const
{
    return PrayerTimes::computeQiblaBearing(lat, lon);
}

double PrayerManager::qiblaDistanceFor(double lat, double lon) const
{
    return PrayerTimes::computeQiblaDistanceKm(lat, lon);
}

QString PrayerManager::qiblaDirectionNameFor(double bearing) const
{
    return PrayerTimes::compassDirectionName(bearing);
}

QString PrayerManager::audioPathFor(const QString &prayer) const
{
    return athanSound(prayer);
}

QVariantList PrayerManager::availableSounds() const
{
    QVariantList result;
    QDir dir("/usr/share/harbour-thakir/sounds");
    const QStringList files = dir.entryList(QStringList() << "*.ogg", QDir::Files, QDir::Name);
    for (const QString &file : files) {
        QFileInfo info(file);
        QString displayName = info.completeBaseName();
        displayName.replace('_', ' ');
        if (!displayName.isEmpty()) {
            displayName[0] = displayName[0].toUpper();
        }
        QVariantMap entry;
        entry["name"] = displayName;
        entry["path"] = dir.filePath(file);
        result.append(entry);
    }
    return result;
}

bool PrayerManager::isEuropeanDst(const QDate &date)
{
    int year = date.year();
    QDate lastSundayMarch(year, 3, 31);
    while (lastSundayMarch.dayOfWeek() != 7) lastSundayMarch = lastSundayMarch.addDays(-1);
    QDate lastSundayOct(year, 10, 31);
    while (lastSundayOct.dayOfWeek() != 7) lastSundayOct = lastSundayOct.addDays(-1);
    return date >= lastSundayMarch && date < lastSundayOct;
}

bool PrayerManager::isEgyptDst(const QDate &date)
{
    int year = date.year();
    QDate lastFridayApril(year, 4, 30);
    while (lastFridayApril.dayOfWeek() != 5) lastFridayApril = lastFridayApril.addDays(-1);
    QDate lastThursdayOct(year, 10, 31);
    while (lastThursdayOct.dayOfWeek() != 4) lastThursdayOct = lastThursdayOct.addDays(-1);
    return date >= lastFridayApril && date <= lastThursdayOct;
}

bool PrayerManager::isNorthAmericanDst(const QDate &date)
{
    int year = date.year();
    QDate firstSundayMarch(year, 3, 1);
    while (firstSundayMarch.dayOfWeek() != 7) firstSundayMarch = firstSundayMarch.addDays(1);
    QDate secondSundayMarch = firstSundayMarch.addDays(7);
    QDate firstSundayNov(year, 11, 1);
    while (firstSundayNov.dayOfWeek() != 7) firstSundayNov = firstSundayNov.addDays(1);
    return date >= secondSundayMarch && date < firstSundayNov;
}

double PrayerManager::fallbackStandardOffset(const QString &countryCode, double lon)
{
    QString cc = countryCode.trimmed().toUpper();
    if (cc == QStringLiteral("DZ") || cc == QStringLiteral("TN") || cc == QStringLiteral("MA") ||
        cc == QStringLiteral("NE") || cc == QStringLiteral("NG") || cc == QStringLiteral("TD")) {
        return 1.0;
    }
    if (cc == QStringLiteral("SA") || cc == QStringLiteral("KW") || cc == QStringLiteral("QA") ||
        cc == QStringLiteral("BH") || cc == QStringLiteral("IQ") || cc == QStringLiteral("YE") ||
        cc == QStringLiteral("SY") || cc == QStringLiteral("JO") || cc == QStringLiteral("TR")) {
        return 3.0;
    }
    if (cc == QStringLiteral("AE") || cc == QStringLiteral("OM")) {
        return 4.0;
    }
    if (cc == QStringLiteral("EG") || cc == QStringLiteral("LB") || cc == QStringLiteral("PS") ||
        cc == QStringLiteral("SD") || cc == QStringLiteral("LY")) {
        return 2.0;
    }
    return std::round(lon / 15.0);
}

double PrayerManager::automaticDaylightOffset(const QString &countryCode, const QString &countryName,
                                             const QString &ianaId, const QDate &date)
{
    Q_UNUSED(countryName);
    QString cc = countryCode.trimmed().toUpper();
    QString tzStr = ianaId.trimmed();

    if (cc.isEmpty()) {
        if (tzStr.startsWith(QStringLiteral("Africa/Algiers"))) cc = QStringLiteral("DZ");
        else if (tzStr.startsWith(QStringLiteral("Africa/Cairo"))) cc = QStringLiteral("EG");
        else if (tzStr.startsWith(QStringLiteral("Africa/Casablanca"))) cc = QStringLiteral("MA");
        else if (tzStr.startsWith(QStringLiteral("Africa/Tunis"))) cc = QStringLiteral("TN");
        else if (tzStr.startsWith(QStringLiteral("Africa/Tripoli"))) cc = QStringLiteral("LY");
        else if (tzStr.startsWith(QStringLiteral("Asia/Riyadh"))) cc = QStringLiteral("SA");
        else if (tzStr.startsWith(QStringLiteral("Asia/Dubai"))) cc = QStringLiteral("AE");
        else if (tzStr.startsWith(QStringLiteral("Asia/Qatar"))) cc = QStringLiteral("QA");
        else if (tzStr.startsWith(QStringLiteral("Asia/Kuwait"))) cc = QStringLiteral("KW");
        else if (tzStr.startsWith(QStringLiteral("Asia/Muscat"))) cc = QStringLiteral("OM");
        else if (tzStr.startsWith(QStringLiteral("Asia/Bahrain"))) cc = QStringLiteral("BH");
        else if (tzStr.startsWith(QStringLiteral("Asia/Amman"))) cc = QStringLiteral("JO");
        else if (tzStr.startsWith(QStringLiteral("Asia/Damascus"))) cc = QStringLiteral("SY");
        else if (tzStr.startsWith(QStringLiteral("Asia/Baghdad"))) cc = QStringLiteral("IQ");
        else if (tzStr.startsWith(QStringLiteral("Asia/Tehran"))) cc = QStringLiteral("IR");
        else if (tzStr.startsWith(QStringLiteral("Europe/Istanbul"))) cc = QStringLiteral("TR");
        else if (tzStr.startsWith(QStringLiteral("Europe/Paris"))) cc = QStringLiteral("FR");
        else if (tzStr.startsWith(QStringLiteral("Europe/London"))) cc = QStringLiteral("GB");
    }

    // 1. Countries that do not observe Daylight Saving Time
    static const QStringList NO_DST = {
        QStringLiteral("DZ"), QStringLiteral("SA"), QStringLiteral("AE"), QStringLiteral("QA"),
        QStringLiteral("KW"), QStringLiteral("OM"), QStringLiteral("BH"), QStringLiteral("TN"),
        QStringLiteral("LY"), QStringLiteral("SD"), QStringLiteral("YE"), QStringLiteral("IQ"),
        QStringLiteral("MR"), QStringLiteral("SO"), QStringLiteral("DJ"), QStringLiteral("KM"),
        QStringLiteral("TR"), QStringLiteral("JO"), QStringLiteral("SY"), QStringLiteral("IR")
    };
    if (NO_DST.contains(cc)) {
        return 0.0;
    }

    // 2. Egypt: Re-established DST in 2023 (last Friday of April to last Thursday of October)
    if (cc == QStringLiteral("EG") || tzStr == QStringLiteral("Africa/Cairo")) {
        return isEgyptDst(date) ? 1.0 : 0.0;
    }

    // 3. Morocco: UTC+1 year-round, except during Ramadan when it reverts to UTC+0
    if (cc == QStringLiteral("MA") || tzStr == QStringLiteral("Africa/Casablanca")) {
        return PrayerTimes::isRamadan(date) ? 0.0 : 1.0;
    }

    // 4. European countries
    static const QStringList EU_DST = {
        QStringLiteral("FR"), QStringLiteral("DE"), QStringLiteral("GB"), QStringLiteral("UK"),
        QStringLiteral("ES"), QStringLiteral("IT"), QStringLiteral("BE"), QStringLiteral("NL"),
        QStringLiteral("CH"), QStringLiteral("AT"), QStringLiteral("SE"), QStringLiteral("NO"),
        QStringLiteral("DK"), QStringLiteral("FI"), QStringLiteral("PL"), QStringLiteral("PT"),
        QStringLiteral("IE"), QStringLiteral("GR"), QStringLiteral("RO"), QStringLiteral("CZ"),
        QStringLiteral("HU"), QStringLiteral("BG"), QStringLiteral("HR"), QStringLiteral("SK")
    };
    if (EU_DST.contains(cc) || (tzStr.startsWith(QStringLiteral("Europe/")) &&
        tzStr != QStringLiteral("Europe/Istanbul") &&
        tzStr != QStringLiteral("Europe/Moscow") &&
        tzStr != QStringLiteral("Europe/Minsk"))) {
        return isEuropeanDst(date) ? 1.0 : 0.0;
    }

    // 5. United States / Canada
    if (cc == QStringLiteral("US") || cc == QStringLiteral("CA")) {
        return isNorthAmericanDst(date) ? 1.0 : 0.0;
    }

    // 6. Australia / New Zealand (Southern hemisphere)
    if (cc == QStringLiteral("AU") || cc == QStringLiteral("NZ")) {
        int year = date.year();
        QDate firstSundayOct(year, 10, 1);
        while (firstSundayOct.dayOfWeek() != 7) firstSundayOct = firstSundayOct.addDays(1);
        QDate firstSundayApril(year, 4, 1);
        while (firstSundayApril.dayOfWeek() != 7) firstSundayApril = firstSundayApril.addDays(1);
        return (date >= firstSundayOct || date < firstSundayApril) ? 1.0 : 0.0;
    }

    // 7. General fallback: check QTimeZone
    QTimeZone tz(tzStr.toUtf8());
    if (tz.isValid()) {
        QDateTime noon(date, QTime(12, 0, 0), tz);
        int dstSecs = tz.daylightTimeOffset(noon);
        if (dstSecs != 0) {
            return dstSecs / 3600.0;
        }
    }

    return 0.0;
}

double PrayerManager::staticTimezoneOffsetHoursFor(const QString &ianaId, const QString &countryCode,
                                                   const QString &countryName, double lon,
                                                   int daylightSavingMode, const QDate &date)
{
    QString cc = countryCode.trimmed().toUpper();
    QString tzStr = ianaId.trimmed();

    // Special handling for Morocco (MA)
    if (cc == QStringLiteral("MA") || tzStr == QStringLiteral("Africa/Casablanca")) {
        if (daylightSavingMode == 1) return 0.0; // standard time (GMT)
        if (daylightSavingMode == 2) return 1.0; // summer time (GMT+1)
        return PrayerTimes::isRamadan(date) ? 0.0 : 1.0;
    }

    QTimeZone tz(ianaId.toUtf8());
    double baseStandardOffset = 0.0;
    if (tz.isValid()) {
        QDateTime noon(date, QTime(12, 0, 0), tz);
        baseStandardOffset = tz.standardTimeOffset(noon) / 3600.0;
    } else {
        baseStandardOffset = fallbackStandardOffset(countryCode, lon);
    }

    if (daylightSavingMode == 1) {
        return baseStandardOffset;
    } else if (daylightSavingMode == 2) {
        return baseStandardOffset + 1.0;
    } else {
        double dst = automaticDaylightOffset(countryCode, countryName, ianaId, date);
        return baseStandardOffset + dst;
    }
}

double PrayerManager::timezoneOffsetHoursFor(const QString &ianaId, const QDate &date) const
{
    return staticTimezoneOffsetHoursFor(ianaId, m_countryCode, m_countryName, m_lon, m_daylightSaving, date);
}

void PrayerManager::setDaylightSaving(int mode)
{
    if (mode < 0 || mode > 2) mode = 0;
    if (m_daylightSaving != mode) {
        m_daylightSaving = mode;
        SettingsHelper::setValue(QStringLiteral("prefs/daylightSaving"), m_daylightSaving);
        emit daylightSavingChanged();
        emit timesChanged();
        recalculateAndSchedule();
    }
}

double PrayerManager::effectiveDaylightOffset(const QDate &date) const
{
    QDate d = date.isValid() ? date : QDate::currentDate();
    if (m_daylightSaving == 1) return 0.0;
    if (m_daylightSaving == 2) return 1.0;
    return automaticDaylightOffset(m_countryCode, m_countryName, m_tzId, d);
}

bool PrayerManager::isDaylightSavingActive() const
{
    return effectiveDaylightOffset(QDate::currentDate()) > 0.001;
}

QString PrayerManager::daylightSavingDescription() const
{
    QString loc = m_countryName.isEmpty() ? m_cityName : m_countryName;
    if (loc.isEmpty()) loc = m_tzId;
    bool active = isDaylightSavingActive();
    if (m_daylightSaving == 0) {
        if (active) {
            return isArabicLanguage()
                ? QStringLiteral("تلقائي: التوقيت الصيفي مفعّل (+1 ساعة) لـ %1").arg(loc)
                : tr("Auto: Daylight saving (+1h) active for %1").arg(loc);
        } else {
            return isArabicLanguage()
                ? QStringLiteral("تلقائي: التوقيت القياسي (غير مفعّل) لـ %1").arg(loc)
                : tr("Auto: Standard time (no daylight saving) for %1").arg(loc);
        }
    } else if (m_daylightSaving == 1) {
        return isArabicLanguage()
            ? QStringLiteral("معطّل يدوياً (التوقيت القياسي)")
            : tr("Disabled manually (Standard time)");
    } else {
        return isArabicLanguage()
            ? QStringLiteral("مفعّل يدوياً (+1 ساعة صيفي)")
            : tr("Enabled manually (+1 hour)");
    }
}

void PrayerManager::configureCalculator(PrayerTimes &calc, const QDate &date) const
{
    calc.setMethod(static_cast<PrayerTimes::Method>(m_method));
    calc.setMadhab(static_cast<PrayerTimes::Madhab>(m_madhab));
    calc.setHighLatitudeRule(static_cast<PrayerTimes::HighLatitudeRule>(m_highLatitudeRule));
    calc.setLocation(m_lat, m_lon);
    calc.setTimezone(timezoneOffsetHoursFor(m_tzId, date));
    for (int i = 0; i < 6; ++i) {
        calc.setPrayerOffset(i, prayerAdjustment(QString::fromLatin1(PRAYER_NAMES[i])));
    }
}

QVariantMap PrayerManager::timesToMap(const PrayerTimes::Times &t) const
{
    QVariantMap m;
    int mins = imsakMinutes();
    double imsakHours = t.fajr - (mins / 60.0);
    if (imsakHours < 0.0) imsakHours += 24.0;

    m["imsak"] = PrayerTimes::formatTime(imsakHours);
    m["fajr"] = PrayerTimes::formatTime(t.fajr);
    m["sunrise"] = PrayerTimes::formatTime(t.sunrise);
    m["dhuhr"] = PrayerTimes::formatTime(t.dhuhr);
    m["asr"] = PrayerTimes::formatTime(t.asr);
    m["maghrib"] = PrayerTimes::formatTime(t.maghrib);
    m["isha"] = PrayerTimes::formatTime(t.isha);
    m["valid"] = t.valid;
    return m;
}

QVariantMap PrayerManager::todayTimes() const
{
    if (!hasCity())
        return QVariantMap();

    PrayerTimes calc;
    QDate today = QDate::currentDate();
    configureCalculator(calc, today);
    return timesToMap(calc.computeForDate(today));
}

QVariantMap PrayerManager::nightTimes() const
{
    QVariantMap result;
    if (!hasCity())
        return result;

    PrayerTimes calc;
    QDate today = QDate::currentDate();
    QDate tomorrow = today.addDays(1);

    configureCalculator(calc, today);
    PrayerTimes::Times todayT = calc.computeForDate(today);

    calc.setTimezone(timezoneOffsetHoursFor(m_tzId, tomorrow));
    PrayerTimes::Times tomorrowT = calc.computeForDate(tomorrow);

    if (!todayT.valid || !tomorrowT.valid)
        return result;

    // The Islamic "night" runs from today's Maghrib to tomorrow's Fajr.
    // Both are fractional-hour clock times (0-24); adding 24 to
    // tomorrow's Fajr before subtracting correctly accounts for the
    // wrap across midnight.
    double nightDurationHours = (tomorrowT.fajr + 24.0) - todayT.maghrib;

    double midnightClock = std::fmod(todayT.maghrib + nightDurationHours / 2.0, 24.0);
    double lastThirdClock = std::fmod(todayT.maghrib + nightDurationHours * (2.0 / 3.0), 24.0);

    result["midnight"] = PrayerTimes::formatTime(midnightClock);
    result["lastThird"] = PrayerTimes::formatTime(lastThirdClock);
    return result;
}

PrayerManager::NextOccurrence PrayerManager::computeNextOccurrence() const
{
    NextOccurrence result;
    if (!hasCity())
        return result;

    PrayerTimes calc;
    QVariantMap enabled = enabledPrayers();
    QDateTime now = QDateTime::currentDateTime();

    for (int dayOffset = 0; dayOffset <= 1; ++dayOffset) {
        QDate date = QDate::currentDate().addDays(dayOffset);
        configureCalculator(calc, date);
        PrayerTimes::Times t = calc.computeForDate(date);
        if (!t.valid) continue;

        QVariantMap times = timesToMap(t);
        for (const char *p : PRAYER_NAMES) {
            if (!enabled.value(p).toBool()) continue;
            QString hm = times.value(p).toString();
            QTime tm = QTime::fromString(hm, "HH:mm");
            QDateTime dt(date, tm);
            if (dt > now) {
                result.prayer = QString(p);
                result.when = dt;
                return result;
            }
        }
    }
    return result; // no enabled prayers at all - when stays invalid
}

QString PrayerManager::nextPrayerName() const
{
    return computeNextOccurrence().prayer;
}

QString PrayerManager::nextPrayerTime() const
{
    QDateTime dt = computeNextOccurrence().when;
    if (!dt.isValid())
        return QString();
    if (use24HourFormat()) {
        return formatDigits(dt.toString(QStringLiteral("HH:mm")));
    }
    int h = dt.time().hour();
    int h12 = h % 12;
    if (h12 == 0) h12 = 12;
    QString hStr = QStringLiteral("%1").arg(h12, 2, 10, QLatin1Char('0'));
    QString mStr = dt.toString(QStringLiteral("mm"));
    QString timeStr = formatDigits(QStringLiteral("%1:%2").arg(hStr, mStr));
    if (isArabicLanguage()) {
        return QStringLiteral("%1 %2").arg(timeStr, h >= 12 ? QStringLiteral("م") : QStringLiteral("ص"));
    }
    return QStringLiteral("%1 %2").arg(timeStr, h >= 12 ? QStringLiteral("pm") : QStringLiteral("am"));
}

bool PrayerManager::isNextPrayerTomorrow() const
{
    QDateTime dt = computeNextOccurrence().when;
    return dt.isValid() && dt.date() > QDate::currentDate();
}

QString PrayerManager::nextPrayerCountdown() const
{
    QDateTime dt = computeNextOccurrence().when;
    if (!dt.isValid())
        return QString();

    qint64 secs = QDateTime::currentDateTime().secsTo(dt);
    if (secs < 0) secs = 0;
    int hours = static_cast<int>(secs / 3600);
    int minutes = static_cast<int>((secs % 3600) / 60);

    if (hours > 0)
        return QString("%1h %2m").arg(hours).arg(minutes);
    return QString("%1m").arg(minutes);
}

int PrayerManager::nextPrayerRemainingSeconds() const
{
    QDateTime dt = computeNextOccurrence().when;
    if (!dt.isValid())
        return -1;

    qint64 secs = QDateTime::currentDateTime().secsTo(dt);
    return secs >= 0 ? static_cast<int>(secs) : 0;
}

bool PrayerManager::isPreAlertWindow() const
{
    NextOccurrence nextOcc = computeNextOccurrence();
    if (!nextOcc.when.isValid())
        return false;

    qint64 secs = QDateTime::currentDateTime().secsTo(nextOcc.when);
    if (secs <= 0)
        return false;

    int alertMins = preAlertMinutes(nextOcc.prayer);
    if (alertMins <= 0)
        return false;

    return secs <= (alertMins * 60);
}

PrayerManager::PrayerInterval PrayerManager::computePrayerInterval() const
{
    PrayerInterval interval;
    if (!hasCity())
        return interval;

    PrayerTimes calc;
    QVariantMap enabled = enabledPrayers();
    QDateTime now = QDateTime::currentDateTime();

    QList<NextOccurrence> allOccurrences;

    for (int dayOffset = -1; dayOffset <= 1; ++dayOffset) {
        QDate date = QDate::currentDate().addDays(dayOffset);
        configureCalculator(calc, date);
        PrayerTimes::Times t = calc.computeForDate(date);
        if (!t.valid) continue;

        QVariantMap times = timesToMap(t);
        for (const char *p : PRAYER_NAMES) {
            if (!enabled.value(p).toBool()) continue;
            QString hm = times.value(p).toString();
            QTime tm = QTime::fromString(hm, "HH:mm");
            QDateTime dt(date, tm);
            if (dt.isValid()) {
                NextOccurrence occ;
                occ.prayer = QString(p);
                occ.when = dt;
                allOccurrences.append(occ);
            }
        }
    }

    int nextIdx = -1;
    for (int i = 0; i < allOccurrences.size(); ++i) {
        if (allOccurrences[i].when > now) {
            nextIdx = i;
            break;
        }
    }

    if (nextIdx != -1) {
        interval.next = allOccurrences[nextIdx];
        if (nextIdx > 0) {
            interval.prev = allOccurrences[nextIdx - 1];
            interval.valid = true;
        }
    }

    return interval;
}

double PrayerManager::nextPrayerProgress() const
{
    PrayerInterval interval = computePrayerInterval();
    if (!interval.valid)
        return 0.0;

    QDateTime now = QDateTime::currentDateTime();
    qint64 totalSecs = interval.prev.when.secsTo(interval.next.when);
    if (totalSecs <= 0)
        return 0.0;

    qint64 elapsedSecs = interval.prev.when.secsTo(now);
    if (elapsedSecs < 0) elapsedSecs = 0;
    if (elapsedSecs > totalSecs) elapsedSecs = totalSecs;

    return static_cast<double>(elapsedSecs) / static_cast<double>(totalSecs);
}

int PrayerManager::nextPrayerRemainingPercentage() const
{
    double progress = nextPrayerProgress();
    int rem = static_cast<int>(std::round((1.0 - progress) * 100.0));
    if (rem < 0) rem = 0;
    if (rem > 100) rem = 100;
    return rem;
}

int PrayerManager::nextPrayerElapsedPercentage() const
{
    double progress = nextPrayerProgress();
    int elapsed = static_cast<int>(std::round(progress * 100.0));
    if (elapsed < 0) elapsed = 0;
    if (elapsed > 100) elapsed = 100;
    return elapsed;
}

QString PrayerManager::previousPrayerName() const
{
    PrayerInterval interval = computePrayerInterval();
    return interval.valid ? interval.prev.prayer : QString();
}

QString PrayerManager::previousPrayerTime() const
{
    PrayerInterval interval = computePrayerInterval();
    return interval.valid ? interval.prev.when.toString("HH:mm") : QString();
}

QString PrayerManager::hijriDate() const
{
    QDate adjustedDate = QDate::currentDate().addDays(hijriAdjustment());
    PrayerTimes::HijriDate h = PrayerTimes::gregorianToHijri(adjustedDate);
    if (!h.valid || h.month < 1 || h.month > 12)
        return QString();

    QString monthStr;
    if (isArabicLanguage()) {
        static const char *arabicMonths[12] = {
            "محرم", "صفر", "ربيع الأول", "ربيع الثاني",
            "جمادى الأولى", "جمادى الثانية", "رجب", "شعبان",
            "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
        };
        monthStr = QString::fromUtf8(arabicMonths[h.month - 1]);
    } else if (appLanguage().trimmed().toLower() == QStringLiteral("tr")) {
        static const char *turkishMonths[12] = {
            "Muharrem", "Safer", "Rebîülevvel", "Rebîülâhir",
            "Cemâziyelevvel", "Cemâziyelâhir", "Recep", "Şaban",
            "Ramazan", "Şevval", "Zilkade", "Zilhicce"
        };
        monthStr = QString::fromUtf8(turkishMonths[h.month - 1]);
    } else if (appLanguage().trimmed().toLower() == QStringLiteral("fr")) {
        static const char *frenchMonths[12] = {
            "Mouharram", "Safar", "Rabi' al-Awwal", "Rabi' ath-Thani",
            "Joumada al-Oula", "Joumada ath-Thania", "Rajab", "Cha'ban",
            "Ramadan", "Chawwal", "Dhou al-Qi'da", "Dhou al-Hijja"
        };
        monthStr = QString::fromUtf8(frenchMonths[h.month - 1]);
    } else {
        static const char *englishMonths[12] = {
            "Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani",
            "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Shaban",
            "Ramadan", "Shawwal", "Dhu al-Qidah", "Dhu al-Hijjah"
        };
        monthStr = QString::fromLatin1(englishMonths[h.month - 1]);
    }

    QString dayStr = formatDigits(QString::number(h.day));
    QString yearStr = formatDigits(QString::number(h.year));

    return QStringLiteral("%1 %2 %3").arg(dayStr, monthStr, yearStr);
}

void PrayerManager::loadWisdomLines() const
{
    m_wisdomLines.clear();

    QString sailfishPath = SailfishApp::pathTo(QStringLiteral("files/Hikmato_El_Youm.txt")).toLocalFile();
    const QStringList candidates = {
        sailfishPath,
        QStringLiteral("/usr/share/harbour-thakir/files/Hikmato_El_Youm.txt"),
        QCoreApplication::applicationDirPath() + QStringLiteral("/../files/Hikmato_El_Youm.txt"),
        QCoreApplication::applicationDirPath() + QStringLiteral("/../share/harbour-thakir/files/Hikmato_El_Youm.txt"),
        QCoreApplication::applicationDirPath() + QStringLiteral("/files/Hikmato_El_Youm.txt"),
        QDir::current().filePath(QStringLiteral("files/Hikmato_El_Youm.txt"))
    };

    QString targetPath;
    for (const QString &p : candidates) {
        if (!p.isEmpty() && QFile::exists(p)) {
            targetPath = p;
            break;
        }
    }

    if (targetPath.isEmpty()) {
        qWarning() << "PrayerManager: Hikmato_El_Youm.txt not found in search paths";
        return;
    }

    QFile file(targetPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "PrayerManager: Failed to open" << targetPath;
        return;
    }

    QTextStream in(&file);
    in.setCodec("UTF-8");
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (!line.isEmpty()) {
            m_wisdomLines.append(line);
        }
    }
    file.close();
}

QString PrayerManager::dailyWisdom() const
{
    if (!isArabicLanguage()) {
        return QString();
    }
    if (m_wisdomLines.isEmpty()) {
        loadWisdomLines();
    }
    if (m_wisdomLines.isEmpty()) {
        return QString();
    }

    qint64 julianDay = QDate::currentDate().toJulianDay();
    int idx = static_cast<int>(std::abs(julianDay) % m_wisdomLines.size());
    return m_wisdomLines.at(idx);
}

bool PrayerManager::hasIslamicEvent() const
{
    QDate adjustedDate = QDate::currentDate().addDays(hijriAdjustment());
    PrayerTimes::HijriDate h = PrayerTimes::gregorianToHijri(adjustedDate);
    if (!h.valid || h.month < 1 || h.month > 12)
        return false;
    return IslamicEvents::getEvent(h.day, h.month).hasEvent;
}

QString PrayerManager::islamicEventTitle() const
{
    QDate adjustedDate = QDate::currentDate().addDays(hijriAdjustment());
    PrayerTimes::HijriDate h = PrayerTimes::gregorianToHijri(adjustedDate);
    if (!h.valid || h.month < 1 || h.month > 12)
        return QString();
    return IslamicEvents::getEvent(h.day, h.month).title;
}

QString PrayerManager::islamicEventBanner() const
{
    QDate adjustedDate = QDate::currentDate().addDays(hijriAdjustment());
    PrayerTimes::HijriDate h = PrayerTimes::gregorianToHijri(adjustedDate);
    if (!h.valid || h.month < 1 || h.month > 12)
        return QString();
    return IslamicEvents::getEvent(h.day, h.month).banner;
}

QString PrayerManager::islamicEventContent() const
{
    QDate adjustedDate = QDate::currentDate().addDays(hijriAdjustment());
    PrayerTimes::HijriDate h = PrayerTimes::gregorianToHijri(adjustedDate);
    if (!h.valid || h.month < 1 || h.month > 12)
        return QString();
    return IslamicEvents::getEvent(h.day, h.month).content;
}

QString PrayerManager::randomWisdom(bool forceNew) const
{
    if (m_wisdomLines.isEmpty()) {
        loadWisdomLines();
    }
    if (m_wisdomLines.isEmpty()) {
        return QString();
    }

    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QString todayStr = QDate::currentDate().toString(Qt::ISODate);
    QString savedDate = s.value(QStringLiteral("eventsView/wisdomDate")).toString();
    QString savedWisdom = s.value(QStringLiteral("eventsView/wisdomText")).toString();

    if (!forceNew && savedDate == todayStr && !savedWisdom.isEmpty()) {
        return savedWisdom;
    }

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<int> dist(0, m_wisdomLines.size() - 1);
    int idx = dist(gen);
    QString selected = m_wisdomLines.at(idx);

    s.setValue(QStringLiteral("eventsView/wisdomDate"), todayStr);
    s.setValue(QStringLiteral("eventsView/wisdomText"), selected);
    s.sync();

    return selected;
}

void PrayerManager::recalculateAndSchedule()
{
    m_lastDate = QDate::currentDate();
    m_lastNextPrayer = nextPrayerName();
    m_lastIsNextPrayerTomorrow = isNextPrayerTomorrow();
    updateCelestialPositions();
    if (showInEventsView()) {
        updateEventsViewStatus();
    }
    emit timesChanged();
}

void PrayerManager::checkNextPrayer()
{
    onPeriodicCheck();
}

void PrayerManager::onPeriodicCheck()
{
    QDate today = QDate::currentDate();
    if (today != m_lastDate) {
        recalculateAndSchedule();
        return;
    }

    QString currentNext = nextPrayerName();
    bool currentTomorrow = isNextPrayerTomorrow();

    if (currentNext != m_lastNextPrayer || currentTomorrow != m_lastIsNextPrayerTomorrow) {
        m_lastNextPrayer = currentNext;
        m_lastIsNextPrayerTomorrow = currentTomorrow;
        emit timesChanged();
    }

    if (showInEventsView()) {
        updateEventsViewStatus();
    }
}

void PrayerManager::updateCelestialPositions()
{
    if (!hasCity()) {
        m_sunBearing = 0.0;
        m_sunAltitude = 0.0;
        m_isDaytime = false;
        m_moonBearing = 0.0;
        m_moonAltitude = 0.0;
        m_isMoonVisible = false;
        m_moonPhase = 0.0;
        m_moonIllumination = 0.0;
        m_moonPhaseName.clear();
        emit celestialPositionsChanged();
        return;
    }

    PrayerTimes::CelestialPosition sun = PrayerTimes::computeSunPosition(m_lat, m_lon);
    PrayerTimes::CelestialPosition moon = PrayerTimes::computeMoonPosition(m_lat, m_lon);

    bool changed = (std::abs(m_sunBearing - sun.azimuth) > 0.01 ||
                    std::abs(m_sunAltitude - sun.altitude) > 0.01 ||
                    m_isDaytime != sun.isVisible ||
                    std::abs(m_moonBearing - moon.azimuth) > 0.01 ||
                    std::abs(m_moonAltitude - moon.altitude) > 0.01 ||
                    m_isMoonVisible != moon.isVisible ||
                    std::abs(m_moonPhase - moon.phase) > 0.005 ||
                    m_moonPhaseName != moon.phaseName);

    m_sunBearing = sun.azimuth;
    m_sunAltitude = sun.altitude;
    m_isDaytime = sun.isVisible;
    m_moonBearing = moon.azimuth;
    m_moonAltitude = moon.altitude;
    m_isMoonVisible = moon.isVisible;
    m_moonPhase = moon.phase;
    m_moonIllumination = moon.illumination;
    m_moonPhaseName = moon.phaseName;

    if (changed) {
        emit celestialPositionsChanged();
    }
}

// --- Favorites support ----------------------------------------------------

QJsonArray PrayerManager::loadFavoritesJson()
{
    QString raw = SettingsHelper::value(QStringLiteral("favorites/json")).toString();
    if (raw.isEmpty())
        return QJsonArray();

    QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8());
    if (doc.isArray())
        return doc.array();

    return QJsonArray();
}

void PrayerManager::saveFavoritesJson(const QJsonArray &arr)
{
    QJsonDocument doc(arr);
    SettingsHelper::setValue(QStringLiteral("favorites/json"), QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

QString PrayerManager::activeFavoriteId() const
{
    return SettingsHelper::value(QStringLiteral("favorites/activeId")).toString();
}

QString PrayerManager::activeFavoriteName() const
{
    QString activeId = activeFavoriteId();
    if (activeId.isEmpty())
        return QString();

    QJsonArray arr = loadFavoritesJson();
    for (const QJsonValue &v : arr) {
        if (v.isObject()) {
            QJsonObject obj = v.toObject();
            if (obj.value(QStringLiteral("id")).toString() == activeId) {
                return obj.value(QStringLiteral("name")).toString();
            }
        }
    }
    return QString();
}

QVariantList PrayerManager::favorites() const
{
    QVariantList list;
    QJsonArray arr = loadFavoritesJson();
    QString currentActiveId = activeFavoriteId();

    for (const QJsonValue &v : arr) {
        if (!v.isObject())
            continue;
        QJsonObject obj = v.toObject();
        QVariantMap map = obj.toVariantMap();
        QString id = obj.value(QStringLiteral("id")).toString();
        map[QStringLiteral("isActive")] = (!id.isEmpty() && id == currentActiveId);
        list.append(map);
    }
    return list;
}

QString PrayerManager::methodName(int methodIndex) const
{
    switch (methodIndex) {
    case 0: return tr("Muslim World League");
    case 1: return tr("Islamic Society of North America");
    case 2: return tr("Egyptian General Authority");
    case 3: return tr("Umm al-Qura, Makkah");
    case 4: return tr("University of Islamic Sciences, Karachi");
    case 5: return tr("Institute of Geophysics, Tehran");
    case 6: return tr("Prayer Times for High Latitudes");
    case 7: return tr("Ministry of Habous and Islamic Affairs, Morocco");
    case 8: return tr("Fixed Isha Angle Interval");
    case 9: return tr("Egyptian General Authority of Survey NEW");
    case 10: return tr("Umm Al-Qura University, RAMADAN");
    case 11: return tr("MOONSIGHTING_COMMITTEE");
    case 12: return tr("FRANCE_UOIF");
    case 13: return tr("MALAYSIA_JAKIM");
    case 14: return tr("TURKEY_FAZILET");
    case 15: return tr("TURKEY_TPRA");
    case 16: return tr("TURKEY_DIYANET");
    case 17: return tr("ENGLAND_BIRMINGHAM");
    case 18: return tr("JORDAN_MAIAHPJ");
    case 19: return tr("ALGERIA_MARWDZ");
    case 20: return tr("TUNISIA_MAIAMTU");
    case 21: return tr("OMAN_MARAOM");
    case 22: return tr("KUWAIT_MARAKU");
    case 23: return tr("LIBYA_MARALI");
    case 24: return tr("QATAR_TAQWMQAT");
    default: return tr("Standard");
    }
}

QString PrayerManager::madhabName(int madhabIndex) const
{
    return madhabIndex == 1 ? tr("Hanafi") : tr("Shafi\u2019i / Maliki / Hanbali");
}

QString PrayerManager::highLatitudeRuleName(int ruleIndex) const
{
    switch (ruleIndex) {
    case 0: return tr("None");
    case 1: return tr("Angle-based / Proportional (Recommended)");
    case 2: return tr("Middle of the night (1/2)");
    case 3: return tr("One-seventh of the night (1/7)");
    default: return tr("Angle-based / Proportional (Recommended)");
    }
}

QString PrayerManager::saveCurrentAsFavorite(const QString &customName)
{
    if (!hasCity())
        return QString();

    QString id = QString::number(QDateTime::currentMSecsSinceEpoch());
    QString name = customName.trimmed();
    if (name.isEmpty()) {
        name = m_cityName;
    }

    QJsonObject obj;
    obj[QStringLiteral("id")] = id;
    obj[QStringLiteral("name")] = name;
    obj[QStringLiteral("cityName")] = m_cityName;
    obj[QStringLiteral("countryName")] = m_countryName;
    obj[QStringLiteral("countryCode")] = m_countryCode;
    obj[QStringLiteral("lat")] = m_lat;
    obj[QStringLiteral("lon")] = m_lon;
    obj[QStringLiteral("tzId")] = m_tzId;
    obj[QStringLiteral("daylightSaving")] = m_daylightSaving;
    obj[QStringLiteral("method")] = m_method;
    obj[QStringLiteral("madhab")] = m_madhab;
    obj[QStringLiteral("highLatitudeRule")] = m_highLatitudeRule;
    obj[QStringLiteral("respectSilentMode")] = respectSilentMode();
    obj[QStringLiteral("stopWithPowerButton")] = stopWithPowerButton();
    obj[QStringLiteral("stopWithFlipOver")] = stopWithFlipOver();
    obj[QStringLiteral("stopWithVolumeButtons")] = stopWithVolumeButtons();
    obj[QStringLiteral("turnOnScreenDuringPlayback")] = turnOnScreen();
    obj[QStringLiteral("showNotification")] = showNotification();
    obj[QStringLiteral("hijriAdjustment")] = hijriAdjustment();
    obj[QStringLiteral("compassCalibration")] = compassCalibration();
    obj[QStringLiteral("qiblaMode")] = qiblaMode();
    obj[QStringLiteral("celestialReference")] = celestialReference();
    obj[QStringLiteral("silentDelayMinutes")] = silentDelayMinutes();
    obj[QStringLiteral("silentDurationMinutes")] = silentDurationMinutes();
    obj[QStringLiteral("use24HourFormat")] = use24HourFormat();
    obj[QStringLiteral("homeLayout")] = homeLayout();
    obj[QStringLiteral("useHindiNumerals")] = useHindiNumerals();
    obj[QStringLiteral("fridaySilentEnabled")] = fridaySilentEnabled();
    obj[QStringLiteral("fridaySilentBeforeMinutes")] = fridaySilentBeforeMinutes();
    obj[QStringLiteral("fridaySilentAfterMinutes")] = fridaySilentAfterMinutes();
    obj[QStringLiteral("morningAthkarEnabled")] = morningAthkarEnabled();
    obj[QStringLiteral("morningAthkarMinutes")] = morningAthkarMinutes();
    obj[QStringLiteral("eveningAthkarEnabled")] = eveningAthkarEnabled();
    obj[QStringLiteral("eveningAthkarMinutes")] = eveningAthkarMinutes();
    obj[QStringLiteral("imsakMinutes")] = imsakMinutes();
    obj[QStringLiteral("showImsakAlways")] = showImsakAlways();

    QJsonObject enabledObj;
    QJsonObject soundObj;
    QJsonObject prealertObj;
    QJsonObject silentObj;
    QJsonObject silentDelayObj;
    QJsonObject silentDurationObj;

    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    for (const char *p : PRAYER_NAMES) {
        QString prayer = QString::fromLatin1(p);
        bool defEnabled = (prayer != QStringLiteral("sunrise"));
        enabledObj[prayer] = s.value(QStringLiteral("enabled/%1").arg(prayer), defEnabled).toBool();
        soundObj[prayer] = s.value(QStringLiteral("sound/%1").arg(prayer),
                                   QStringLiteral("/usr/share/harbour-thakir/sounds/adhan_court.ogg")).toString();
        prealertObj[prayer] = s.value(QStringLiteral("prealert/%1").arg(prayer), 10).toInt();
        silentObj[prayer] = s.value(QStringLiteral("silentenabled/%1").arg(prayer), true).toBool();
        silentDelayObj[prayer] = s.value(QStringLiteral("silentdelay/%1").arg(prayer), 10).toInt();
        silentDurationObj[prayer] = s.value(QStringLiteral("silentduration/%1").arg(prayer), 15).toInt();
    }

    QJsonObject adjustObj;
    for (const char *p : PRAYER_NAMES) {
        QString prayer = QString::fromLatin1(p);
        adjustObj[prayer] = s.value(QStringLiteral("adjustments/%1").arg(prayer), 0).toInt();
    }

    obj[QStringLiteral("enabled")] = enabledObj;
    obj[QStringLiteral("sound")] = soundObj;
    obj[QStringLiteral("prealert")] = prealertObj;
    obj[QStringLiteral("silentenabled")] = silentObj;
    obj[QStringLiteral("silentdelay")] = silentDelayObj;
    obj[QStringLiteral("silentduration")] = silentDurationObj;
    obj[QStringLiteral("adjustments")] = adjustObj;

    QJsonArray arr = loadFavoritesJson();
    arr.append(obj);
    saveFavoritesJson(arr);

    SettingsHelper::setValue(QStringLiteral("favorites/activeId"), id);

    emit favoritesChanged();
    emit activeFavoriteChanged();

    return id;
}

bool PrayerManager::applyFavorite(const QString &favoriteId)
{
    if (favoriteId.isEmpty())
        return false;

    QJsonArray arr = loadFavoritesJson();
    QJsonObject target;
    bool found = false;

    for (const QJsonValue &v : arr) {
        if (v.isObject()) {
            QJsonObject obj = v.toObject();
            if (obj.value(QStringLiteral("id")).toString() == favoriteId) {
                target = obj;
                found = true;
                break;
            }
        }
    }

    if (!found)
        return false;

    m_cityName = target.value(QStringLiteral("cityName")).toString();
    m_countryName = target.value(QStringLiteral("countryName")).toString();
    m_countryCode = target.value(QStringLiteral("countryCode")).toString();
    m_lat = target.value(QStringLiteral("lat")).toDouble(0.0);
    m_lon = target.value(QStringLiteral("lon")).toDouble(0.0);
    m_tzId = target.value(QStringLiteral("tzId")).toString(QStringLiteral("UTC"));
    m_method = target.value(QStringLiteral("method")).toInt(0);
    m_madhab = target.value(QStringLiteral("madhab")).toInt(0);

    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    s.setValue(QStringLiteral("city/name"), m_cityName);
    s.setValue(QStringLiteral("city/country"), m_countryName);
    s.setValue(QStringLiteral("city/countryCode"), m_countryCode);
    s.setValue(QStringLiteral("city/lat"), m_lat);
    s.setValue(QStringLiteral("city/lon"), m_lon);
    s.setValue(QStringLiteral("city/tz"), m_tzId);
    s.setValue(QStringLiteral("prefs/method"), m_method);
    s.setValue(QStringLiteral("prefs/madhab"), m_madhab);

    if (target.contains(QStringLiteral("daylightSaving")))
        setDaylightSaving(target.value(QStringLiteral("daylightSaving")).toInt(0));
    else
        setDaylightSaving(0);

    if (target.contains(QStringLiteral("highLatitudeRule")))
        setHighLatitudeRule(target.value(QStringLiteral("highLatitudeRule")).toInt(1));
    if (target.contains(QStringLiteral("respectSilentMode")))
        s.setValue(QStringLiteral("respectSilentMode"), target.value(QStringLiteral("respectSilentMode")).toBool(true));
    if (target.contains(QStringLiteral("stopWithPowerButton")))
        setStopWithPowerButton(target.value(QStringLiteral("stopWithPowerButton")).toBool(true));
    if (target.contains(QStringLiteral("stopWithFlipOver")))
        setStopWithFlipOver(target.value(QStringLiteral("stopWithFlipOver")).toBool(true));
    if (target.contains(QStringLiteral("stopWithVolumeButtons")))
        setStopWithVolumeButtons(target.value(QStringLiteral("stopWithVolumeButtons")).toBool(true));
    if (target.contains(QStringLiteral("turnOnScreenDuringPlayback")))
        setTurnOnScreen(target.value(QStringLiteral("turnOnScreenDuringPlayback")).toBool(false));
    if (target.contains(QStringLiteral("showNotification")))
        setShowNotification(target.value(QStringLiteral("showNotification")).toBool(true));
    if (target.contains(QStringLiteral("hijriAdjustment")))
        setHijriAdjustment(target.value(QStringLiteral("hijriAdjustment")).toInt(0));
    if (target.contains(QStringLiteral("compassCalibration")))
        setCompassCalibration(target.value(QStringLiteral("compassCalibration")).toInt(0));
    if (target.contains(QStringLiteral("qiblaMode")))
        setQiblaMode(target.value(QStringLiteral("qiblaMode")).toInt(0));
    if (target.contains(QStringLiteral("celestialReference")))
        setCelestialReference(target.value(QStringLiteral("celestialReference")).toInt(0));
    if (target.contains(QStringLiteral("use24HourFormat")))
        setUse24HourFormat(target.value(QStringLiteral("use24HourFormat")).toBool(false));
    if (target.contains(QStringLiteral("homeLayout")))
        setHomeLayout(target.value(QStringLiteral("homeLayout")).toInt(0));
    if (target.contains(QStringLiteral("useHindiNumerals")))
        setUseHindiNumerals(target.value(QStringLiteral("useHindiNumerals")).toBool(false));
    if (target.contains(QStringLiteral("silentDelayMinutes")))
        s.setValue(QStringLiteral("silent/delayMinutes"), target.value(QStringLiteral("silentDelayMinutes")).toInt(10));
    if (target.contains(QStringLiteral("silentDurationMinutes")))
        s.setValue(QStringLiteral("silent/durationMinutes"), target.value(QStringLiteral("silentDurationMinutes")).toInt(10));
    if (target.contains(QStringLiteral("fridaySilentEnabled")))
        setFridaySilentEnabled(target.value(QStringLiteral("fridaySilentEnabled")).toBool(true));
    if (target.contains(QStringLiteral("fridaySilentBeforeMinutes")))
        setFridaySilentBeforeMinutes(target.value(QStringLiteral("fridaySilentBeforeMinutes")).toInt(30));
    if (target.contains(QStringLiteral("fridaySilentAfterMinutes")))
        setFridaySilentAfterMinutes(target.value(QStringLiteral("fridaySilentAfterMinutes")).toInt(30));
    if (target.contains(QStringLiteral("morningAthkarEnabled")))
        setMorningAthkarEnabled(target.value(QStringLiteral("morningAthkarEnabled")).toBool(false));
    if (target.contains(QStringLiteral("morningAthkarMinutes")))
        setMorningAthkarMinutes(target.value(QStringLiteral("morningAthkarMinutes")).toInt(10));
    if (target.contains(QStringLiteral("eveningAthkarEnabled")))
        setEveningAthkarEnabled(target.value(QStringLiteral("eveningAthkarEnabled")).toBool(false));
    if (target.contains(QStringLiteral("eveningAthkarMinutes")))
        setEveningAthkarMinutes(target.value(QStringLiteral("eveningAthkarMinutes")).toInt(5));
    if (target.contains(QStringLiteral("imsakMinutes")))
        setImsakMinutes(target.value(QStringLiteral("imsakMinutes")).toInt(10));
    if (target.contains(QStringLiteral("showImsakAlways")))
        setShowImsakAlways(target.value(QStringLiteral("showImsakAlways")).toBool(false));

    QJsonObject enabledObj = target.value(QStringLiteral("enabled")).toObject();
    QJsonObject soundObj = target.value(QStringLiteral("sound")).toObject();
    QJsonObject prealertObj = target.value(QStringLiteral("prealert")).toObject();
    QJsonObject silentObj = target.value(QStringLiteral("silentenabled")).toObject();
    QJsonObject silentDelayObj = target.value(QStringLiteral("silentdelay")).toObject();
    QJsonObject silentDurationObj = target.value(QStringLiteral("silentduration")).toObject();
    QJsonObject adjustObj = target.value(QStringLiteral("adjustments")).toObject();

    for (const char *p : PRAYER_NAMES) {
        QString prayer = QString::fromLatin1(p);
        if (enabledObj.contains(prayer))
            s.setValue(QStringLiteral("enabled/%1").arg(prayer), enabledObj.value(prayer).toBool());
        if (soundObj.contains(prayer))
            s.setValue(QStringLiteral("sound/%1").arg(prayer), soundObj.value(prayer).toString());
        if (prealertObj.contains(prayer))
            s.setValue(QStringLiteral("prealert/%1").arg(prayer), prealertObj.value(prayer).toInt());
        if (silentObj.contains(prayer))
            s.setValue(QStringLiteral("silentenabled/%1").arg(prayer), silentObj.value(prayer).toBool());
        if (silentDelayObj.contains(prayer))
            s.setValue(QStringLiteral("silentdelay/%1").arg(prayer), silentDelayObj.value(prayer).toInt());
        if (silentDurationObj.contains(prayer))
            s.setValue(QStringLiteral("silentduration/%1").arg(prayer), silentDurationObj.value(prayer).toInt());
        if (adjustObj.contains(prayer))
            s.setValue(QStringLiteral("adjustments/%1").arg(prayer), adjustObj.value(prayer).toInt(0));
    }

    s.setValue(QStringLiteral("favorites/activeId"), favoriteId);

    emit cityChanged();
    emit methodChanged();
    emit madhabChanged();
    emit enabledChanged();
    emit soundsChanged();
    emit silentSettingsChanged();
    emit activeFavoriteChanged();
    emit favoritesChanged();
    SilentModeHelper::checkAllSilentModes();
    recalculateAndSchedule();

    return true;
}

bool PrayerManager::updateFavorite(const QString &favoriteId)
{
    if (favoriteId.isEmpty() || !hasCity())
        return false;

    QJsonArray arr = loadFavoritesJson();
    bool found = false;

    for (int i = 0; i < arr.size(); ++i) {
        if (arr[i].isObject()) {
            QJsonObject obj = arr[i].toObject();
            if (obj.value(QStringLiteral("id")).toString() == favoriteId) {
                obj[QStringLiteral("cityName")] = m_cityName;
                obj[QStringLiteral("countryName")] = m_countryName;
                obj[QStringLiteral("lat")] = m_lat;
                obj[QStringLiteral("lon")] = m_lon;
                obj[QStringLiteral("tzId")] = m_tzId;
                obj[QStringLiteral("method")] = m_method;
                obj[QStringLiteral("madhab")] = m_madhab;
                obj[QStringLiteral("highLatitudeRule")] = m_highLatitudeRule;
                obj[QStringLiteral("respectSilentMode")] = respectSilentMode();
                obj[QStringLiteral("stopWithPowerButton")] = stopWithPowerButton();
                obj[QStringLiteral("stopWithFlipOver")] = stopWithFlipOver();
                obj[QStringLiteral("stopWithVolumeButtons")] = stopWithVolumeButtons();
                obj[QStringLiteral("turnOnScreenDuringPlayback")] = turnOnScreen();
                obj[QStringLiteral("showNotification")] = showNotification();
                obj[QStringLiteral("hijriAdjustment")] = hijriAdjustment();
                obj[QStringLiteral("compassCalibration")] = compassCalibration();
                obj[QStringLiteral("qiblaMode")] = qiblaMode();
                obj[QStringLiteral("celestialReference")] = celestialReference();
                obj[QStringLiteral("silentDelayMinutes")] = silentDelayMinutes();
                obj[QStringLiteral("silentDurationMinutes")] = silentDurationMinutes();
                obj[QStringLiteral("use24HourFormat")] = use24HourFormat();
                obj[QStringLiteral("homeLayout")] = homeLayout();
                obj[QStringLiteral("useHindiNumerals")] = useHindiNumerals();
                obj[QStringLiteral("fridaySilentEnabled")] = fridaySilentEnabled();
                obj[QStringLiteral("fridaySilentBeforeMinutes")] = fridaySilentBeforeMinutes();
                obj[QStringLiteral("fridaySilentAfterMinutes")] = fridaySilentAfterMinutes();
                obj[QStringLiteral("morningAthkarEnabled")] = morningAthkarEnabled();
                obj[QStringLiteral("morningAthkarMinutes")] = morningAthkarMinutes();
                obj[QStringLiteral("eveningAthkarEnabled")] = eveningAthkarEnabled();
                obj[QStringLiteral("eveningAthkarMinutes")] = eveningAthkarMinutes();

                QJsonObject enabledObj;
                QJsonObject soundObj;
                QJsonObject prealertObj;
                QJsonObject silentObj;
                QJsonObject silentDelayObj;
                QJsonObject silentDurationObj;

                QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
                for (const char *p : PRAYER_NAMES) {
                    QString prayer = QString::fromLatin1(p);
                    bool defEnabled = (prayer != QStringLiteral("sunrise"));
                    enabledObj[prayer] = s.value(QStringLiteral("enabled/%1").arg(prayer), defEnabled).toBool();
                    soundObj[prayer] = s.value(QStringLiteral("sound/%1").arg(prayer),
                                               QStringLiteral("/usr/share/harbour-thakir/sounds/adhan_court.ogg")).toString();
                    prealertObj[prayer] = s.value(QStringLiteral("prealert/%1").arg(prayer), 10).toInt();
                    silentObj[prayer] = s.value(QStringLiteral("silentenabled/%1").arg(prayer), true).toBool();
                    silentDelayObj[prayer] = s.value(QStringLiteral("silentdelay/%1").arg(prayer), 10).toInt();
                    silentDurationObj[prayer] = s.value(QStringLiteral("silentduration/%1").arg(prayer), 15).toInt();
                }

                QJsonObject adjustObj;
                for (const char *p : PRAYER_NAMES) {
                    QString prayer = QString::fromLatin1(p);
                    adjustObj[prayer] = s.value(QStringLiteral("adjustments/%1").arg(prayer), 0).toInt();
                }

                obj[QStringLiteral("enabled")] = enabledObj;
                obj[QStringLiteral("sound")] = soundObj;
                obj[QStringLiteral("prealert")] = prealertObj;
                obj[QStringLiteral("silentenabled")] = silentObj;
                obj[QStringLiteral("silentdelay")] = silentDelayObj;
                obj[QStringLiteral("silentduration")] = silentDurationObj;
                obj[QStringLiteral("adjustments")] = adjustObj;

                arr[i] = obj;
                found = true;
                break;
            }
        }
    }

    if (!found)
        return false;

    saveFavoritesJson(arr);
    emit favoritesChanged();
    return true;
}

bool PrayerManager::renameFavorite(const QString &favoriteId, const QString &newName)
{
    QString trimmed = newName.trimmed();
    if (favoriteId.isEmpty() || trimmed.isEmpty())
        return false;

    QJsonArray arr = loadFavoritesJson();
    bool found = false;

    for (int i = 0; i < arr.size(); ++i) {
        if (arr[i].isObject()) {
            QJsonObject obj = arr[i].toObject();
            if (obj.value(QStringLiteral("id")).toString() == favoriteId) {
                obj[QStringLiteral("name")] = trimmed;
                arr[i] = obj;
                found = true;
                break;
            }
        }
    }

    if (!found)
        return false;

    saveFavoritesJson(arr);
    emit favoritesChanged();
    if (activeFavoriteId() == favoriteId) {
        emit activeFavoriteChanged();
    }
    return true;
}

bool PrayerManager::deleteFavorite(const QString &favoriteId)
{
    if (favoriteId.isEmpty())
        return false;

    QJsonArray arr = loadFavoritesJson();
    QJsonArray newArr;
    bool found = false;

    for (const QJsonValue &v : arr) {
        if (v.isObject()) {
            QJsonObject obj = v.toObject();
            if (obj.value(QStringLiteral("id")).toString() == favoriteId) {
                found = true;
                continue;
            }
            newArr.append(obj);
        }
    }

    if (!found)
        return false;

    saveFavoritesJson(newArr);

    if (activeFavoriteId() == favoriteId) {
        SettingsHelper::setValue(QStringLiteral("favorites/activeId"), QString());
        emit activeFavoriteChanged();
    }

    emit favoritesChanged();
    return true;
}

static QTranslator *s_appTranslator = nullptr;
static QQmlEngine *s_qmlEngine = nullptr;

void PrayerManager::installAppTranslator(QCoreApplication *app)
{
    Q_UNUSED(app);
    QString lang = SettingsHelper::value(QStringLiteral("appLanguage"), QString()).toString();
    applyLanguage(lang);
}

void PrayerManager::setQmlEngine(QQmlEngine *engine)
{
    m_engine = engine;
    s_qmlEngine = engine;
}

QString PrayerManager::appLanguage() const
{
    return SettingsHelper::value(QStringLiteral("appLanguage"), QString()).toString();
}

void PrayerManager::setAppLanguage(const QString &lang)
{
    if (appLanguage() == lang)
        return;

    SettingsHelper::setValue(QStringLiteral("appLanguage"), lang);
    applyLanguage(lang);
    emit appLanguageChanged();
    emit timesChanged();
    emit buildDateChanged();
    if (showInEventsView()) {
        updateEventsViewStatus();
    }
}

bool PrayerManager::isArabicLanguage() const
{
    QString lang = appLanguage().trimmed().toLower();
    if (lang.isEmpty()) {
        lang = QLocale::system().name().left(2).toLower();
    }
    return lang == QStringLiteral("ar");
}

bool PrayerManager::useHindiNumerals() const
{
    return SettingsHelper::value(QStringLiteral("useHindiNumerals"), false).toBool();
}

void PrayerManager::setUseHindiNumerals(bool enable)
{
    if (useHindiNumerals() == enable)
        return;

    SettingsHelper::setValue(QStringLiteral("useHindiNumerals"), enable);
    emit useHindiNumeralsChanged();
    emit timesChanged();
    emit buildDateChanged();
    if (showInEventsView()) {
        updateEventsViewStatus();
    }
}

QString PrayerManager::formatDigits(const QString &str) const
{
    if (str.isEmpty() || !isArabicLanguage()) {
        return str;
    }

    QString result = str;
    if (useHindiNumerals()) {
        for (int i = 0; i < result.size(); ++i) {
            ushort u = result.at(i).unicode();
            if (u >= '0' && u <= '9') {
                result[i] = QChar(0x0660 + (u - '0'));
            }
        }
    } else {
        for (int i = 0; i < result.size(); ++i) {
            ushort u = result.at(i).unicode();
            if (u >= 0x0660 && u <= 0x0669) {
                result[i] = QChar('0' + (u - 0x0660));
            }
        }
    }
    return result;
}

void PrayerManager::applyLanguage(const QString &lang)
{
    QString effectiveLang = lang.trimmed().toLower();
    if (effectiveLang.isEmpty()) {
        effectiveLang = QLocale::system().name().left(2).toLower();
    }

    if (s_appTranslator) {
        if (qApp) {
            qApp->removeTranslator(s_appTranslator);
        }
        delete s_appTranslator;
        s_appTranslator = nullptr;
    }

    if (effectiveLang == QStringLiteral("ar")) {
        QLocale::setDefault(QLocale(QLocale::Arabic));
    } else if (effectiveLang == QStringLiteral("fr")) {
        QLocale::setDefault(QLocale(QLocale::French));
    } else if (effectiveLang == QStringLiteral("tr")) {
        QLocale::setDefault(QLocale(QLocale::Turkish));
    } else if (effectiveLang == QStringLiteral("en")) {
        QLocale::setDefault(QLocale(QLocale::English));
    } else {
        QLocale::setDefault(QLocale::system());
    }

    if (effectiveLang == QStringLiteral("ar") || effectiveLang == QStringLiteral("fr") || effectiveLang == QStringLiteral("tr")) {
        s_appTranslator = new QTranslator(qApp);
        QString baseName = QStringLiteral("harbour-thakir-") + effectiveLang;
        QStringList candidateDirs;
        QString p = SailfishApp::pathTo("translations").toLocalFile();
        if (!p.isEmpty()) {
            candidateDirs << p;
        }
        candidateDirs << QStringLiteral("/usr/share/harbour-thakir/translations")
                      << QCoreApplication::applicationDirPath() + QStringLiteral("/../share/harbour-thakir/translations")
                      << QCoreApplication::applicationDirPath() + QStringLiteral("/translations")
                      << QCoreApplication::applicationDirPath() + QStringLiteral("/../translations")
                      << QStringLiteral("translations");

        bool loaded = false;
        for (const QString &dir : candidateDirs) {
            if (s_appTranslator->load(baseName, dir)) {
                loaded = true;
                qDebug() << "harbour-thakir: loaded translator" << baseName << "from" << dir;
                break;
            }
            if (s_appTranslator->load(baseName + QStringLiteral(".qm"), dir)) {
                loaded = true;
                qDebug() << "harbour-thakir: loaded translator (.qm)" << baseName << "from" << dir;
                break;
            }
        }

        if (loaded) {
            if (qApp) {
                qApp->installTranslator(s_appTranslator);
            }
        } else {
            qWarning() << "harbour-thakir: failed to load translator for" << effectiveLang;
            delete s_appTranslator;
            s_appTranslator = nullptr;
        }
    }

    if (s_qmlEngine) {
#if QT_VERSION >= QT_VERSION_CHECK(5, 10, 0)
        s_qmlEngine->retranslate();
#endif
    }
}

QString PrayerManager::osVersion() const
{
    QFile file(QStringLiteral("/etc/os-release"));
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        QString fallbackVer;
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.startsWith(QStringLiteral("VERSION_ID="))) {
                QString val = line.mid(11).trimmed();
                if ((val.startsWith('"') && val.endsWith('"')) ||
                    (val.startsWith('\'') && val.endsWith('\''))) {
                    val = val.mid(1, val.length() - 2);
                }
                if (!val.isEmpty()) {
                    return val;
                }
            } else if (line.startsWith(QStringLiteral("VERSION="))) {
                QString val = line.mid(8).trimmed();
                if ((val.startsWith('"') && val.endsWith('"')) ||
                    (val.startsWith('\'') && val.endsWith('\''))) {
                    val = val.mid(1, val.length() - 2);
                }
                if (!val.isEmpty() && fallbackVer.isEmpty()) {
                    fallbackVer = val;
                }
            }
        }
        if (!fallbackVer.isEmpty()) {
            return fallbackVer;
        }
    }
    return QString();
}

QString PrayerManager::buildDate() const
{
    QString dateRaw = QStringLiteral(__DATE__).simplified();
    QDate d = QLocale(QLocale::C).toDate(dateRaw, QStringLiteral("MMM d yyyy"));
    if (!d.isValid()) {
        d = QDate::fromString(dateRaw, QStringLiteral("MMM d yyyy"));
    }
    if (!d.isValid()) {
        return QStringLiteral(__DATE__);
    }

    QString lang = appLanguage().trimmed().toLower();
    if (lang.isEmpty()) {
        lang = QLocale::system().name().left(2).toLower();
    }

    QLocale loc;
    if (lang == QStringLiteral("ar")) {
        loc = QLocale(QLocale::Arabic);
    } else if (lang == QStringLiteral("fr")) {
        loc = QLocale(QLocale::French);
    } else if (lang == QStringLiteral("tr")) {
        loc = QLocale(QLocale::Turkish);
    } else if (lang == QStringLiteral("en")) {
        loc = QLocale(QLocale::English);
    } else {
        loc = QLocale::system();
    }

    QString dateStr = loc.toString(d, QLocale::LongFormat);
    return formatDigits(dateStr);
}

QString PrayerManager::formatDate(const QDate &date) const
{
    QDate d = date.isValid() ? date : QDate::currentDate();
    // Format according to the device's regional settings (QLocale::system())
    QString dateStr = QLocale::system().toString(d, QLocale::ShortFormat);
    return formatDigits(dateStr);
}

QString PrayerManager::formatCurrentDateTime(const QDateTime &dt) const
{
    QDateTime targetDt = dt.isValid() ? dt : QDateTime::currentDateTime();

    // 1. Format date according to the device's regional settings (QLocale::system())
    QString datePart = QLocale::system().toString(targetDt.date(), QLocale::ShortFormat);

    // 2. Format time respecting 12h/24h format and language
    QString timePart;
    if (use24HourFormat()) {
        timePart = targetDt.toString(QStringLiteral("HH:mm"));
    } else {
        int h = targetDt.time().hour();
        int h12 = h % 12;
        if (h12 == 0) h12 = 12;
        QString hStr = QStringLiteral("%1").arg(h12, 2, 10, QLatin1Char('0'));
        QString mStr = targetDt.toString(QStringLiteral("mm"));

        bool rtl = isArabicLanguage();
        QString ampm = (h >= 12) ? (rtl ? QStringLiteral("م") : QStringLiteral("pm"))
                                 : (rtl ? QStringLiteral("ص") : QStringLiteral("am"));
        timePart = QStringLiteral("%1:%2 %3").arg(hStr, mStr, ampm);
    }

    return formatDigits(QStringLiteral("%1 %2").arg(datePart, timePart));
}

bool PrayerManager::morningAthkarEnabled() const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    return s.value(QStringLiteral("athkar/morningEnabled"), false).toBool();
}

void PrayerManager::setMorningAthkarEnabled(bool enabled)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    if (s.value(QStringLiteral("athkar/morningEnabled"), false).toBool() != enabled) {
        s.setValue(QStringLiteral("athkar/morningEnabled"), enabled);
        s.remove(QStringLiteral("played/morning_athkar"));
        s.sync();
        emit morningAthkarChanged();
    }
}

int PrayerManager::morningAthkarMinutes() const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    return s.value(QStringLiteral("athkar/morningMinutes"), 10).toInt();
}

void PrayerManager::setMorningAthkarMinutes(int minutes)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    if (s.value(QStringLiteral("athkar/morningMinutes"), 10).toInt() != minutes) {
        s.setValue(QStringLiteral("athkar/morningMinutes"), minutes);
        s.remove(QStringLiteral("played/morning_athkar"));
        s.sync();
        emit morningAthkarChanged();
    }
}

bool PrayerManager::eveningAthkarEnabled() const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    return s.value(QStringLiteral("athkar/eveningEnabled"), false).toBool();
}

void PrayerManager::setEveningAthkarEnabled(bool enabled)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    if (s.value(QStringLiteral("athkar/eveningEnabled"), false).toBool() != enabled) {
        s.setValue(QStringLiteral("athkar/eveningEnabled"), enabled);
        s.remove(QStringLiteral("played/evening_athkar"));
        s.sync();
        emit eveningAthkarChanged();
    }
}

int PrayerManager::eveningAthkarMinutes() const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    return s.value(QStringLiteral("athkar/eveningMinutes"), 5).toInt();
}

void PrayerManager::setEveningAthkarMinutes(int minutes)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    if (s.value(QStringLiteral("athkar/eveningMinutes"), 5).toInt() != minutes) {
        s.setValue(QStringLiteral("athkar/eveningMinutes"), minutes);
        s.remove(QStringLiteral("played/evening_athkar"));
        s.sync();
        emit eveningAthkarChanged();
    }
}

static QString resolveAthkarPath(const QString &relPath)
{
    QStringList candidates;
    candidates << relPath;
    if (relPath.endsWith(QStringLiteral(".ogg"), Qt::CaseInsensitive)) {
        QString mp3 = relPath;
        mp3.chop(4);
        mp3.append(QStringLiteral(".mp3"));
        candidates << mp3;
    } else if (relPath.endsWith(QStringLiteral(".mp3"), Qt::CaseInsensitive)) {
        QString ogg = relPath;
        ogg.chop(4);
        ogg.append(QStringLiteral(".ogg"));
        candidates.prepend(ogg);
    }

    for (const QString &cand : candidates) {
        QUrl u = SailfishApp::pathTo(cand);
        if (u.isLocalFile() && QFile::exists(u.toLocalFile())) return u.toLocalFile();
        QString p = QStringLiteral("/usr/share/harbour-thakir/") + cand;
        if (QFile::exists(p)) return p;
        QString appP = QCoreApplication::applicationDirPath() + QStringLiteral("/../share/harbour-thakir/") + cand;
        if (QFile::exists(appP)) return appP;
        if (QFile::exists(cand)) return QFileInfo(cand).absoluteFilePath();
        QString srcP = QStringLiteral("C:/Users/hafte/.gemini/antigravity/scratch/harbour-thakir/") + cand;
        if (QFile::exists(srcP)) return srcP;
    }
    return QStringLiteral("/usr/share/harbour-thakir/") + relPath;
}

QString PrayerManager::resolveAthkarPath(const QString &relPath) const
{
    return ::resolveAthkarPath(relPath);
}

QStringList PrayerManager::morningAthkarAudioPaths() const
{
    static const QStringList relFiles = {
        QStringLiteral("sounds/Athkar/1_1.ogg"),
        QStringLiteral("sounds/Athkar/1_2.ogg"),
        QStringLiteral("sounds/Athkar/1_3.ogg"),
        QStringLiteral("sounds/Athkar/1_4.ogg"),
        QStringLiteral("sounds/Athkar/2_4.ogg"),
        QStringLiteral("sounds/Athkar/2_1.ogg"),
        QStringLiteral("sounds/Athkar/1_19.ogg"),
        QStringLiteral("sounds/Athkar/3_1.ogg")
    };
    if (relFiles.isEmpty()) return QStringList();

    // Select one clip randomly for the day (not all in one)
    qint64 julian = QDate::currentDate().toJulianDay();
    quint64 seed = static_cast<quint64>(julian) * 2654435761ULL;
    int idx = static_cast<int>(seed % static_cast<quint64>(relFiles.size()));

    return QStringList{ resolveAthkarPath(relFiles.at(idx)) };
}

QStringList PrayerManager::eveningAthkarAudioPaths() const
{
    static const QStringList relFiles = {
        QStringLiteral("sounds/Athkar/2_1.ogg"),
        QStringLiteral("sounds/Athkar/1_3.ogg"),
        QStringLiteral("sounds/Athkar/1_2.ogg"),
        QStringLiteral("sounds/Athkar/2_2.ogg"),
        QStringLiteral("sounds/Athkar/3_2.ogg")
    };
    if (relFiles.isEmpty()) return QStringList();

    // Select one clip randomly for the day (not all in one)
    qint64 julian = QDate::currentDate().toJulianDay();
    quint64 seed = (static_cast<quint64>(julian) ^ 0x5deece66dULL) * 2654435761ULL;
    int idx = static_cast<int>(seed % static_cast<quint64>(relFiles.size()));

    return QStringList{ resolveAthkarPath(relFiles.at(idx)) };
}

bool PrayerManager::showInEventsView() const
{
    return EventsViewStatus::isEnabled();
}

void PrayerManager::setShowInEventsView(bool enabled)
{
    if (EventsViewStatus::isEnabled() != enabled) {
        EventsViewStatus::setEnabled(enabled);
        if (enabled) {
            updateEventsViewStatus();
        } else {
            EventsViewStatus::clearStatus();
        }
        emit showInEventsViewChanged();
    }
}

QString PrayerManager::localizedPrayerName(const QString &prayerKey, bool isFriday, bool isTomorrow) const
{
    QString effectiveLang = appLanguage().trimmed().toLower();
    if (effectiveLang.isEmpty()) {
        effectiveLang = QLocale::system().name().left(2).toLower();
    }

    if (effectiveLang == QStringLiteral("ar")) {
        if (isTomorrow) {
            if (prayerKey == QStringLiteral("fajr")) return QString::fromUtf8("فجر الغد");
            if (prayerKey == QStringLiteral("sunrise")) return QString::fromUtf8("شروق الغد");
            if (prayerKey == QStringLiteral("dhuhr")) return isFriday ? QString::fromUtf8("جمعة الغد") : QString::fromUtf8("ظهر الغد");
            if (prayerKey == QStringLiteral("asr")) return QString::fromUtf8("عصر الغد");
            if (prayerKey == QStringLiteral("maghrib")) return QString::fromUtf8("مغرب الغد");
            if (prayerKey == QStringLiteral("isha")) return QString::fromUtf8("عشاء الغد");
        }
        if (prayerKey == QStringLiteral("imsak")) return QString::fromUtf8("الإمساك");
        if (prayerKey == QStringLiteral("fajr")) return QString::fromUtf8("الفجر");
        if (prayerKey == QStringLiteral("sunrise")) return QString::fromUtf8("الشروق");
        if (prayerKey == QStringLiteral("dhuhr")) return isFriday ? QString::fromUtf8("صلاة الجمعة") : QString::fromUtf8("الظهر");
        if (prayerKey == QStringLiteral("asr")) return QString::fromUtf8("العصر");
        if (prayerKey == QStringLiteral("maghrib")) return QString::fromUtf8("المغرب");
        if (prayerKey == QStringLiteral("isha")) return QString::fromUtf8("العشاء");
        if (prayerKey == QStringLiteral("midnight")) return QString::fromUtf8("منتصف الليل");
        if (prayerKey == QStringLiteral("lastThird")) return QString::fromUtf8("الثلث الأخير");
    } else if (effectiveLang == QStringLiteral("fr")) {
        if (isTomorrow) {
            if (prayerKey == QStringLiteral("fajr")) return QStringLiteral("Fadjr de demain");
            if (prayerKey == QStringLiteral("sunrise")) return QStringLiteral("Chourouq de demain");
            if (prayerKey == QStringLiteral("dhuhr")) return isFriday ? QStringLiteral("Vendredi de demain") : QStringLiteral("Dhouhr de demain");
            if (prayerKey == QStringLiteral("asr")) return QStringLiteral("Assar de demain");
            if (prayerKey == QStringLiteral("maghrib")) return QStringLiteral("Maghreb de demain");
            if (prayerKey == QStringLiteral("isha")) return QStringLiteral("Icha de demain");
        }
        if (prayerKey == QStringLiteral("imsak")) return QStringLiteral("Imsak");
        if (prayerKey == QStringLiteral("fajr")) return QStringLiteral("Fadjr");
        if (prayerKey == QStringLiteral("sunrise")) return QStringLiteral("Chourouq");
        if (prayerKey == QStringLiteral("dhuhr")) return isFriday ? QStringLiteral("Prière du vendredi") : QStringLiteral("Dhouhr");
        if (prayerKey == QStringLiteral("asr")) return QStringLiteral("Assar");
        if (prayerKey == QStringLiteral("maghrib")) return QStringLiteral("Maghreb");
        if (prayerKey == QStringLiteral("isha")) return QStringLiteral("Icha");
        if (prayerKey == QStringLiteral("midnight")) return QStringLiteral("Minuit");
        if (prayerKey == QStringLiteral("lastThird")) return QStringLiteral("Dernier tiers de la nuit");
    } else if (effectiveLang == QStringLiteral("tr")) {
        if (isTomorrow) {
            if (prayerKey == QStringLiteral("fajr")) return QString::fromUtf8("Yarının İmsakı");
            if (prayerKey == QStringLiteral("sunrise")) return QString::fromUtf8("Yarının Güneşi");
            if (prayerKey == QStringLiteral("dhuhr")) return isFriday ? QString::fromUtf8("Yarının Cuma Namazı") : QString::fromUtf8("Yarının Öğlesi");
            if (prayerKey == QStringLiteral("asr")) return QString::fromUtf8("Yarının İkindisi");
            if (prayerKey == QStringLiteral("maghrib")) return QString::fromUtf8("Yarının Akşamı");
            if (prayerKey == QStringLiteral("isha")) return QString::fromUtf8("Yarının Yatsısı");
        }
        if (prayerKey == QStringLiteral("imsak")) return QString::fromUtf8("İmsak (Sahur)");
        if (prayerKey == QStringLiteral("fajr")) return QString::fromUtf8("İmsak");
        if (prayerKey == QStringLiteral("sunrise")) return QString::fromUtf8("Güneş");
        if (prayerKey == QStringLiteral("dhuhr")) return isFriday ? QString::fromUtf8("Cuma Namazı") : QString::fromUtf8("Öğle");
        if (prayerKey == QStringLiteral("asr")) return QString::fromUtf8("İkindi");
        if (prayerKey == QStringLiteral("maghrib")) return QString::fromUtf8("Akşam");
        if (prayerKey == QStringLiteral("isha")) return QString::fromUtf8("Yatsı");
        if (prayerKey == QStringLiteral("midnight")) return QString::fromUtf8("Gece Yarısı");
        if (prayerKey == QStringLiteral("lastThird")) return QString::fromUtf8("Gecenin Son Üçte Biri");
    } else {
        if (isTomorrow) {
            if (prayerKey == QStringLiteral("fajr")) return QStringLiteral("Tomorrow's Fajr");
            if (prayerKey == QStringLiteral("sunrise")) return QStringLiteral("Tomorrow's Sunrise");
            if (prayerKey == QStringLiteral("dhuhr")) return isFriday ? QStringLiteral("Tomorrow's Friday prayer") : QStringLiteral("Tomorrow's Dhuhr");
            if (prayerKey == QStringLiteral("asr")) return QStringLiteral("Tomorrow's Asr");
            if (prayerKey == QStringLiteral("maghrib")) return QStringLiteral("Tomorrow's Maghrib");
            if (prayerKey == QStringLiteral("isha")) return QStringLiteral("Tomorrow's Isha");
        }
        if (prayerKey == QStringLiteral("imsak")) return QStringLiteral("Imsak");
        if (prayerKey == QStringLiteral("fajr")) return QStringLiteral("Fajr");
        if (prayerKey == QStringLiteral("sunrise")) return QStringLiteral("Sunrise");
        if (prayerKey == QStringLiteral("dhuhr")) return isFriday ? QStringLiteral("Friday prayer") : QStringLiteral("Dhuhr");
        if (prayerKey == QStringLiteral("asr")) return QStringLiteral("Asr");
        if (prayerKey == QStringLiteral("maghrib")) return QStringLiteral("Maghrib");
        if (prayerKey == QStringLiteral("isha")) return QStringLiteral("Isha");
        if (prayerKey == QStringLiteral("midnight")) return QStringLiteral("Midnight");
        if (prayerKey == QStringLiteral("lastThird")) return QStringLiteral("Last 1/3 Night");
    }

    if (prayerKey.isEmpty()) return QStringLiteral("--");
    return prayerKey.left(1).toUpper() + prayerKey.mid(1);
}

QString PrayerManager::localizedRemainingTime() const
{
    int secs = nextPrayerRemainingSeconds();
    if (secs < 0) secs = 0;
    int hours = secs / 3600;
    int minutes = (secs % 3600) / 60;
    if (secs > 0 && secs < 60 && minutes == 0) {
        minutes = 1;
    }

    QString effectiveLang = appLanguage().trimmed().toLower();
    if (effectiveLang.isEmpty()) {
        effectiveLang = QLocale::system().name().left(2).toLower();
    }

    QString hStr = QString::number(hours);
    QString mStr = QString::number(minutes);

    if (effectiveLang == QStringLiteral("ar")) {
        if (useHindiNumerals()) {
            hStr = formatDigits(hStr);
            mStr = formatDigits(mStr);
        }
        if (hours > 0) {
            return QString::fromUtf8("متبقي: %1 سا %2 د").arg(hStr, mStr);
        } else {
            return QString::fromUtf8("متبقي: %1 د").arg(mStr);
        }
    } else if (effectiveLang == QStringLiteral("fr")) {
        if (hours > 0) {
            return QStringLiteral("Temps restant : %1 h %2 min").arg(hStr, mStr);
        } else {
            return QStringLiteral("Temps restant : %1 min").arg(mStr);
        }
    } else if (effectiveLang == QStringLiteral("tr")) {
        if (hours > 0) {
            return QString::fromUtf8("Kalan süre: %1 sa %2 dk").arg(hStr, mStr);
        } else {
            return QString::fromUtf8("Kalan süre: %1 dk").arg(mStr);
        }
    } else {
        if (hours > 0) {
            return QStringLiteral("Remaining: %1h %2m").arg(hStr, mStr);
        } else {
            return QStringLiteral("Remaining: %1m").arg(mStr);
        }
    }
}

void PrayerManager::updateEventsViewStatus()
{
    if (!EventsViewStatus::isEnabled() || !hasCity()) {
        EventsViewStatus::clearStatus();
        return;
    }

    // Check whether remaining time is inside the pre-alert lead window for the upcoming prayer
    bool preAlert = isPreAlertWindow();

    QString pName = nextPrayerName();
    QString pTime = nextPrayerTime();
    bool isFriday = (pName == QStringLiteral("dhuhr") && QDate::currentDate().dayOfWeek() == Qt::Friday);
    bool isTomorrow = isNextPrayerTomorrow();
    QString pDisplay = localizedPrayerName(pName, isFriday, isTomorrow);

    // Line 1 (Summary): Next prayer name and scheduled time (e.g. "Tomorrow's Fajr 05:23 am" or "فجر الغد 05:23 ص")
    QString summary = QStringLiteral("%1 %2").arg(pDisplay, pTime);
    if (preAlert) {
        summary = QStringLiteral("🔴 %1").arg(summary);
    }

    // Line 2 (Body): Localized countdown (e.g. "Remaining: 7h 47m" or "متبقي: 7 سا 47 د")
    QString body = localizedRemainingTime();
    if (preAlert) {
        body = QStringLiteral("🔴 %1").arg(body);
    }

    // Progress bar towards next prayer (0.0 to 1.0)
    double progress = nextPrayerProgress();

    // Pre-alert warning banner line
    if (preAlert) {
        QString alertBanner;
        QString lang = appLanguage().trimmed().toLower();
        if (lang.isEmpty()) {
            lang = QLocale::system().name().left(2).toLower();
        }
        bool isSunrise = (pName == QStringLiteral("sunrise"));
        if (isSunrise) {
            if (lang == QStringLiteral("ar")) {
                alertBanner = QString::fromUtf8("⚠️ اقترب موعد الشروق");
            } else if (lang == QStringLiteral("fr")) {
                alertBanner = QStringLiteral("⚠️ Le lever du soleil approche");
            } else if (lang == QStringLiteral("tr")) {
                alertBanner = QString::fromUtf8("⚠️ Güneş doğuşu yaklaşıyor");
            } else {
                alertBanner = QStringLiteral("⚠️ Upcoming sunrise soon");
            }
        } else {
            if (lang == QStringLiteral("ar")) {
                alertBanner = QString::fromUtf8("⚠️ اقترب موعد الأذان");
            } else if (lang == QStringLiteral("fr")) {
                alertBanner = QStringLiteral("⚠️ La prière approche");
            } else if (lang == QStringLiteral("tr")) {
                alertBanner = QString::fromUtf8("⚠️ Ezan vakti yaklaşıyor");
            } else {
                alertBanner = QStringLiteral("⚠️ Upcoming prayer soon");
            }
        }
        body += QStringLiteral("\n") + alertBanner;
    }

    // Islamic Event: when today has an Islamic event, display it in Events View
    if (hasIslamicEvent()) {
        QString eventText = isArabicLanguage() ? islamicEventTitle() : islamicEventBanner();
        if (!eventText.isEmpty()) {
            QString clickText;
            QString lang = appLanguage().trimmed().toLower();
            if (lang.isEmpty()) {
                lang = QLocale::system().name().left(2).toLower();
            }
            if (lang == QStringLiteral("ar")) {
                clickText = QString::fromUtf8("انقر لعرض تفاصيل الحدث في التطبيق");
            } else if (lang == QStringLiteral("fr")) {
                clickText = QStringLiteral("Cliquez pour afficher les détails de l'événement dans l'application");
            } else if (lang == QStringLiteral("tr")) {
                clickText = QString::fromUtf8("Uygulamada etkinliğin ayrıntılarını görmek için tıklayın");
            } else {
                clickText = QStringLiteral("Click to show details of the event in the application");
            }
            body += QStringLiteral("\n🕌 ") + eventText + QStringLiteral(" (") + clickText + QStringLiteral(")");
        }
    }

    // In Arabic language only: add text from a random line of Hikmato_El_Youm.txt
    if (isArabicLanguage()) {
        QString wisdom = randomWisdom();
        if (!wisdom.isEmpty()) {
            body += QStringLiteral("\n") + wisdom;
        }
    }

    // App name for notification header: "ذكر أذان" for Arabic, "Thakir Athan" for English/others
    QString appName = isArabicLanguage() ? QString::fromUtf8("ذكر أذان") : QStringLiteral("Thakir Athan");

    EventsViewStatus::updateStatus(appName, summary, body, progress, cityName(), preAlert);
}


