#!/bin/sh
set -eu

install () {
	local GITSERVICES='git@github.com: https://github.com/'

	local OSNAME=
	local OSDIST=
	local OSVERSION=
	local OSARCH=$(uname -m)
	local OSSHELL=
	local LOCATION=~/.dotapps
	local REPOSITORIES=dotfiles

	local ENVFILE=.env
	if [ ! -e "$ENVFILE" ]; then
		ENVFILE=$(dirname $0)/../.env
	fi
	if [ -e "$ENVFILE" ]; then
		eval $(cat $ENVFILE | awk -F'=' '$2 ~ /^[^# ]/ {print;}')
	fi

	case $(uname) in
	# macOS
	Darwin)
		OSNAME=macos
		OSVERSION=$(sw_vers -productVersion)
		;;
	# Linux
	Linux)
		OSNAME=linux
		if [ -f /etc/redhat-release ]; then
			case "$(cat /etc/redhat-release | cut -d' ' -f1)" in
			# CentOS
			CentOS)
				OSDIST=centos
				OSVERSION=$(cat /etc/redhat-release | awk '{ print $4 }')
				;;
			# AlmaLinux
			AlmaLinux)
				OSDIST=almalinux
				OSVERSION=$(cat /etc/redhat-release | awk '{ print $3 }')
				;;
			esac
		elif [ -f /etc/os-release ]; then
			case "$(cat /etc/os-release | awk -F'=' '$1 == "NAME" {gsub(/"/, "", $2); print $2;}')" in
			# Debian
			# * Raspberry Pi OS
			'Debian GNU/Linux')
				OSDIST=debian
				;;
			# Ubuntu
			Ubuntu)
				OSDIST=ubuntu
				;;
			# AmazonLinux
			AmazonLinux)
				OSDIST=amazonlinux
				;;
			esac

			OSVERSION=$(cat /etc/os-release | awk -F'=' '$1 == "VERSION_ID" {gsub(/"/, "", $2); print $2;}')
		fi
		;;
	*)
	esac

	cat <<- EOF

	 ▓█████▄  ▒█████  ▄▄▄█████▓ ▄▄▄       ██▓███   ██▓███    ██████ 
	 ▒██▀ ██▌▒██▒  ██▒▓  ██▒ ▓▒▒████▄    ▓██░  ██▒▓██░  ██▒▒██    ▒ 
	 ░██   █▌▒██░  ██▒▒ ▓██░ ▒░▒██  ▀█▄  ▓██░ ██▓▒▓██░ ██▓▒░ ▓██▄   
	 ░▓█▄   ▌▒██   ██░░ ▓██▓ ░ ░██▄▄▄▄██ ▒██▄█▓▒ ▒▒██▄█▓▒ ▒  ▒   ██▒
	 ░▒████▓ ░ ████▓▒░  ▒██▒ ░  ▓█   ▓██▒▒██▒ ░  ░▒██▒ ░  ░▒██████▒▒
	  ▒▒▓  ▒ ░ ▒░▒░▒░   ▒ ░░    ▒▒   ▓▒█░▒▓▒░ ░  ░▒▓▒░ ░  ░▒ ▒▓▒ ▒ ░
	  ░ ▒  ▒   ░ ▒ ▒░     ░      ▒   ▒▒ ░░▒ ░     ░▒ ░     ░ ░▒  ░ ░
	  ░ ░  ░ ░ ░ ░ ▒    ░        ░   ▒   ░░       ░░       ░  ░  ░  
	    ░        ░ ░                 ░  ░                        ░  
	  ░                                                             
	
	EOF

	local usershell=$(echo $SHELL | xargs basename)
	if [ "$usershell" != "$OSSHELL" ]; then
		local yn=y
		if [ -n "$OSSHELL" ]; then
			printf "? use $usershell (y/N) " && read yn
		fi
		[ "$yn" = 'y' ] && OSSHELL=$usershell
	fi

	printf "? location ($LOCATION) " && read location
	: ${location:=$LOCATION}

	printf "? repositories ($REPOSITORIES) " && read repositories
	repositories=$(printf "${repositories:-$REPOSITORIES}" | awk -F':' -v 'RS=,' '
		{r = $1; e = $2;}
		r !~ /\// {printf "'$(whoami)'/";}
		{printf r;}
		e != "" {printf ":%s",e;}
		{printf "\n";}
	' | paste -s -d, -)

	cat <<- EOF
	┏
	┃ OS           $OSNAME
	┃ Distribution $OSDIST
	┃ Version      $OSVERSION
	┃ Architecture $OSARCH
	┃ Shell        $OSSHELL
	┃ 
	┃ Location     $location
	┃ Repositories $repositories
	┗
	EOF

	if [ -z "$OSNAME" ] || [ -z "$OSVERSION" ] || [ -z "$OSARCH" ]; then
		echo "! unsupported system, $(uname -a)" && false
	fi

	if ! type git > /dev/null || ! type make > /dev/null; then
		printf '? git and make commands are required. install now [y/N] ' && read yn
		[ "$yn" != 'y' ] && false

		case "$OSNAME" in
		macos)
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
			brew update
			brew install git
			;;
		linux)
			case "$OSDIST" in
			centos|amazonlinux)
				sudo yum install -y git make
				;;
			ubuntu)
				sudo apt update
				sudo apt install -y git make
				;;
			almalinux)
				sudo dnf install -y git make
				;;
			*)
				echo "! unsupported system, $(uname -a)" && false
			esac
			;;
		*)
			echo "! unsupported system, $(uname -a)" && false
			;;
		esac
	fi

	printf '? start [y/N] ' && read yn
	[ "$yn" != 'y' ] && false

	if [ ! -e $location ]; then
		git clone https://github.com/kaduhiro/dotapps $location
	fi

	for repo in $(echo $repositories | tr ',' '\n' | awk -F':' '{print $1;}'); do
		local reponame=$(echo $repo | awk -F'/' '{printf "%s@%s", $2, $1;}')
		local repopath=$location/home/$reponame
		if [ ! -d $repopath ]; then
			umask 0022

			echo "! fetch repository, $repopath"
			mkdir -p $(dirname $repopath)

			for service in $GITSERVICES; do
				if git clone "$service$repo" "$repopath"; then
					break
				fi
			done

			if [ ! -d $repopath ]; then
				echo "! no repository, $repo" && false
			fi

			umask 0002
		fi
	done

	cat <<- EOF > $location/.env
	OSNAME=$OSNAME
	OSDIST=$OSDIST
	OSVERSION=$OSVERSION
	OSARCH=$OSARCH
	OSSHELL=$OSSHELL
	LOCATION=$location
	REPOSITORIES=$repositories
	EOF

	sh $location/etc/deploy.sh
}

install $@
