#ifndef POWERBUTTONWATCHER_H
#define POWERBUTTONWATCHER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QOrientationSensor>
#include <QOrientationFilter>
#include <QOrientationReading>
#include <QProcess>
#include <QTimer>
#include <QScopedPointer>
#include <QElapsedTimer>
#include <QRegularExpression>
#include <QDebug>
#include "settingshelper.h"

class PowerButtonWatcher : public QObject, public QOrientationFilter
{
    Q_OBJECT
public:
    explicit PowerButtonWatcher(QObject *parent = nullptr)
        : PowerButtonWatcher(true, true, true, parent) {}

    explicit PowerButtonWatcher(bool stopWithPower, bool stopWithFlipOver, QObject *parent = nullptr)
        : PowerButtonWatcher(stopWithPower, stopWithFlipOver, true, parent) {}

    explicit PowerButtonWatcher(bool stopWithPower, bool stopWithFlipOver, bool stopWithVolume, QObject *parent = nullptr)
        : PowerButtonWatcher(stopWithPower, stopWithFlipOver, stopWithVolume,
                             SettingsHelper::value(QStringLiteral("turnOnScreenDuringPlayback"), false).toBool(), parent) {}

    explicit PowerButtonWatcher(bool stopWithPower, bool stopWithFlipOver, bool stopWithVolume, bool turnOnScreen, QObject *parent = nullptr)
        : QObject(parent),
          m_stopWithPower(stopWithPower),
          m_stopWithFlipOver(stopWithFlipOver),
          m_stopWithVolume(stopWithVolume),
          m_turnOnScreen(turnOnScreen),
          m_currentDisplayState(getDisplayStatus()),
          m_sensor(nullptr),
          m_initialOrientation(QOrientationReading::Undefined),
          m_initialVolumeStep(-1),
          m_hasInitialStep(false),
          m_initialSinkVolume(),
          m_sinkNameOrIndex(),
          m_initialRingerVolume(-1),
          m_currentProfile(QStringLiteral("general")),
          m_volumeTimer(nullptr),
          m_blankPreventTimer(nullptr),
          m_subscribeProc(nullptr),
          m_silentStreamProc(nullptr),
          m_stopped(false)
    {
        init();
    }

    ~PowerButtonWatcher() override
    {
        cleanup();
    }

    void cleanup()
    {
        if (m_blankPreventTimer) {
            m_blankPreventTimer->stop();
            delete m_blankPreventTimer;
            m_blankPreventTimer = nullptr;
        }
        if (m_silentStreamProc) {
            m_silentStreamProc->terminate();
            if (!m_silentStreamProc->waitForFinished(300)) {
                m_silentStreamProc->kill();
            }
            delete m_silentStreamProc;
            m_silentStreamProc = nullptr;
        }
        if (m_sensor) {
            m_sensor->stop();
            m_sensor->removeFilter(this);
            delete m_sensor;
            m_sensor = nullptr;
        }
        if (m_volumeTimer) {
            m_volumeTimer->stop();
            delete m_volumeTimer;
            m_volumeTimer = nullptr;
        }
        if (m_subscribeProc) {
            m_subscribeProc->terminate();
            if (!m_subscribeProc->waitForFinished(300)) {
                m_subscribeProc->kill();
            }
            delete m_subscribeProc;
            m_subscribeProc = nullptr;
        }
        cancelBlankingPause();
    }

