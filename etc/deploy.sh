#!/bin/sh
set -eu

deploy() {
	local ENVFILE=$(readlink -f $(dirname $0)/../.env)
	if [ ! -e $ENVFILE ]; then
		echo "! no environment file, $ENVFILE" && false
	fi

	$(cat $ENVFILE | awk '{print "local", $0;}')

	local HOMEROOT=$LOCATION/home
	local TMPROOT=$LOCATION/tmp

	local IGNORES='.git .DS_Store .dotapps'
	local IGNORES_OPTION=$(echo "$IGNORES" | tr ' ' '\n' | awk '{printf " -not -name %s", $0;}')

	local SECRETS='.ssh .ssh/id_rsa .ssh/authorized_keys .ssh/config'

	local DEFAULTENV="default/$OSNAME/$OSSHELL"

	for repoenv in $(echo $REPOSITORIES | tr ',' '\n'); do
		local repo=$(echo $repoenv | awk -F':' '{print $1;}')
		local reponame=$(echo $repo | awk -F'/' '{printf "%s@%s", $2, $1;}')
		local repopath=$LOCATION/home/$reponame

		local env=$(echo $repoenv | awk -F':' '{print $2;}')

		local environments=$(find $repopath -mindepth 1 -maxdepth 1 -type d $IGNORES_OPTION | awk -F'/' '{print $NF;}')
		if [ -z "$environments" ]; then
			echo "! no environments, $repo"
			continue
		fi

		cat <<- EOF
		┏
		┃ $repo
		┃ 
		┃ environments:
		$(echo "$environments" | awk '{print "┃     ", $0}')
		┗
		EOF

		printf "? environments (${env:=$DEFAULTENV}) " && read inputenvs
		inputenvs=$(echo ${inputenvs:-$env} | sed -e 's/[\/,]/ /g')

		for inputenv in $inputenvs; do
			local userhome=$repopath/$inputenv
			if [ ! -e $userhome ]; then
				echo "! no environment, $userhome"
				continue
			fi

			echo "! environment, $inputenv"

			local usertmp=$TMPROOT/$reponame/$inputenv
			rm -rf $usertmp
			mkdir -p $usertmp

			local targets=$(find $userhome -mindepth 1 -maxdepth 1 $IGNORES_OPTION | awk -F'/' '{print $NF}')
			for t in $targets; do
				echo "~ symbolic link $t -> $HOME/$t"
				[ -e $HOME/$t ] && mv -f $HOME/$t $usertmp/$t
				ln -fns $(readlink -f $userhome/$t) $HOME/$t
			done

			for s in $SECRETS; do
				if [ -d $userhome/$s ]; then
					echo "@ secret directory, $s"
					chmod 700 $userhome/$s
				elif [ -f $userhome/$s ]; then
					echo "@ secret file, $s"
					chmod 600 $userhome/$s
				fi
			done
		done

		local src="($(printf "$repo" | sed -E 's/\//\\\//g'))([^,]*)*(,|$)"
		local dst="\\1:$(printf "$inputenvs" | sed -E 's/ /\\\//g')\\3"
		sed -i -E "s/$src/$dst/" $ENVFILE 2> /dev/null || sed -i '' -E "s/$src/$dst/" $ENVFILE

		local scriptroot=$repopath/.dotapps
		if [ ! -e $scriptroot ]; then
			echo "! no scripts, $scriptroot"
			continue
		fi

		echo "! scripts, $scriptroot"

		for script in $(find $scriptroot -type f -name '*.sh' | awk -F'/' '{print NF, $0}' | sort -n | awk '{print $2}'); do
			echo "$ script, $script"
			env $(cat $ENVFILE | tr '\n' ' ') sh -eu $script
		done
	done
}

deploy $@
