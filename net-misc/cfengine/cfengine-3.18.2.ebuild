# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit eutils autotools flag-o-matic

MY_PV="${PV//_beta/b}"
MY_PV="${MY_PV/_p/p}"
MY_P="${PN}-${MY_PV}"

DESCRIPTION="An automated suite of programs for configuring and maintaining computers"
HOMEPAGE="http://www.cfengine.org/"
SRC_URI="https://cfengine-package-repos.s3.amazonaws.com/tarballs/${MY_P}.tar.gz -> ${MY_P}.tar.gz
	masterfiles? ( https://cfengine-package-repos.s3.amazonaws.com/tarballs/${PN}-masterfiles-${MY_PV}.tar.gz -> ${PN}-masterfiles-${MY_PV}.tar.gz )"

LICENSE="GPL-3"
SLOT="3"
KEYWORDS="~amd64 ~x86"

IUSE="acl examples libvirt +lmdb mysql masterfiles pam postgres qdbm selinux systemd tokyocabinet vim-syntax xml +yaml"

DEPEND="acl? ( virtual/acl )
	libvirt? ( app-emulation/libvirt )
	lmdb? ( dev-db/lmdb )
	mysql? ( virtual/mysql )
	postgres? ( dev-db/postgresql:= )
	qdbm? ( dev-db/qdbm )
	selinux? ( sys-libs/libselinux )
	tokyocabinet? ( dev-db/tokyocabinet )
	xml? ( dev-libs/libxml2:2 )
	yaml? ( dev-libs/libyaml ) \
	dev-libs/openssl
	dev-libs/libpcre"
RDEPEND="${DEPEND}"
PDEPEND="vim-syntax? ( app-vim/cfengine-syntax )"

REQUIRED_USE="^^ ( lmdb qdbm tokyocabinet )"

S="${WORKDIR}/${MY_P}"

src_prepare() {
	default
	eautoreconf
}

src_unpack() {
	unpack ${MY_P}.tar.gz
	if use masterfiles; then
		unpack ${PN}-masterfiles-${MY_PV}.tar.gz
	fi
}

src_configure() {
	# Enforce /var/cfengine for historical compatibility

	econf \
		--enable-fhs \
		--docdir=/usr/share/doc/${PF} \
		--with-workdir=/var/cfengine \
		--with-pcre \
		--with-openssl \
		$(use_with acl libacl) \
		$(use_with libvirt) \
		$(use_with lmdb) \
		$(use_with mysql mysql check) \
		$(use_with pam) \
		$(use_with postgres postgresql) \
		$(use_with qdbm) \
		$(use_with systemd systemd-socket) \
		$(use_with tokyocabinet) \
		$(use_with xml libxml2) \
		$(use_with yaml libyaml) \
		$(use_enable selinux)

	# Fix Makefile to skip inputs, see below "examples"
	#sed -i -e 's/\(SUBDIRS.*\) inputs/\1/' Makefile || die

	# We install the documentation through portage
	sed -i -e 's/\(install-data-am.*\) install-docDATA/\1/' Makefile || die
}

src_install() {
	# The CFEngine build process generates systemd service files automatically
	# so there is no equivalent to the below in that case.
	if ! use systemd ; then
		newinitd "${FILESDIR}"/cf-serverd.rc6 cf-serverd || die
		newinitd "${FILESDIR}"/cf-monitord.rc6 cf-monitord || die
		newinitd "${FILESDIR}"/cf-execd.rc6 cf-execd || die
	fi

	emake DESTDIR="${D}" install || die

	dodoc AUTHORS

	if ! use examples; then
		rm -rf "${D}"/usr/share/doc/${PF}/example*
	fi

	# Create cfengine working directory
	dodir /var/cfengine/bin
	fperms 700 /var/cfengine
	fperms 700 /var/cfengine/ppkeys

	# Copy cfagent into the cfengine tree otherwise cfexecd won't
	# find it. Most hosts cache their copy of the cfengine
	# binaries here. This is the default search location for the
	# binaries.
	# CFEngine binaries can be used by normal users as well, sym them into
	# /usr/bin instead
	for bin in promises agent monitord serverd execd runagent key; do
		dosym ../../../usr/bin/cf-$bin var/cfengine/bin/cf-$bin || die
	done

	if use masterfiles; then
		insinto /var/cfengine
		doins -r "${WORKDIR}/masterfiles"
	fi

	for dir in inputs modules outputs plugins ppkeys state; do
		keepdir /var/cfengine/$dir
	done

	dodir /etc/env.d
	echo 'CONFIG_PROTECT=/var/cfengine/masterfiles' >"${ED}/etc/env.d/99${PN}" || die
}

pkg_postinst() {
	if use systemd ; then
		einfo "Separate service files for each component of CFEngine are provided."
		einfo
		einfo "A meta service called 'cfengine3.service' is installed that will"
		einfo "start all components as configured."
	else
		einfo "Init scripts for cf-serverd, cf-monitord, and cf-execd are provided."
		einfo
		einfo "If you don't want to use the init scripts, you can run cfengine using cron:"
		einfo "0,30 * * * *    /usr/bin/cf-execd -O"
	fi
	echo

	elog "If you run cfengine the very first time, you MUST generate the keys for cfengine by running:"
	elog "emerge --config ${CATEGORY}/${PN}"
}

pkg_config() {
	if [ "${ROOT}" == "/" ]; then
		if [ ! -f "/var/cfengine/ppkeys/localhost.priv" ]; then
			einfo "Generating keys for localhost."
			/usr/bin/cf-key
		fi
	else
		die "cfengine cfkey does not support any value of ROOT other than /."
	fi
}