    void init()
    {
        m_startTime.start();
        m_currentDisplayState = getDisplayStatus();
        if (m_currentDisplayState == QStringLiteral("on") || m_currentDisplayState == QStringLiteral("dimmed")) {
            m_screenOnTime.start();
        }

        if (m_stopWithPower || m_stopWithVolume || m_stopWithFlipOver) {
            QDBusConnection sysBus = QDBusConnection::systemBus();
            if (!sysBus.isConnected()) {
                qWarning() << "PowerButtonWatcher: System D-Bus is not connected!";
            } else {
                if (m_stopWithPower) {
                    sysBus.connect(QStringLiteral("com.nokia.mce"),
                                   QStringLiteral("/com/nokia/mce/signal"),
                                   QStringLiteral("com.nokia.mce.signal"),
                                   QStringLiteral("display_status_ind"),
                                   this,
                                   SLOT(onDisplayStatusInd(QString)));

                    sysBus.connect(QStringLiteral("com.nokia.mce"),
                                   QStringLiteral("/com/nokia/mce/signal"),
                                   QStringLiteral("com.nokia.mce.signal"),
                                   QStringLiteral("power_button_trigger"),
                                   this,
                                   SLOT(onPowerButtonTrigger(QString)));
                }

                sysBus.connect(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/signal"),
                               QStringLiteral("com.nokia.mce.signal"),
                               QStringLiteral("alarm_ui_feedback_ind"),
                               this,
                               SLOT(onAlarmUiFeedbackInd(QString)));

                qDebug() << "PowerButtonWatcher: Initialized MCE monitoring (stopWithPower:"
                         << m_stopWithPower << ", stopWithVolume:" << m_stopWithVolume
                         << ", current display:" << m_currentDisplayState << ")";
            }
        }

        if (m_stopWithFlipOver) {
            m_sensor = new QOrientationSensor(this);
            m_sensor->addFilter(this);
            bool started = m_sensor->start();
            qDebug() << "PowerButtonWatcher: Initialized flip-over/upside-down sensor, started:" << started;
        }

        if (m_turnOnScreen) {
            // Wake display if screen is off so Sailfish OS lockscreen preview is shown
            if (m_currentDisplayState == QStringLiteral("off")) {
                wakeDisplay();
            }

            // Keep display dimmed during playback so hardware buttons remain responsive
            requestBlankingPause();
            dimDisplay();

            m_blankPreventTimer = new QTimer(this);
            m_blankPreventTimer->setInterval(2500);
            connect(m_blankPreventTimer, &QTimer::timeout, this, [this]() {
                requestBlankingPause();
                dimDisplay();
            });
            m_blankPreventTimer->start();
        }

        if (m_stopWithVolume) {
            // Start background silent music stream:
            // In Sailfish OS MCE volkey policy:
            // "Volume keys are enabled when display is on OR audio policy indicates music playback".
            // Having an active media.role=music stream guarantees MCE enables volume keys
            // EVEN WHEN THE DISPLAY IS COMPLETELY OFF (e.g. phone in pocket).
            startSilentMusicStream();

            // 3. Capture initial volume levels
            captureInitialVolume();

            // 4. Reactive real-time PulseAudio event listener
            m_subscribeProc = new QProcess(this);
            connect(m_subscribeProc, &QProcess::readyReadStandardOutput, this, &PowerButtonWatcher::onPactlOutput);
            m_subscribeProc->start(QStringLiteral("pactl"), {QStringLiteral("subscribe")});

            // 5. Connect to com.nokia.profiled on sessionBus
            QDBusConnection sessionBus = QDBusConnection::sessionBus();
            if (sessionBus.isConnected()) {
                sessionBus.connect(QStringLiteral("com.nokia.profiled"),
                                   QStringLiteral("/com/nokia/profiled"),
                                   QStringLiteral("com.nokia.profiled"),
                                   QStringLiteral("profile_changed"),
                                   this,
                                   SLOT(onProfileChanged()));
            }

            // 6. Connect to com.Meego.MainVolume2 on both system and session bus
            QDBusConnection sysBus = QDBusConnection::systemBus();
            if (sysBus.isConnected()) {
                sysBus.connect(QStringLiteral("com.Meego.MainVolume2"),
                               QString(),
                               QStringLiteral("org.freedesktop.DBus.Properties"),
                               QStringLiteral("PropertiesChanged"),
                               this,
                               SLOT(onVolumePropertiesChanged(QString, QVariantMap, QStringList)));
            }
            if (sessionBus.isConnected()) {
                sessionBus.connect(QStringLiteral("com.Meego.MainVolume2"),
                                   QString(),
                                   QStringLiteral("org.freedesktop.DBus.Properties"),
                                   QStringLiteral("PropertiesChanged"),
                                   this,
                                   SLOT(onVolumePropertiesChanged(QString, QVariantMap, QStringList)));
            }

            // 7. Polling safety net every 400ms (lightweight D-Bus in-memory check)
            m_volumeTimer = new QTimer(this);
            m_volumeTimer->setInterval(400);
            connect(m_volumeTimer, &QTimer::timeout, this, &PowerButtonWatcher::checkVolumeChange);
            m_volumeTimer->start();
            qDebug() << "PowerButtonWatcher: Initialized multi-layered volume monitoring with screen-off support";
        }
    }

