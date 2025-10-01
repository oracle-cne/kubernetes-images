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
%global majorminor 1.33
%global patch 5
%global pause 3.10
%global etcd 3.5.23
%global coredns v1.13.1
%global flannel v0.27.3
%global ui_tag v0.35.0
%global ui_plugins v2.0.0
%global catalog v2.0.0
%global nginx 1.24.0
%global base container-registry.oracle.com/olcne/base:latest

%global _buildhost              build-ol%{?oraclelinux}-%{?_arch}.oracle.com
%global app_name                kubernetes-imgs
%global app_version             %{majorminor}.%{patch}
%global oracle_release_version  1
%global kubernetes_version      v%{majorminor}.%{patch}


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
#export REGS=%{registry_url}
export REGS=container-registry.oracle.com/olcne
rm -rf %{buildroot}
install -d -m 0755 %{buildroot}/usr/ock/containers
install -d -m 0755 %{buildroot}/etc/ocne/ock/patches
./pull-images.sh \
	--base "%{buildroot}" \
	--root "/usr/ock/containers" \
	--kube-tag "%{kubernetes_version}" \
	--pause-tag "%{pause}" \
	--etcd-tag "%{etcd}" \
	--coredns-tag "%{coredns}" \
	--flannel-tag "%{flannel}" \
	--ui-tag "%{ui_tag}" \
	--plugins-tag "%{ui_plugins}" \
	--catalog-tag "%{catalog}" \
	--nginx-tag "%{nginx}" \
	--base-image "%{base}"

./fix-images.sh %{buildroot}
mv %{buildroot}/usr/ock/patches/* %{buildroot}/etc/ocne/ock/patches/

%files
/usr/ock
/etc/ocne/ock

%post
echo "Fixing file and directory ownership"
find /usr/ock/containers -name headlamp | xargs chown -R 100:101

%changelog
* Tue Sep 30 2025 Thomas Tanaka <thomas.tanaka@oracle.com> - 1.33.5-1
- Kubernetes 1.33.5
