# Check and set environment before every scripts. Golbal vars should be not affect others.
ARGS="$@"

__SOURCE="${BASH_SOURCE[0]}"
export BTX_MAIN_COMMON="$( cd -P "$( dirname "$__SOURCE" )" && pwd )"
export BTX_MAIN_HOME="$( cd -P "$( dirname "$__SOURCE" )" && cd .. && pwd )"

USER_ARCHIVED="$HOME/archived"

#############################################
# Load linux tool chains. 
#############################################
export LINUX_SETUP_HOME="$BTX_MAIN_HOME/../linux-setup"
_linux_bootstrap="$LINUX_SETUP_HOME/common/bootstrap.sh"
if [ -d $LINUX_SETUP_HOME ]; then
	source $_linux_bootstrap
	# Try to pull latest version if no diff exists.
	_diff=$( cd $LINUX_SETUP_HOME && git diff )
	log "checking updates of linux-setup"
	[[ -z $_diff ]] && ( cd $LINUX_SETUP_HOME && status_exec git pull ) || \
		log_blue "git diff exists inside $LINUX_SETUP_HOME"
else
	echo "Cloning linux-setup repo..."
	cd $USER_ARCHIVED
	rm -rf $USER_ARCHIVED/linux-setup
	git clone "git@github.com:celon/linux-setup.git" || \
		git clone "https://github.com/celon/linux-setup.git" || \
		abort "Failed to clone linux-setup"
	mv $USER_ARCHIVED/linux-setup $LINUX_SETUP_HOME || \
		abort "Failed to mv linux-setup to $LINUX_SETUP_HOME"
	source $_linux_bootstrap
fi
[ ! -f $_linux_bootstrap ] && echo "File $_linux_bootstrap is not exist." && exit -1
export LINUX_SETUP_HOME=$( absolute_path $LINUX_SETUP_HOME)
log "linux-setup: $LINUX_SETUP_HOME"


#############################################
log "-------- Setting up bash functions --------"
#############################################

# Load ENV variables.
_conf="$BTX_MAIN_HOME/conf/env.sh"
[ -f $_conf ] && source $_conf || log_red "No conf $_conf"

# Useful variables.
datetime=$( date +"%Y%m%d_%H%M%S_%N" )
datestr=$( date +"%Y%m%d" )
datestr_underline=$( date +"%Y_%m_%d" )


if [[ $ARGS != *NOJAVA* && $BTX_JAVA_ENV != 'OK' ]]; then
	log "Checking Java"
	find_path "java" || $LINUX_SETUP_HOME/init/initEnv.sh
	assert_path "java"
	#assert_path "ant"
	BTX_JAVA_ENV='OK'
fi

[ ! -d $HOME/Jts ] && \
	log_red "Run $LINUX_SETUP_HOME/init/installTWS.sh in GUI to insall TWS"

# Goto DIR
[[ ! -z $DIR ]] && echo "cd $DIR" && cd $DIR

