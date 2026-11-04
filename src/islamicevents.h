#ifndef ISLAMICEVENTS_H
#define ISLAMICEVENTS_H

#include <QString>

struct IslamicEventInfo {
    bool hasEvent = false;
    QString banner;
    QString title;
    QString content;
};

class IslamicEvents {
public:
    static IslamicEventInfo getEvent(int hijriDay, int hijriMonth);
};

#endif // ISLAMICEVENTS_H
