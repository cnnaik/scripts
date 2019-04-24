#!/usr/bin/env bash
# © Copyright IBM Corporation 2019.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
#
# Instructions:
# Download build script: wget https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/2.4.39/ApacheHttpServer/build_apachehttpserver.sh
# Execute build script: bash build_apachehttpserver.sh    (provide -h for help)

set -e -o pipefail

PACKAGE_NAME="apachehttpserver"
PACKAGE_VERSION="2.4.39"
APR_VERSION="1.6.5"
APR_UTIL_VERSION="1.6.1"
CURDIR="$(pwd)"
BUILD_DIR="/usr/local"

FORCE="false"
LOG_FILE="$CURDIR/logs/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"

trap cleanup 0 1 2 ERR

#Check if directory exsists
if [ ! -d "$CURDIR/logs" ]; then
	mkdir -p "$CURDIR/logs"
fi

# Need handling for RHEL 6.10 as it doesn't have os-release file
if [ -f "/etc/os-release" ]; then
	source "/etc/os-release"
else
	cat /etc/redhat-release >>"${LOG_FILE}"
	export ID="rhel"
	export VERSION_ID="6.x"
	export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
fi

function checkPrequisites() {
	if command -v "sudo" >/dev/null; then
		printf -- 'Sudo : Yes\n' >>"$LOG_FILE"
	else
		printf -- 'Sudo : No \n' >>"$LOG_FILE"
		printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
		exit 1
	fi

	if [[ "$FORCE" == "true" ]]; then
		printf -- 'Force attribute provided hence continuing with install without confirmation message\n' |& tee -a "$LOG_FILE"
	else
		# Ask user for prerequisite installation
		printf -- "\nAs part of the installation , dependencies would be installed/upgraded.\n"
		while true; do
			read -r -p "Do you want to continue (y/n) ? :  " yn
			case $yn in
			[Yy]*)
				printf -- 'User responded with Yes. \n' >>"$LOG_FILE"
				break
				;;
			[Nn]*) exit ;;
			*) echo "Please provide confirmation to proceed." ;;
			esac
		done
	fi
}

function cleanup() {
	printf -- 'No artifacts to be cleaned.\n'
}

function configureAndInstall() {
	printf -- 'Configuration and Installation started \n'

	#Download the source code
	printf -- 'Downloading apachehttpserver and supporting packages \n'
	cd "$CURDIR"
	git clone -b "$PACKAGE_VERSION" https://github.com/apache/httpd.git
	cd "$CURDIR/httpd"

	cd "$CURDIR/httpd/srclib"
	git clone -b "$APR_VERSION" https://github.com/apache/apr.git
	cd "$CURDIR/httpd/srclib/apr"

	cd "$CURDIR/httpd/srclib"
	git clone -b "$APR_UTIL_VERSION" https://github.com/apache/apr-util.git
	cd "$CURDIR/httpd/srclib/apr-util"

	#Building http server
	printf -- 'Building http server \n'
	cd "$CURDIR/httpd"
	./buildconf
	./configure --with-included-apr --prefix=$BUILD_DIR

	#Installation step
	make
	sudo make install

	#Verify apachectl installation
	if command -v "apachectl" >/dev/null; then
		printf -- " %s Installation verified.\n" "$PACKAGE_NAME"
	else
		printf -- "Error while installing %s, exiting with 127 \n" "$PACKAGE_NAME"
		exit 127
	fi
}

function logDetails() {
	printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"

	if [ -f "/etc/os-release" ]; then
		cat "/etc/os-release" >>"$LOG_FILE"
	fi

	cat /proc/version >>"$LOG_FILE"
	printf -- '*********************************************************************************************************\n' >>"$LOG_FILE"

	printf -- "Detected %s \n" "$PRETTY_NAME"
	printf -- "Request details : PACKAGE NAME= %s , VERSION= %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" |& tee -a "$LOG_FILE"
}

# Print the usage message
function printHelp() {
	echo
	echo "Usage: "
	echo "  build_apachehttpserver.sh [-d debug]"
	echo
}

while getopts "h?d" opt; do
	case "$opt" in
	h | \?)
		printHelp
		exit 0
		;;
	d)
		set -x
		;;
	esac
done

function gettingStarted() {

	printf -- "\n\nUsage: \n"
	printf -- "  Apache Http server installed successfully \n"
	printf -- "  More information can be found here : https://github.com/apache/httpd \n"
	printf -- '\n'
}

###############################################################################################################

logDetails
checkPrequisites #Check Prequisites

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04" | "ubuntu-19.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
	sudo apt-get update >/dev/null
	sudo apt-get install -y git python openssl gcc autoconf make libtool-bin libpcre3-dev libxml2 libexpat1 libexpat1-dev wget tar |& tee -a "$LOG_FILE"
	configureAndInstall |& tee -a "$LOG_FILE"
	;;

"rhel-6.x" | "rhel-7.4" | "rhel-7.5" | "rhel-7.6")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
	printf -- 'Installing the dependencies for HTTP server from repository \n' |& tee -a "$LOG_FILE"
	sudo yum install -y git openssl openssl-devel python gcc libtool autoconf make pcre pcre-devel libxml2 libxml2-devel expat-devel which wget tar |& tee -a "$LOG_FILE"
	configureAndInstall |& tee -a "$LOG_FILE"
	;;

"sles-12.4")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
	printf -- 'Installing the dependencies for HTTP server from repository \n' |& tee -a "$LOG_FILE"

	sudo zypper install -y git openssl openssl-devel python gcc libtool autoconf make pcre pcre-devel libxml2 libxml2-devel libexpat-devel which wget tar |& tee -a "$LOG_FILE"
	configureAndInstall |& tee -a "$LOG_FILE"
	;;

"sles-15")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
	printf -- 'Installing the dependencies for HTTP server from repository \n' |& tee -a "$LOG_FILE"
	sudo zypper install -y git openssl libopenssl-devel python gcc libtool autoconf make libpcre1 pcre-devel libxml2-tools libxml2-devel libexpat-devel which wget tar |& tee -a "$LOG_FILE"
	configureAndInstall |& tee -a "$LOG_FILE"
	;;

*)
	printf -- "%s not supported \n" "$DISTRO" |& tee -a "$LOG_FILE"
	exit 1
	;;
esac

gettingStarted |& tee -a "$LOG_FILE"
