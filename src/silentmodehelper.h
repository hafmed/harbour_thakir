#ifndef SILENTMODEHELPER_H
#define SILENTMODEHELPER_H

#include <QDateTime>
#include <QSettings>
#include <QProcess>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusConnection>
#include <QFile>
#include <QTimeZone>
#include <QDebug>
#include "settingshelper.h"
#include "prayertimes.h"

class SilentModeHelper
{
public:
    static const int CHECK_TOLERANCE_SECONDS = 3 * 60;

    static QString getCurrentProfile()
    {
        QDBusInterface profiled(QStringLiteral("com.nokia.profiled"),
                                QStringLiteral("/com/nokia/profiled"),
                                QStringLiteral("com.nokia.profiled"),
                                QDBusConnection::sessionBus());
        if (!profiled.isValid()) {
            qWarning() << "SilentMode: could not reach profiled (get_profile)";
            return QString();
        }
        QDBusMessage reply = profiled.call(QStringLiteral("get_profile"));
        if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty()) {
            qWarning() << "SilentMode: get_profile failed:" << reply.errorMessage();
            return QString();
        }
        return reply.arguments().at(0).toString();
    }

    static bool setProfile(const QString &profile)
    {
        QDBusInterface profiled(QStringLiteral("com.nokia.profiled"),
                                QStringLiteral("/com/nokia/profiled"),
                                QStringLiteral("com.nokia.profiled"),
                                QDBusConnection::sessionBus());
        if (!profiled.isValid()) {
            qWarning() << "SilentMode: could not reach profiled (set_profile)";
            return false;
        }
        QDBusMessage reply = profiled.call(QStringLiteral("set_profile"), profile);
        if (reply.type() == QDBusMessage::ErrorMessage) {
            qWarning() << "SilentMode: set_profile(" << profile
                      << ") failed:" << reply.errorMessage();
            return false;
        }
        return true;
    }

    static void playBeep()
    {
        QString beepPath = QStringLiteral("/usr/share/harbour-thakir/sounds/Beep.ogg");
        QProcess::execute(QStringLiteral("/usr/bin/paplay"), {
            QStringLiteral("--property=media.role=alarm"),
            QStringLiteral("--property=media.name=SilentBeep"),
            beepPath
        });
    }

    static void checkSilentModeExpiry(QSettings &s)
    {
        bool active = s.value(QStringLiteral("silent/active"), false).toBool();
        if (!active)
            return;

        qint64 endEpoch = s.value(QStringLiteral("silent/endEpoch"), 0).toLongLong();
        qint64 nowEpoch = QDateTime::currentDateTime().toMSecsSinceEpoch() / 1000;
        if (nowEpoch < endEpoch)
            return;

        QString restoreProfile = s.value(QStringLiteral("silent/restoreProfile"), QStringLiteral("general")).toString();
        if (restoreProfile.isEmpty()) {
            restoreProfile = QStringLiteral("general");
        }
        qDebug() << "SilentMode: window ended, restoring profile" << restoreProfile;

        QDBusConnection sysBus = QDBusConnection::systemBus();
        if (sysBus.isConnected()) {
            QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/request"),
                               QStringLiteral("com.nokia.mce.request"),
                               sysBus);
            if (mce.isValid()) {
                mce.call(QStringLiteral("req_cpu_keepalive_start"), QStringLiteral("harbour-thakir-silent"));
            }
        }

        setProfile(restoreProfile);
        s.setValue(QStringLiteral("silent/active"), false);

        if (restoreProfile != QStringLiteral("silent")) {
            playBeep();
        }

        if (sysBus.isConnected()) {
            QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/request"),
                               QStringLiteral("com.nokia.mce.request"),
                               sysBus);
            if (mce.isValid()) {
                mce.call(QStringLiteral("req_cpu_keepalive_stop"), QStringLiteral("harbour-thakir-silent"));
            }
        }
    }

    static void maybeStartSilentMode(QSettings &s, const QString &prayer,
                                      const QDateTime &prayerDt, const QDateTime &now,
                                      const QString &todayStr)
    {
        if (prayer == QStringLiteral("sunrise")) {
            return;
        }

        bool isFridayDhuhr = (prayer == QStringLiteral("dhuhr") && now.date().dayOfWeek() == Qt::Friday);
        bool fridaySilentEnabled = s.value(QStringLiteral("fridaySilent/enabled"), true).toBool();

        QDateTime silentStartTarget;
        qint64 targetEndEpoch = 0;
        int durationMinutes = 0;
        qint64 nowEpoch = now.toMSecsSinceEpoch() / 1000;

        if (isFridayDhuhr && fridaySilentEnabled) {
            int beforeMinutes = s.value(QStringLiteral("fridaySilent/beforeMinutes"), 30).toInt();
            int afterMinutes = s.value(QStringLiteral("fridaySilent/afterMinutes"), 30).toInt();
            if (beforeMinutes < 0) beforeMinutes = 0;
            if (afterMinutes <= 0) afterMinutes = 30;

            silentStartTarget = prayerDt.addSecs(-beforeMinutes * 60);
            QDateTime silentEndTarget = prayerDt.addSecs(afterMinutes * 60);
            targetEndEpoch = silentEndTarget.toMSecsSinceEpoch() / 1000;
            durationMinutes = beforeMinutes + afterMinutes;
        } else {
            bool enabledForThisPrayer = s.value(QString("silentenabled/%1").arg(prayer), true).toBool();
            if (!enabledForThisPrayer) {
                return;
            }

            int defaultDelay = s.value(QStringLiteral("silent/delayMinutes"), 10).toInt();
            int defaultDuration = s.value(QStringLiteral("silent/durationMinutes"), 15).toInt();
            int delayMinutes = s.value(QString("silentdelay/%1").arg(prayer), defaultDelay).toInt();
            durationMinutes = s.value(QString("silentduration/%1").arg(prayer), defaultDuration).toInt();
            if (durationMinutes <= 0) {
                return;
            }

            silentStartTarget = prayerDt.addSecs(delayMinutes * 60);
            targetEndEpoch = (silentStartTarget.toMSecsSinceEpoch() / 1000) + durationMinutes * 60;
        }

        QString triggeredKey = isFridayDhuhr
                ? QStringLiteral("silenttriggered/friday_dhuhr")
                : QString("silenttriggered/%1").arg(prayer);
        bool alreadyTriggeredToday = (s.value(triggeredKey).toString() == todayStr);

        qint64 startEpoch = silentStartTarget.toMSecsSinceEpoch() / 1000;
        bool silentStartDue = (nowEpoch >= startEpoch && nowEpoch < targetEndEpoch);

        if (!silentStartDue || alreadyTriggeredToday)
            return;

        if (s.value(QStringLiteral("silent/active"), false).toBool()) {
            qint64 existingEndEpoch = s.value(QStringLiteral("silent/endEpoch"), 0).toLongLong();
            if (nowEpoch >= existingEndEpoch) {
                checkSilentModeExpiry(s);
            } else {
                qDebug() << "SilentMode: window already active, not starting another one for" << prayer;
                s.setValue(triggeredKey, todayStr);
                return;
            }
        }

        QDBusConnection sysBus = QDBusConnection::systemBus();
        if (sysBus.isConnected()) {
            QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/request"),
                               QStringLiteral("com.nokia.mce.request"),
                               sysBus);
            if (mce.isValid()) {
                mce.call(QStringLiteral("req_cpu_keepalive_start"), QStringLiteral("harbour-thakir-silent"));
            }
        }

        QString currentProfile = getCurrentProfile();
        if (currentProfile.isEmpty()) {
            qWarning() << "SilentMode: could not determine current profile, defaulting to general";
            currentProfile = QStringLiteral("general");
        }

        if (currentProfile == QStringLiteral("silent")) {
            qDebug() << "SilentMode: already in silent profile for" << prayer;
            s.setValue(QStringLiteral("silent/restoreProfile"), QStringLiteral("silent"));
            s.setValue(QStringLiteral("silent/active"), true);
            s.setValue(QStringLiteral("silent/endEpoch"), targetEndEpoch);
            s.setValue(triggeredKey, todayStr);
        } else {
            qDebug() << "SilentMode: activating silent mode for" << prayer
                      << "(" << durationMinutes << "min, was" << currentProfile << ")";
            if (!setProfile(QStringLiteral("silent"))) {
                qWarning() << "SilentMode: setProfile(silent) failed for" << prayer << "- will retry";
                if (sysBus.isConnected()) {
                    QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                                       QStringLiteral("/com/nokia/mce/request"),
                                       QStringLiteral("com.nokia.mce.request"),
                                       sysBus);
                    if (mce.isValid()) {
                        mce.call(QStringLiteral("req_cpu_keepalive_stop"), QStringLiteral("harbour-thakir-silent"));
                    }
                }
                return;
            }
            s.setValue(QStringLiteral("silent/restoreProfile"), currentProfile);
            s.setValue(QStringLiteral("silent/active"), true);
            s.setValue(QStringLiteral("silent/endEpoch"), targetEndEpoch);
            s.setValue(triggeredKey, todayStr);
            playBeep();
        }

        if (sysBus.isConnected()) {
            QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/request"),
                               QStringLiteral("com.nokia.mce.request"),
                               sysBus);
            if (mce.isValid()) {
                mce.call(QStringLiteral("req_cpu_keepalive_stop"), QStringLiteral("harbour-thakir-silent"));
            }
        }
    }

    static void checkAllSilentModes()
    {
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        SettingsHelper::ensureSanity(s);

        QString cityName = s.value(QStringLiteral("city/name")).toString();
        if (cityName.isEmpty()) {
            return;
        }

        double lat = s.value(QStringLiteral("city/lat"), 0.0).toDouble();
        double lon = s.value(QStringLiteral("city/lon"), 0.0).toDouble();
        QString tzId = s.value(QStringLiteral("city/tz"), QStringLiteral("UTC")).toString();
        int method = s.value(QStringLiteral("prefs/method"), 0).toInt();
        int madhab = s.value(QStringLiteral("prefs/madhab"), 0).toInt();
        int highLatitudeRule = s.value(QStringLiteral("prefs/highLatitudeRule"), 1).toInt();

        PrayerTimes calc;
        calc.setMethod(static_cast<PrayerTimes::Method>(method));
        calc.setMadhab(static_cast<PrayerTimes::Madhab>(madhab));
        calc.setHighLatitudeRule(static_cast<PrayerTimes::HighLatitudeRule>(highLatitudeRule));
        calc.setLocation(lat, lon);

        QDate today = QDate::currentDate();
        QTimeZone tz(tzId.toUtf8());
        double tzOffset = 0.0;
        if (tz.isValid()) {
            QDateTime noon(today, QTime(12, 0, 0), tz);
            tzOffset = tz.offsetFromUtc(noon) / 3600.0;
        }
        calc.setTimezone(tzOffset);
        static const char *names[6] = {"fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"};
        for (int i = 0; i < 6; ++i) {
            int offset = s.value(QStringLiteral("adjustments/%1").arg(names[i]), 0).toInt();
            calc.setPrayerOffset(i, offset);
        }

        PrayerTimes::Times t = calc.computeForDate(today);
        if (!t.valid) {
            return;
        }

        double values[6] = {t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha};
        QDateTime now = QDateTime::currentDateTime();
        QString todayStr = today.toString(Qt::ISODate);

        checkSilentModeExpiry(s);

        for (int i = 0; i < 6; ++i) {
            QString p = names[i];
            QString m = PrayerTimes::formatTime(values[i]);
            QDateTime prayerDt(today, QTime::fromString(m, QStringLiteral("HH:mm")));

            maybeStartSilentMode(s, p, prayerDt, now, todayStr);
        }
    }
};

#endif // SILENTMODEHELPER_H