    void startSilentMusicStream()
    {
        if (m_silentStreamProc)
            return;

        m_silentStreamProc = new QProcess(this);
        const QStringList args = {
            QStringLiteral("--playback"),
            QStringLiteral("--raw"),
            QStringLiteral("--channels=1"),
            QStringLiteral("--rate=8000"),
            QStringLiteral("--format=s16le"),
            QStringLiteral("--volume=0"),
            QStringLiteral("--property=media.role=music"),
            QStringLiteral("/dev/zero")
        };
        m_silentStreamProc->start(QStringLiteral("/usr/bin/paplay"), args);
        qDebug() << "PowerButtonWatcher: Started silent music stream for screen-off volume key handling";
    }

    static QDBusInterface *createVolumeInterface(const QDBusConnection &bus)
    {
        if (!bus.isConnected())
            return nullptr;
        auto *vol = new QDBusInterface(QStringLiteral("com.Meego.MainVolume2"),
                                       QStringLiteral("/com/Meego/MainVolume2"),
                                       QStringLiteral("com.Meego.MainVolume2"),
                                       bus);
        if (!vol->isValid()) {
            delete vol;
            vol = new QDBusInterface(QStringLiteral("com.Meego.MainVolume2"),
                                     QStringLiteral("/"),
                                     QStringLiteral("com.Meego.MainVolume2"),
                                     bus);
        }
        if (!vol->isValid()) {
            delete vol;
            vol = new QDBusInterface(QStringLiteral("com.meego.mainvolume2"),
                                     QStringLiteral("/com/meego/mainvolume2"),
                                     QStringLiteral("com.meego.mainvolume2"),
                                     bus);
        }
        if (!vol->isValid()) {
            delete vol;
            return nullptr;
        }
        return vol;
    }

    static int queryVolumeStep()
    {
        const QDBusConnection buses[2] = { QDBusConnection::sessionBus(), QDBusConnection::systemBus() };
        for (int i = 0; i < 2; ++i) {
            if (buses[i].isConnected()) {
                QScopedPointer<QDBusInterface> vol(createVolumeInterface(buses[i]));
                if (vol && vol->isValid()) {
                    QVariant v = vol->property("CurrentStep");
                    if (v.isValid()) return v.toInt();
                }
            }
        }
        return -1;
    }

    static void setVolumeStep(int step)
    {
        const QDBusConnection buses[2] = { QDBusConnection::sessionBus(), QDBusConnection::systemBus() };
        for (int i = 0; i < 2; ++i) {
            if (buses[i].isConnected()) {
                QScopedPointer<QDBusInterface> vol(createVolumeInterface(buses[i]));
                if (vol && vol->isValid()) {
                    vol->setProperty("CurrentStep", step);
                }
            }
        }
    }

    static QString getCurrentProfile(const QDBusConnection &bus)
    {
        if (!bus.isConnected())
            return QStringLiteral("general");
        QDBusInterface profiled(QStringLiteral("com.nokia.profiled"),
                               QStringLiteral("/com/nokia/profiled"),
                               QStringLiteral("com.nokia.profiled"),
                               bus);
        if (profiled.isValid()) {
            QDBusMessage reply = profiled.call(QStringLiteral("get_profile"));
            if (!reply.arguments().isEmpty()) {
                return reply.arguments().at(0).toString();
            }
        }
        return QStringLiteral("general");
    }

    static int getRingerVolume(const QDBusConnection &bus, const QString &profile)
    {
        if (!bus.isConnected())
            return -1;
        QDBusInterface profiled(QStringLiteral("com.nokia.profiled"),
                               QStringLiteral("/com/nokia/profiled"),
                               QStringLiteral("com.nokia.profiled"),
                               bus);
        if (profiled.isValid()) {
            QDBusMessage reply = profiled.call(QStringLiteral("get_value"), profile, QStringLiteral("ringing.alert.volume"));
            if (!reply.arguments().isEmpty()) {
                return reply.arguments().at(0).toString().toInt();
            }
        }
        return -1;
    }

    QString queryCurrentSinkVolume()
    {
        QProcess proc;
        proc.start(QStringLiteral("pactl"), {QStringLiteral("list"), QStringLiteral("sinks")});
        if (proc.waitForFinished(1000)) {
            QString out = QString::fromUtf8(proc.readAllStandardOutput());
            QRegularExpression rxVol(QStringLiteral("Volume:[^\\n\\r]*?(\\d+%)"));
            QRegularExpressionMatch matchVol = rxVol.match(out);
            if (matchVol.hasMatch()) {
                if (m_sinkNameOrIndex.isEmpty()) {
                    QRegularExpression rxSink(QStringLiteral("Sink #(\\d+)"));
                    QRegularExpressionMatch matchSink = rxSink.match(out);
                    if (matchSink.hasMatch()) {
                        m_sinkNameOrIndex = matchSink.captured(1);
                    }
                }
                return matchVol.captured(1);
            }
        }
        return QString();
    }

