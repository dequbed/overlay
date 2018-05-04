# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit eutils cmake-utils git-r3

DESCRIPTION="Neovim client library and GUI using Qt5."
HOMEPAGE="https://github.com/equalsraf/neovim-qt/"
EGIT_REPO_URI="https://github.com/equalsraf/neovim-qt.git"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

DEPEND="
		dev-qt/qtcore:5
		dev-qt/qtwidgets:5
		dev-qt/qtnetwork:5
		dev-qt/qttest:5
		app-editors/neovim"
RDEPEND="${DEPEND}"

src_configure() {
	cmake-utils_src_configure
}
