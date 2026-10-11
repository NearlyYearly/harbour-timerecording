Name:       harbour-timerecord
Summary:    Time recording with tasks, day notes and automatic breaks
Version:    0.7.1
Release:    1
License:    GPL-3.0-or-later
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 1.0
Requires:   libsailfishapp-launcher
Requires:   pyotherside-qml-plugin-python3-qt5 >= 1.5
Requires:   python3-sqlite
Requires:   nemo-qml-plugin-notifications-qt5
Requires:   libkeepalive
Requires:   nemo-qml-plugin-dbus-qt5

%description
Check in and out, tasks, day notes, automatic break rules, punch rounding,
undo/redo and JSON backups.

%prep
%setup -q -n %{name}-%{version}

%build

%install
rm -rf %{buildroot}
install -d %{buildroot}%{_datadir}/%{name}
cp -r qml python %{buildroot}%{_datadir}/%{name}/
find %{buildroot}%{_datadir}/%{name} -name '__pycache__' -prune -exec rm -rf {} +
install -D -m 644 %{name}.desktop %{buildroot}%{_datadir}/applications/%{name}.desktop
install -D -m 644 dbus/org.timerecord.%{name}.service \
    %{buildroot}%{_datadir}/dbus-1/services/org.timerecord.%{name}.service
for size in 86 108 128 172; do
    install -D -m 644 icons/${size}x${size}/%{name}.png \
        %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/%{name}.png
done

%files
%defattr(-,root,root,-)
%license LICENSE
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/dbus-1/services/org.timerecord.%{name}.service
%{_datadir}/icons/hicolor/*/apps/%{name}.png