    void captureInitialVolume()
    {
        // 1. Check pactl sink volume
        m_initialSinkVolume = queryCurrentSinkVolume();
        qDebug() << "PowerButtonWatcher: Initial pactl sink volume:" << m_initialSinkVolume
                 << "sink index/name:" << m_sinkNameOrIndex;

        // 2. Check profiled ringer volume
        QDBusConnection sessionBus = QDBusConnection::sessionBus();
        if (sessionBus.isConnected()) {
            m_currentProfile = getCurrentProfile(sessionBus);
            m_initialRingerVolume = getRingerVolume(sessionBus, m_currentProfile);
            qDebug() << "PowerButtonWatcher: Initial profiled ringer volume:"
                     << m_initialRingerVolume << "profile:" << m_currentProfile;
        }

        // 3. Check com.Meego.MainVolume2 step
        m_initialVolumeStep = queryVolumeStep();
        if (m_initialVolumeStep >= 0) {
            m_hasInitialStep = true;
            qDebug() << "PowerButtonWatcher: Initial com.Meego.MainVolume2 step:" << m_initialVolumeStep;
        }
    }

    void restoreVolume()
    {
        // 1. Restore pactl sink volume
        if (!m_initialSinkVolume.isEmpty()) {
            QProcess::execute(QStringLiteral("pactl"),
                              {QStringLiteral("set-sink-volume"), QStringLiteral("@DEFAULT_SINK@"), m_initialSinkVolume});
            if (!m_sinkNameOrIndex.isEmpty()) {
                QProcess::execute(QStringLiteral("pactl"),
                                  {QStringLiteral("set-sink-volume"), m_sinkNameOrIndex, m_initialSinkVolume});
            }
            qDebug() << "PowerButtonWatcher: Restored pactl sink volume to" << m_initialSinkVolume;
        }

        // 2. Restore profiled ringer volume
        if (m_initialRingerVolume >= 0 && !m_currentProfile.isEmpty()) {
            QDBusConnection sessionBus = QDBusConnection::sessionBus();
            if (sessionBus.isConnected()) {
                QDBusInterface profiled(QStringLiteral("com.nokia.profiled"),
                                       QStringLiteral("/com/nokia/profiled"),
                                       QStringLiteral("com.nokia.profiled"),
                                       sessionBus);
                if (profiled.isValid()) {
                    profiled.call(QStringLiteral("set_value"), m_currentProfile,
                                  QStringLiteral("ringing.alert.volume"),
                                  QString::number(m_initialRingerVolume));
                    qDebug() << "PowerButtonWatcher: Restored profiled ringer volume to" << m_initialRingerVolume;
                }
            }
        }

        // 3. Restore com.Meego.MainVolume2
        if (m_hasInitialStep) {
            setVolumeStep(m_initialVolumeStep);
            qDebug() << "PowerButtonWatcher: Restored com.Meego.MainVolume2 step to" << m_initialVolumeStep;
        }
    }

    void triggerStop(const QString &reason)
    {
        if (m_stopped)
            return;
        m_stopped = true;

        qDebug() << "PowerButtonWatcher: Stop triggered! Reason:" << reason;
        cleanup();
        restoreVolume();
        emit stopTriggered();
        emit powerButtonPressed();
    }

    void triggerVolumeStop()
    {
        triggerStop(QStringLiteral("Volume button pressed"));
    }

    bool filter(QOrientationReading *reading) override
    {
        if (!reading || !m_stopWithFlipOver)
            return false;

        QOrientationReading::Orientation orientation = reading->orientation();
        if (m_initialOrientation == QOrientationReading::Undefined) {
            m_initialOrientation = orientation;
            qDebug() << "PowerButtonWatcher: Initial orientation set to" << orientation;
            return false;
        }

        // FaceDown: phone is lying face down (screen towards surface)
        // TopDown: phone is held upside down (top towards ground)
        if (orientation == QOrientationReading::FaceDown || orientation == QOrientationReading::TopDown) {
            if (m_initialOrientation != orientation) {
                m_initialOrientation = orientation;
                triggerStop(QStringLiteral("Phone turned upside down / face down"));
            }
        } else {
            m_initialOrientation = orientation;
        }

        return false;
    }

