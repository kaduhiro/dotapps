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

	local IGNORES='.git .DS_Store .history .dotapps'
	local IGNORES_OPTION=$(echo "$IGNORES" | tr ' ' '\n' | awk '{printf " -not -name %s", $0;}')

	local SECRETS='.ssh .ssh/config .ssh/authorized_keys .ssh/id_rsa .ssh/id_ed25519'

	local DEFAULTENV="default/$OSNAME/$OSSHELL"

	for repoenv in $(echo $REPOSITORIES | tr ',' '\n'); do
		local repo=$(echo $repoenv | awk -F':' '{print $1;}')
		local reponame=$(echo $repo | awk -F'/' '{printf "%s@%s", $2, $1;}')
		local repopath=$LOCATION/home/$reponame

		update_repository "$repo" "$repopath"

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
			echo "! environment, $inputenv"

			case $inputenv in
			bash|zsh)
				echo "! change shell to $inputenv"
				cat $ENVFILE | sed -E "s/^(OSSHELL=).+$/\1$inputenv/g" | tee $ENVFILE > /dev/null
				;;
			esac
	
			local userhome=$repopath/$inputenv
			if [ ! -e $userhome ]; then
				echo "! no environment, $userhome"
				continue
			fi

			local usertmp=$TMPROOT/$reponame/$inputenv
			rm -rf $usertmp
			mkdir -p $usertmp

			local targets=$(find $userhome -mindepth 1 -maxdepth 1 $IGNORES_OPTION | awk -F'/' '{print $NF}')
			for t in $targets; do
				link_target "$userhome/$t" "$HOME/$t" "$usertmp" "$IGNORES_OPTION" "$t"
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
		cat $ENVFILE | sed -E "s/$src/$dst/" | tee $ENVFILE > /dev/null

		local scriptroot=$repopath/.dotapps
		if [ ! -e $scriptroot ]; then
			echo "! no scripts, $scriptroot"
			continue
		fi

		echo "! scripts, $scriptroot"

		set +e
		for script in $(find $scriptroot -type f -name '*.sh' | awk -F'/' '{print NF, $0}' | sort -n | awk '{print $2}'); do
			env $(cat $ENVFILE | tr '\n' ' ') sh -eu $script
			[ $? -eq 0 ] && echo "✅ $script" || echo "✔️  $script"
		done
		set -e
	done
}

update_repository() {
	local repo=$1
	local repopath=$2

	if [ ! -d "$repopath/.git" ]; then
		echo "! no git repository, $repopath"
		false
	fi

	echo "! update repository, $repo"

	local branch
	branch=$(git -C "$repopath" symbolic-ref --quiet --short HEAD)

	git -C "$repopath" fetch --prune origin
	git -C "$repopath" merge --ff-only "origin/$branch"
}

link_target() {
	local src=$1
	local dst=$2
	local tmproot=$3
	local ignores_option=$4
	local label=$5

	if [ -d "$src" ] && [ -d "$dst" ] && [ ! -L "$dst" ]; then
		echo "~ merge directory $label -> $dst"

		local children=$(find "$src" -mindepth 1 -maxdepth 1 $ignores_option | awk -F'/' '{print $NF}')
		for child in $children; do
			link_target "$src/$child" "$dst/$child" "$tmproot" "$ignores_option" "$label/$child"
		done

		return
	fi

	echo "~ symbolic link $label -> $dst"
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		mkdir -p "$tmproot/$(dirname "$label")"
		mv -f "$dst" "$tmproot/$label"
	fi
	ln -fns "$(readlink -f "$src")" "$dst"
}

deploy $@
