#ifndef ATHANNOTIFICATION_H
#define ATHANNOTIFICATION_H

#include <QObject>
#include <QDate>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDebug>
#include "settingshelper.h"

class AthanNotification : public QObject
{
    Q_OBJECT
public:
    explicit AthanNotification(const QString &prayer, QObject *parent = nullptr)
        : AthanNotification(prayer, SettingsHelper::value(QStringLiteral("turnOnScreenDuringPlayback"), false).toBool(), parent) {}

    explicit AthanNotification(const QString &prayer, bool turnOnScreen, QObject *parent = nullptr)
        : QObject(parent), m_prayer(prayer), m_turnOnScreen(turnOnScreen), m_notificationId(0)
    {
        QDBusConnection sessionBus = QDBusConnection::sessionBus();
        if (sessionBus.isConnected()) {
            sessionBus.connect(QStringLiteral("org.freedesktop.Notifications"),
                               QStringLiteral("/org/freedesktop/Notifications"),
                               QStringLiteral("org.freedesktop.Notifications"),
                               QStringLiteral("ActionInvoked"),
                               this,
                               SLOT(onActionInvoked(uint, QString)));

            sessionBus.connect(QStringLiteral("org.freedesktop.Notifications"),
                               QStringLiteral("/org/freedesktop/Notifications"),
                               QStringLiteral("org.freedesktop.Notifications"),
                               QStringLiteral("NotificationClosed"),
                               this,
                               SLOT(onNotificationClosed(uint, uint)));
        } else {
            qWarning() << "AthanNotification: Session D-Bus is not connected!";
        }
    }

    ~AthanNotification() override
    {
        close();
    }