    static QString getDisplayStatus()
    {
        QDBusConnection sysBus = QDBusConnection::systemBus();
        if (!sysBus.isConnected())
            return QStringLiteral("off");

        QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                           QStringLiteral("/com/nokia/mce/request"),
                           QStringLiteral("com.nokia.mce.request"),
                           sysBus);
        if (mce.isValid()) {
            QDBusMessage reply = mce.call(QStringLiteral("get_display_status"));
            if (reply.type() != QDBusMessage::ErrorMessage && !reply.arguments().isEmpty()) {
                return reply.arguments().at(0).toString();
            }
        }
        return QStringLiteral("off");
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

    static void dimDisplay()
    {
        QDBusConnection sysBus = QDBusConnection::systemBus();
        if (sysBus.isConnected()) {
            QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/request"),
                               QStringLiteral("com.nokia.mce.request"),
                               sysBus);
            if (mce.isValid()) {
                mce.call(QStringLiteral("req_display_state_dim"));
            }
        }
    }

    static void requestBlankingPause()
    {
        QDBusConnection sysBus = QDBusConnection::systemBus();
        if (sysBus.isConnected()) {
            QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/request"),
                               QStringLiteral("com.nokia.mce.request"),
                               sysBus);
            if (mce.isValid()) {
                mce.call(QStringLiteral("req_display_blanking_pause"));
            }
        }
    }

    static void cancelBlankingPause()
    {
        QDBusConnection sysBus = QDBusConnection::systemBus();
        if (sysBus.isConnected()) {
            QDBusInterface mce(QStringLiteral("com.nokia.mce"),
                               QStringLiteral("/com/nokia/mce/request"),
                               QStringLiteral("com.nokia.mce.request"),
                               sysBus);
            if (mce.isValid()) {
                mce.call(QStringLiteral("req_display_cancel_blanking_pause"));
            }
        }
    }

signals:
    void stopTriggered();
    void powerButtonPressed();

