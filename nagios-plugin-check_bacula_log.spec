%define		plugin	check_bacula_log
%include	/usr/lib/rpm/macros.perl
Summary:	Nagios plugin to check bacula status via bacula log
Name:		nagios-plugin-%{plugin}
Version:	0.3
Release:	2
License:	GPL v2
Group:		Networking
# Source0Download: http://exchange.nagios.org/components/com_mtree/attachment.php?link_id=1327&cf_id=24
Source0:	nocturnal_nagios_plugins-1.0.tar.gz
# Source0-md5:	3a50cd7abee1801e578ef0374cf2a072
URL:		http://exchange.nagios.org/directory/Plugins/Backup-and-Recovery/Bacula/nagios%252Dcheck_bacula/details
Patch0:		fixes.patch
BuildRequires:	perl-devel >= 1:5.8.0
BuildRequires:	rpm-perlprov >= 4.1-13
Requires:	nagios-common
Requires:	nagios-plugins-libs
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%define		_sysconfdir	/etc/nagios/plugins
%define		plugindir	%{_prefix}/lib/nagios/plugins

%define		_noautoreq	'perl(utils)'

%description
Nagios plugin that checks whether the backups made for today with the
Bacula backup system were succesful.

This requires the Nagios user to have read access to the bacula log
file.

%prep
%setup -qc
%patch0 -p1

cat > nagios.cfg <<'EOF'
# Usage:
# %{plugin} -F /var/log/bacula/log
define command {
	command_name    %{plugin}
	command_line    %{plugindir}/%{plugin} $ARG1$
}

define service {
	use                     generic-service
    name                    bacula_log
    register                0
	service_description     Bacula job status

	normal_check_interval   86400
	notification_interval   86400
	max_check_attempts      1

	check_command           %{plugin}
}
EOF

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT{%{_sysconfdir},%{plugindir}}
install -p check_bacula $RPM_BUILD_ROOT%{plugindir}/%{plugin}
cp -a nagios.cfg $RPM_BUILD_ROOT%{_sysconfdir}/%{plugin}.cfg

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%config(noreplace) %verify(not md5 mtime size) %{_sysconfdir}/%{plugin}.cfg
%attr(755,root,root) %{plugindir}/%{plugin}
