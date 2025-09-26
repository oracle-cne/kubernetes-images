# Disable several RPM packaging features that we either do not need or corrupt the image files
AutoReqProv: no
%define _build_id_links none
%global __strip /bin/true
%global __os_install_post %(echo '%{__os_install_post}' | sed -e 's!/usr/lib[^[:space:]]*/brp-python-bytecompile[[:space:]].*$!!g')

%if 0%{?with_debug}
%global _dwz_low_mem_die_limit 0
%else
%global debug_package %{nil}
%endif

# Image tags + kubernetes version
%global majorminor              
%global patch                   
%global pause
%global etcd
%global coredns
%global flannel
%global ui
%global ui_plugins
%global catalog
%global nginx
%global base

%global _buildhost              build-ol%{?oraclelinux}-%{?_arch}.oracle.com
%global app_name                kubernetes-imgs
%global app_version             %{majorminor}.%{patch}
%global oracle_release_version  1
%global kubernetes_version      %{majorminor}.%{patch}


Name:           %{app_name}
Version:        %{app_version}
Release:        %{oracle_release_version}%{?dist}
Vendor:         Oracle America
Summary:        Kubernetes images needed to bootstrap an Oracle Cloud Native Environment cluster.
License:        UPL 1.0
Group:          Development/Tools

Source0:        %{name}-%{version}.tar.bz2
BuildRequires:  podman >= 4.6.1
BuildRequires:  yq

%description
This package contains Kubernetes images needed to bootstrap an Oracle Cloud Native Environment cluster. Pre-pulling the
images makes startup faster and removes the requirement to have access to a container registry to create a cluster.

%prep
%setup -q -n %{name}-%{version}

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/archives
install -d -m 0755 %{buildroot}/usr/ock/containers
install -d -m 0755 %{buildroot}/etc/ocne/ock/patches
./pull-images.sh v%{kubernetes_version} %{buildroot} /usr/ock/containers %{buildroot}/archives
./pullimages.sh \
	--base "%{buildroot}" \
	--root "/usr/ock/containers" \
	--archive "%{buildroot}/archives" \
	--kube-tag "%{kubernetes_version}" \
	--pause-tag "%{pause}" \
	--etcd-tag "%{etcd}" \
	--coredns-tag "%{coredns}" \
	--flannel-tag "%{flannel}" \
	--ui-tag "%{ui}" \
	--plugins-tag "%{ui_plugins}" \
	--catalog-tag "%{catalog}" \
	--nginx-tag "%{nginx}" \
	--base-image "%{base}"

./fix-images.sh %{buildroot}
rm -rf %{buildroot}/archives
mv %{buildroot}/usr/ock/patches/* %{buildroot}/etc/ocne/ock/patches/

%files
/usr/ock
/etc/ocne/ock

%post
echo "Fixing file and directory ownership"
find /usr/ock/containers -name headlamp | xargs chown -R 100:101

%changelog
* Mon Jul 21 2025 Daniel Krasinski <daniel.krasinski@oracle.com) - 1.31.11-2
- Upgrad to 1.31.11

* Tue Jul 15 2025 Daniel Krasinski <daniel.krasinski@oracle.com) - 1.31.9-2
- Pull in latest images

* Tue Jun 17 2025 Daniel Krasinski <daniel.krasinski@oracle.com> - 1.31.9-1
- Upgrade to 1.31.9

* Mon Apr 07 2025 Daniel Krasinski <daniel.krasinski@oracle.com> - 1.31.6-3
- Use container images that leverage a common base image

* Mon Feb 24 2025 Daniel Krasinski <daniel.krasinski@oracle.com> - 1.31.6-2
- Pick up the latest container images

* Sat Feb 22 2025 Daniel Krasinski <daniel.krasinski@oracle.com> - 1.31.6-1
- Introduce Kubernetes 1.31.6