public slots:
    void onPactlOutput()
    {
        if (!m_stopWithVolume || m_stopped || !m_subscribeProc)
            return;

        QByteArray data = m_subscribeProc->readAllStandardOutput();
        if (m_startTime.elapsed() < 800) {
            return; // Ignore startup audio stream registration events
        }

        QString text = QString::fromUtf8(data);
        qDebug() << "PowerButtonWatcher: pactl subscribe event:" << text.trimmed();

        if (text.contains(QStringLiteral("sink")) || text.contains(QStringLiteral("server"))) {
            triggerStop(QStringLiteral("PulseAudio volume/sink event detected"));
        }
    }

    void onProfileChanged()
    {
        if (!m_stopWithVolume || m_stopped)
            return;
        if (m_startTime.elapsed() < 800)
            return;

        QDBusConnection sessionBus = QDBusConnection::sessionBus();
        QString currentProfile = getCurrentProfile(sessionBus);
        if (currentProfile == QStringLiteral("silent")) {
            QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
            if (s.value(QStringLiteral("silent/active"), false).toBool()) {
                qDebug() << "PowerButtonWatcher: Profile changed to silent by SilentModeHelper, ignoring";
                return;
            }
        }

        triggerStop(QStringLiteral("profiled profile_changed detected"));
    }

    void onPowerButtonTrigger(const QString &event)
    {
        qDebug() << "PowerButtonWatcher: power_button_trigger =" << event;
        if (m_stopWithPower) {
            triggerStop(QStringLiteral("MCE power_button_trigger: ") + event);
        }
    }

    void onAlarmUiFeedbackInd(const QString &event)
    {
        qDebug() << "PowerButtonWatcher: alarm_ui_feedback_ind =" << event;
        if (event == QStringLiteral("powerkey")) {
            if (m_stopWithPower) {
                triggerStop(QStringLiteral("MCE alarm_ui_feedback_ind: powerkey"));
            }
        } else if (event == QStringLiteral("volume_up") || event == QStringLiteral("volume_down")) {
            if (m_stopWithVolume) {
                triggerStop(QStringLiteral("MCE alarm_ui_feedback_ind: ") + event);
            }
        } else if (event == QStringLiteral("flipover")) {
            if (m_stopWithFlipOver) {
                triggerStop(QStringLiteral("MCE alarm_ui_feedback_ind: flipover"));
            }
        }
    }

    void onVolumePropertiesChanged(const QString &interface, const QVariantMap &changedProps, const QStringList &invalidated)
    {
        Q_UNUSED(invalidated);
        if (!m_stopWithVolume || m_stopped)
            return;

        if (interface == QStringLiteral("com.Meego.MainVolume2") || changedProps.contains(QStringLiteral("CurrentStep"))) {
            int current = changedProps.value(QStringLiteral("CurrentStep"), -1).toInt();
            if (m_hasInitialStep && current != -1 && current != m_initialVolumeStep) {
                triggerStop(QStringLiteral("MainVolume2 CurrentStep changed to %1 (was %2)").arg(current).arg(m_initialVolumeStep));
            }
        }
    }

    void checkVolumeChange()
    {
        if (!m_stopWithVolume || m_stopped)
            return;

        if (m_startTime.elapsed() < 800)
            return;

        // 1. Check profiled ringer volume via D-Bus (instant in-memory IPC)
        if (m_initialRingerVolume >= 0) {
            QDBusConnection sessionBus = QDBusConnection::sessionBus();
            int currentRinger = getRingerVolume(sessionBus, m_currentProfile);
            if (currentRinger >= 0 && currentRinger != m_initialRingerVolume) {
                triggerStop(QStringLiteral("Profiled ringer volume changed to %1 (was %2)").arg(currentRinger).arg(m_initialRingerVolume));
                return;
            }
        }

        // 2. Check MainVolume2 step via D-Bus (instant in-memory IPC)
        if (m_hasInitialStep) {
            int currentStep = queryVolumeStep();
            if (currentStep >= 0 && currentStep != m_initialVolumeStep) {
                triggerStop(QStringLiteral("MainVolume2 step changed to %1 (was %2)").arg(currentStep).arg(m_initialVolumeStep));
                return;
            }
        }

        // 3. Fallback pactl query only if pactl subscribe process is inactive
        if (!m_subscribeProc || m_subscribeProc->state() != QProcess::Running) {
            if (!m_initialSinkVolume.isEmpty()) {
                QString currentSink = queryCurrentSinkVolume();
                if (!currentSink.isEmpty() && currentSink != m_initialSinkVolume) {
                    triggerStop(QStringLiteral("Sink volume changed to %1 (was %2)").arg(currentSink).arg(m_initialSinkVolume));
                    return;
                }
            }
        }
    }

    void onDisplayStatusInd(const QString &state)
    {
        if (!m_stopWithPower)
            return;

        QString prevState = m_currentDisplayState;
        m_currentDisplayState = state;

        qDebug() << "PowerButtonWatcher: display_status_ind =" << state
                 << "(prev was:" << prevState << ")";

        if (state == prevState) {
            return;
        }

        // When the screen turns off (e.g. preview timeout or pocket),
        // playback must continue normally to the end.
        if (state == QStringLiteral("off")) {
            qDebug() << "PowerButtonWatcher: Screen turned OFF -> continuing playback";
            return;
        }

        // When the screen was OFF and the user presses the power button,
        // the screen wakes up (off -> on/dimmed) -> User pressed power button to stop Athan!
        if (prevState == QStringLiteral("off") && (state == QStringLiteral("on") || state == QStringLiteral("dimmed"))) {
            if (m_startTime.elapsed() < 1200) {
                qDebug() << "PowerButtonWatcher: Ignoring startup screen wakeup";
                return;
            }
            triggerStop(QStringLiteral("Screen woke UP from OFF state -> Power button pressed"));
            return;
        }
    }

private:
    bool m_stopWithPower;
    bool m_stopWithFlipOver;
    bool m_stopWithVolume;
    bool m_turnOnScreen;
    QString m_currentDisplayState;
    QOrientationSensor *m_sensor;
    QOrientationReading::Orientation m_initialOrientation;
    int m_initialVolumeStep;
    bool m_hasInitialStep;
    QString m_initialSinkVolume;
    QString m_sinkNameOrIndex;
    int m_initialRingerVolume;
    QString m_currentProfile;
    QTimer *m_volumeTimer;
    QTimer *m_blankPreventTimer;
    QProcess *m_subscribeProc;
    QProcess *m_silentStreamProc;
    QElapsedTimer m_startTime;
    QElapsedTimer m_screenOnTime;
    bool m_stopped;
};

#endif // POWERBUTTONWATCHER_H
