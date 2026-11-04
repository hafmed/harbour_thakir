Name:       harbour-thakir
Summary:    Athan (call to prayer) times for any city
Version:    3.5.9
Release:    1
License:    LICENSE
URL:        https://example.com/harbour-thakir
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   qt5-plugin-geoservices-osm >= 5.2.0
Requires:   qt5-qtlocation >= 5.2.0
Requires:   qt5-qtdeclarative-import-location >= 5.2.0
Requires:   qt5-qtdeclarative-import-positioning >= 5.2.0
Requires:   qt5-qtdeclarative-import-sensors >= 5.2.0
Requires:   qt5-qtsensors >= 5.2.0
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Sql)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5Multimedia)
BuildRequires:  pkgconfig(Qt5Positioning)
BuildRequires:  pkgconfig(Qt5Location)
BuildRequires:  pkgconfig(Qt5Sensors)
BuildRequires:  pkgconfig(Qt5DBus)
BuildRequires:  pkgconfig(Qt5Svg)
BuildRequires:  desktop-file-utils

%description
Athan lets you pick any city in the world - by text search or by
tapping a point on a map - and computes accurate prayer times for it,
automatically choosing a sensible calculation method based on the
country. Plays the athan automatically: a system-level timer
(harbour-thakir-check.timer, using WakeSystem=true to wake the device
from real suspend via the hardware RTC alarm) periodically runs this
same binary with --check-and-play, which plays any prayer that's
currently due and not yet played today.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
%make_build

%install
%qmake5_install

desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_datadir}/dbus-1/services/*.service
/usr/lib/systemd/system/%{name}-check.timer
/usr/lib/systemd/system/%{name}-check.service

%post
# Runs with root privileges as part of package installation (whether
# via pkcon, `rpm -i` under devel-su, or the IDE's deploy step) - a
# system-level unit's systemd instance (unlike a --user one) is always
# available at this point, so this can safely run automatically instead
# of requiring the user to do it by hand afterward. "||:" makes each
# line non-fatal to the install if systemctl is ever unavailable for
# some reason.
systemctl daemon-reload ||:
systemctl enable --now %{name}-check.timer ||:
systemctl restart %{name}-check.timer ||:
update-desktop-database %{_datadir}/applications ||:

%preun
# Only on final removal, not on upgrade (an upgrade's %post above will
# re-enable it against the new files).
if [ "$1" -eq 0 ]; then
    systemctl disable --now %{name}-check.timer ||:
fi
