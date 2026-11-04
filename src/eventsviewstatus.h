#ifndef EVENTSVIEWSTATUS_H
#define EVENTSVIEWSTATUS_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QtGlobal>
#include <cmath>
#include "settingshelper.h"

class EventsViewStatus : public QObject
{
    Q_OBJECT
public:
    static bool isEnabled()
    {
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        return s.value(QStringLiteral("prefs/showInEventsView"), true).toBool();
    }

    static void setEnabled(bool enabled)
    {
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("prefs/showInEventsView"), enabled);
        s.sync();
        if (!enabled) {
            clearStatus();
        }
    }

    static void clearStatus()
    {
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        uint id = s.value(QStringLiteral("eventsViewNotificationId"), 0).toUInt();
        if (id == 0) return;

        s.remove(QStringLiteral("eventsViewNotificationId"));
        s.sync();

        QDBusConnection sessionBus = QDBusConnection::sessionBus();
        if (!sessionBus.isConnected()) return;

        QDBusInterface iface(QStringLiteral("org.freedesktop.Notifications"),
                             QStringLiteral("/org/freedesktop/Notifications"),
                             QStringLiteral("org.freedesktop.Notifications"),
                             sessionBus);
        if (iface.isValid()) {
            iface.call(QStringLiteral("CloseNotification"), id);
            qDebug() << "EventsViewStatus: Closed notification ID" << id;
        }
    }

    static void ensureDBusServiceFiles()
    {
        QString servicesDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/dbus-1/services");
        QDir dir(servicesDir);
        if (!dir.exists()) {
            dir.mkpath(QStringLiteral("."));
        }

        QString sailjailBin = QStringLiteral("/usr/bin/sailjail");
        QString execCmd = QFile::exists(sailjailBin)
                ? QStringLiteral("/usr/bin/sailjail -p harbour-thakir.desktop /usr/bin/harbour-thakir")
                : QStringLiteral("/usr/bin/harbour-thakir");

        auto writeServiceFile = [&](const QString &serviceName) {
            QString path = servicesDir + QStringLiteral("/%1.service").arg(serviceName);
            QFile f(path);
            if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
                QTextStream out(&f);
                out << "[D-BUS Service]\n";
                out << "Name=" << serviceName << "\n";
                out << "Exec=" << execCmd << "\n";
                f.close();
                qDebug() << "EventsViewStatus: Created/updated user D-Bus service file at" << path;
            }
        };

        writeServiceFile(QStringLiteral("org.hafsoftdz.harbour-thakir"));
        writeServiceFile(QStringLiteral("org.hafsoftdz.harbour_thakir"));
    }

    static void updateStatus(const QString &appName, const QString &summary, const QString &body,
                             double progress = -1.0, const QString &subText = QString(),
                             bool isPreAlert = false)
    {
        Q_UNUSED(isPreAlert);
        if (!isEnabled()) {
            clearStatus();
            return;
        }

        ensureDBusServiceFiles();

        QDBusConnection sessionBus = QDBusConnection::sessionBus();
        if (!sessionBus.isConnected()) {
            qWarning() << "EventsViewStatus: Session D-Bus is not connected!";
            return;
        }

        QDBusInterface iface(QStringLiteral("org.freedesktop.Notifications"),
                             QStringLiteral("/org/freedesktop/Notifications"),
                             QStringLiteral("org.freedesktop.Notifications"),
                             sessionBus);
        if (!iface.isValid()) {
            qWarning() << "EventsViewStatus: org.freedesktop.Notifications interface invalid:"
                       << iface.lastError().message();
            return;
        }

        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        uint existingId = s.value(QStringLiteral("eventsViewNotificationId"), 0).toUInt();

        QString openText = (QLocale().language() == QLocale::Arabic)
                ? QString::fromUtf8("فتح")
                : QStringLiteral("Open");

        QStringList actions;
        actions << QStringLiteral("default") << openText
                << QStringLiteral("app") << openText
                << QStringLiteral("open") << openText;

        QVariantMap hints;
        hints.insert(QStringLiteral("urgency"), uchar(0)); // Standard urgency

        hints.insert(QStringLiteral("resident"), true);    // Keep in Events View
        hints.insert(QStringLiteral("transient"), false);
        hints.insert(QStringLiteral("x-nemo-suppress-feedback"), true); // Silence vibration/sound
        hints.insert(QStringLiteral("x-nemo-icon"), QStringLiteral("harbour-thakir"));
        hints.insert(QStringLiteral("desktop-entry"), QStringLiteral("harbour-thakir"));
        hints.insert(QStringLiteral("x-nemo-desktop-entry"), QStringLiteral("harbour-thakir"));
        hints.insert(QStringLiteral("x-nemo-max-content-lines"), 8);
        hints.insert(QStringLiteral("x-nemo-remote-action-default"),
                     QStringLiteral("org.hafsoftdz.harbour-thakir / org.hafsoftdz.harbour_thakir open"));
        hints.insert(QStringLiteral("x-nemo-remote-action-app"),
                     QStringLiteral("org.hafsoftdz.harbour-thakir / org.hafsoftdz.harbour_thakir open"));
        hints.insert(QStringLiteral("x-nemo-remote-action-open"),
                     QStringLiteral("org.hafsoftdz.harbour-thakir / org.hafsoftdz.harbour_thakir open"));

        if (progress >= 0.0) {
            double clamped = qBound(0.0, progress, 1.0);
            hints.insert(QStringLiteral("x-nemo-progress"), clamped);
            hints.insert(QStringLiteral("value"), qRound(clamped * 100.0));
        }

        if (!subText.isEmpty()) {
            hints.insert(QStringLiteral("x-nemo-sub-text"), subText);
        }

        QDBusReply<uint> reply = iface.call(QStringLiteral("Notify"),
                                            appName,
                                            existingId,
                                            QStringLiteral("harbour-thakir"),
                                            summary,
                                            body,
                                            actions,
                                            hints,
                                            int(0)); // 0: no automatic expiration

        if (reply.isValid()) {
            uint newId = reply.value();
            if (newId != existingId) {
                s.setValue(QStringLiteral("eventsViewNotificationId"), newId);
                s.sync();
            }
            qDebug() << "EventsViewStatus: Updated notification ID" << newId
                     << "summary:" << summary << "progress:" << progress;
        } else {
            qWarning() << "EventsViewStatus: Failed to update notification:" << reply.error().message();
        }
    }
};

#endif // EVENTSVIEWSTATUS_H