    static bool isDisplayOn()
    {
        QDBusConnection sysBus = QDBusConnection::systemBus();
        if (!sysBus.isConnected())
            return false;

        QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                           QStringLiteral("/com/nokia/mce/request"),
                           QStringLiteral("com.nokia.mce.request"),
                           sysBus);
        if (mce.isValid()) {
            QDBusMessage reply = mce.call(QStringLiteral("get_display_status"));
            if (reply.type() != QDBusMessage::ErrorMessage && !reply.arguments().isEmpty()) {
                return (reply.arguments().at(0).toString() != QStringLiteral("off"));
            }
        }
        return false;
    }

    static void wakeDisplay()
    {
        QDBusConnection sysBus = QDBusConnection::systemBus();
        if (sysBus.isConnected()) {
            QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/request"),
                               QStringLiteral("com.nokia.mce.request"),
                               sysBus);
            if (mce.isValid()) {
                mce.call(QStringLiteral("req_display_state_on"));
            }
        }
    }

    bool show()
    {
        QDBusConnection sessionBus = QDBusConnection::sessionBus();
        if (!sessionBus.isConnected()) {
            qWarning() << "AthanNotification: Session D-Bus is not connected!";
            return false;
        }

        // Wake display only if configured to turn on screen
        if (m_turnOnScreen) {
            wakeDisplay();
        }

        QDBusInterface iface(QStringLiteral("org.freedesktop.Notifications"),
                             QStringLiteral("/org/freedesktop/Notifications"),
                             QStringLiteral("org.freedesktop.Notifications"),
                             sessionBus);
        if (!iface.isValid()) {
            qWarning() << "AthanNotification: org.freedesktop.Notifications interface is not valid:"
                       << iface.lastError().message();
            return false;
        }

        bool isFridayDhuhr = (m_prayer == QStringLiteral("dhuhr") && QDate::currentDate().dayOfWeek() == Qt::Friday);
        QString prayerDisplay;
        if (m_prayer == QStringLiteral("fajr")) prayerDisplay = tr("Fajr");
        else if (m_prayer == QStringLiteral("sunrise")) prayerDisplay = tr("Chourouq");
        else if (m_prayer == QStringLiteral("dhuhr")) prayerDisplay = isFridayDhuhr ? tr("Friday prayer") : tr("Dhouhr");
        else if (m_prayer == QStringLiteral("asr")) prayerDisplay = tr("Assar");
        else if (m_prayer == QStringLiteral("maghrib")) prayerDisplay = tr("Maghreb");
        else if (m_prayer == QStringLiteral("isha")) prayerDisplay = tr("Ishaa");
        else if (m_prayer == QStringLiteral("morning_athkar")) prayerDisplay = tr("Morning Athkar");
        else if (m_prayer == QStringLiteral("evening_athkar")) prayerDisplay = tr("Evening Athkar");
        else prayerDisplay = m_prayer.isEmpty() ? tr("Athan") : (m_prayer.left(1).toUpper() + m_prayer.mid(1));

        bool isSunrise = (m_prayer == QStringLiteral("sunrise"));
        bool isAthkar = (m_prayer == QStringLiteral("morning_athkar") || m_prayer == QStringLiteral("evening_athkar"));
        QString summary = isSunrise
                ? tr("Sunrise (Chourouq)")
                : (isAthkar ? prayerDisplay : (isFridayDhuhr ? tr("Friday Prayer Time") : tr("%1 Prayer Time").arg(prayerDisplay)));
        QString body = isSunrise
                ? tr("Sunrise time has entered.")
                : (isAthkar ? tr("Athkar is playing. Tap Stop to silence.") : tr("Athan is playing. Tap Stop to silence."));

        QStringList actions;
        actions << QStringLiteral("stop") << tr("Stop")
                << QStringLiteral("default") << tr("Stop");

        QVariantMap hints;
        hints.insert(QStringLiteral("x-nemo-preview-summary"), summary);
        hints.insert(QStringLiteral("x-nemo-preview-body"), body);
        hints.insert(QStringLiteral("category"), QStringLiteral("x-nemo.alarm"));
        hints.insert(QStringLiteral("urgency"), uchar(2)); // Critical / Alarm urgency
        hints.insert(QStringLiteral("x-nemo-priority"), 100);
        hints.insert(QStringLiteral("x-nemo-display-on"), m_turnOnScreen);
        hints.insert(QStringLiteral("x-nemo-icon"), QStringLiteral("harbour-thakir"));

        QDBusReply<uint> reply = iface.call(QStringLiteral("Notify"),
                                            QStringLiteral("harbour-thakir"),
                                            m_notificationId,
                                            QStringLiteral("harbour-thakir"),
                                            summary,
                                            body,
                                            actions,
                                            hints,
                                            int(0)); // 0: no automatic timeout

        if (reply.isValid()) {
            m_notificationId = reply.value();
            qDebug() << "AthanNotification: Published notification ID" << m_notificationId << "for" << m_prayer;
            return true;
        } else {
            qWarning() << "AthanNotification: Failed to publish notification:" << reply.error().message();
            return false;
        }
    }

    void close()
    {
        if (m_notificationId == 0)
            return;

        uint idToClose = m_notificationId;
        m_notificationId = 0;

        QDBusInterface iface(QStringLiteral("org.freedesktop.Notifications"),
                             QStringLiteral("/org/freedesktop/Notifications"),
                             QStringLiteral("org.freedesktop.Notifications"),
                             QDBusConnection::sessionBus());
        if (iface.isValid()) {
            iface.call(QStringLiteral("CloseNotification"), idToClose);
            qDebug() << "AthanNotification: Closed notification ID" << idToClose;
        }
    }

signals:
    void stopRequested();

public slots:
    void onActionInvoked(uint id, const QString &actionKey)
    {
        if (m_notificationId != 0 && id == m_notificationId) {
            qDebug() << "AthanNotification: Action" << actionKey << "invoked for notification ID" << id;
            emit stopRequested();
        }
    }

    void onNotificationClosed(uint id, uint reason)
    {
        if (m_notificationId != 0 && id == m_notificationId) {
            qDebug() << "AthanNotification: Notification ID" << id << "closed with reason" << reason;
            m_notificationId = 0;
            // Reason 2 = dismissed by user
            if (reason == 2) {
                emit stopRequested();
            }
        }
    }

private:
    QString m_prayer;
    bool m_turnOnScreen;
    uint m_notificationId;
};

#endif // ATHANNOTIFICATION_H
