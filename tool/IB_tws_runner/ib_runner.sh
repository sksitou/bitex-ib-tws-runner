#!/bin/bash --login
SOURCE="${BASH_SOURCE[0]}"
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $DIR/../../common/setup_env.sh
log "$SOURCE received args: $@"

[ ! -d $HOME/Jts ] && \
	abort "Run $LINUX_SETUP_HOME/init/installTWS.sh in GUI to insall TWS"

# Load config.
account_name=$1
[ -z $account_name ] && abort "Task name should be given."
ibcontroller_script=$DIR/ibcontroller_"$account_name".sh

# If .sh does not exist, create it from template.
PROJ_DIR="$( cd -P "$DIR/../../" && pwd )"
if [[ ! -f $ibcontroller_script ]] || [[ ! -z $2 ]]; then
	log "Create $ibcontroller_script"
	password=$2
	[ -z $password ] && abort "Password should be given for script generating."
	sed -e "s/TWSUSERNAME/$account_name/g" $DIR/ibcontroller_TEMPLATE.sh > $ibcontroller_script
	ibcontroller_ini=$DIR/ibcontroller_"$account_name".ini
	sed -e "s/TWSUSERNAME/$account_name/g" $DIR/ibcontroller_TEMPLATE.ini > $ibcontroller_ini
	sed -i -e "s/TWSPASSWORD/$password/g" $ibcontroller_ini
	linux_username=$( whoami )
	sed -i -e "s/LINUXUSERNAME/$linux_username/g" $ibcontroller_ini
	log $PROJ_DIR
	sed -i -e "s|PROJDIR|$PROJ_DIR|g" $ibcontroller_script

	api_port=$3
	if [[ $api_port =~ ^[0-9]+$ ]]; then
		log "Set API port to $api_port"
		sed -i -e "s/TWSAPIPORT/$api_port/g" $ibcontroller_ini
		sed -i -e "s/TWSACCEPTAPI/accept/g" $ibcontroller_ini
		sed -i -e "s/TWSREADONLY/no/g" $ibcontroller_ini
		sed -i -e "s/TWSBLINDTRADING/yes/g" $ibcontroller_ini
	else
		log "Disable API port"
		sed -i -e "s/TWSAPIPORT//g" $ibcontroller_ini
		sed -i -e "s/TWSACCEPTAPI/reject/g" $ibcontroller_ini
		sed -i -e "s/TWSREADONLY/yes/g" $ibcontroller_ini
		sed -i -e "s/TWSBLINDTRADING/no/g" $ibcontroller_ini
	fi

	if [[ $account_name == trial* || $3 == paper || $4 == paper ]]; then
		log "Set mode to paper trading."
		sed -i -e "s/TWSTRADINGMODE/paper/g" $ibcontroller_ini
	else
		log "Set mode to live trading."
		sed -i -e "s/TWSTRADINGMODE/live/g" $ibcontroller_ini
	fi

	cp -v $ibcontroller_ini $DIR/../../conf/
	chmod u+x $ibcontroller_script
fi

# Check invoking scripts.
[ -f $ibcontroller_script ] || abort "Task script file $ibcontroller_script is not found."
# Search and load INI file.
ini_line=$( cat $ibcontroller_script | grep ^IBC_INI= | sed 's/\r//g' )
log $ini_line
eval $ini_line
log $IBC_INI
[ -z $IBC_INI ] && abort "IBC_INI should be set in $ibcontroller_script"
[ -f $IBC_INI ] || abort "$IBC_INI is not found."
# Search log path, create it.
logpath_line=$( cat $ibcontroller_script | grep ^LOG_PATH= | sed 's/\r//g' )
log $logpath_line
eval $logpath_line
log $LOG_PATH
[ -d $LOG_PATH ] || mkdir -p $LOG_PATH || abort "Failed in creating $LOG_PATH"
# Load IbDir from IBC_INI file
ibdir_line=$( cat $IBC_INI | grep ^IbDir= | sed 's/\r//g' )
log $ibdir_line
eval $ibdir_line
log $IbDir
[ -z $IbDir ] && abort "IbDir should be set in $IBC_INI"
[ -d $IbDir ] || mkdir -p $IbDir || abort "Failed in creating $IbDir"

# Set internal variables
TWS_DIR=$IbDir
mkdir -p $TWS_DIR
ibcontroller_ini=$IBC_INI
output_dir=$DIR/output/$account_name
[ -d $output_dir ] || mkdir -p $output_dir

function period_task {
	log "period_task()"
}

function work_cycle {
	cycle=$1
	log "Work cycle: $cycle"
	cd $DIR
	
	# Get target IBController ini path.
	# If process is not found, start a new one.
	process_num=$( ps aux | grep $ibcontroller_ini | grep -v grep | grep -v IBController.sh | wc -l )
	process_info=$( ps aux | grep $ibcontroller_ini | grep -v grep | grep -v IBController.sh )
	process_pid=$( builtin echo $process_info | awk '{ print $2 }' )
	log_blue "Checking process_num: $process_num $process_info"
	if [ $process_num == '0' ]; then
		log_green "Starting $ibcontroller_script at background."
		$ibcontroller_script &
		while true; do
			process_num=$( ps aux | grep $ibcontroller_ini | grep -v grep | grep -v IBController.sh | wc -l )
			process_info=$( ps aux | grep $ibcontroller_ini | grep -v grep | grep -v IBController.sh )
			process_pid=$( builtin echo $process_info | awk '{ print $2 }' )
			log_blue "Checking process_num: $process_num $process_info"
			log_blue "Process PID $process_pid"
			if [ $process_num == '0' ]; then
				sleep 1
			else
				break
			fi
		done
		log_green "Process appearred"
	else
		log_green "Process already appearred, skip starting TWS."
	fi
	
	tws_user_dir=""
	# Check TWS dir is appearred and unique.
	wait_dir_ct=0
	while true; do
		# Get all TWS dirs with tws.log active in 2 miniutes.
		IFS=$'\n'
		target_dirs=$( find $TWS_DIR/*/tws.log -mmin -2 | awk -F'/tws.log' '{ print $1 }' )
		target_dirs=( $target_dirs )
		target_dir_num=${#target_dirs[@]}
		log "TWS_DIR numbers: $target_dir_num"
		log_blue "Checking dir by *.audit.xml"
		audit_dirs=()
		for dir in ${target_dirs[*]} ; do
			audit_files_num=$( ls $dir | grep -e '\.audit\.xml$' | wc -l )
			log_blue "$audit_files_num found in $dir"
			if [ $audit_files_num != '0' ]; then
				audit_dirs+=($dir)
			fi
		done
		log "audit_dirs: $audit_dirs"
		audit_dir_num=${#audit_dirs[@]}
		log "audit_dir_num: $audit_dir_num"
		if [ $audit_dir_num == 0 ]; then
			if [ $wait_dir_ct -gt 3 ]; then
				log_red "Wait too long, kill process: $process_info"
				log_red "Process PID $process_pid"
				kill $process_pid
				return
			else
				log_red "Audit dir not appearred, wait 30 seconds and retry #$wait_dir_ct."
				wait_dir_ct=$((wait_dir_ct+1))
				sleep 30
			fi
		elif [ $audit_dir_num == 1 ]; then
			tws_user_dir=${audit_dirs[0]}
			log_green "Audit dir is unique: $tws_user_dir"
			break
		else
			log_red "Multiple audit dirs appearred, at lease one dir should be purged"
			log_red "Will exit after 60 seconds."
			sleep 60
			exit 1
		fi
	done

	if [[ $cycle != '0' ]]; then
		log_green "TWS started for cycle: $cycle"
		datetime=$( date +"%Y%m%d_%H%M%S_%N" )
		logfile=$DIR/logs/$datetime.log
		log_green "TWS started for cycle: $cycle" >> $logfile
	fi
	
	log "Invoke period task at very first time."
	period_task
	log "Invoke period task every hour, Waiting until TWS terminated."
	while true; do
		process_num=$( ps aux | grep $ibcontroller_ini | grep -v grep | grep -v IBController.sh | wc -l )
		[ $process_num == '0' ] && break
		# Scan every 10 seconds
		sleep 10
	
		datetime=$( date +"%Y%m%d_%H%M%S_%N" )
		yesterdat_date=$( date --date="-1 day" +"%Y%m%d" )
		if [[ $datetime == *_12100?_* || $datetime == *_23300?_* ]]; then
			# Everyday 12:10:0X 23:30:0X , kill TWS
			log "Daily routine : kill TWS"
			ps aux | grep $ibcontroller_ini | grep -v grep | grep -v IBController.sh | awk '{ print $2 }' | xargs kill
			# In case of killing failed.
			sleep 60
			log "Daily routine : kill -9 TWS"
			ps aux | grep $ibcontroller_ini | grep -v grep | grep -v IBController.sh | awk '{ print $2 }' | xargs kill -9
			sleep 10
		fi
	done
	
	log_red "TWS terminated"
	datetime=$( date +"%Y%m%d_%H%M%S_%N" )
	logfile=$DIR/logs/$datetime.log
	log_red "TWS terminated at $datetime" >> $logfile
	# sleep 5
}

cycle=0
while true; do
	work_cycle $cycle
	sleep 10
	cycle=$(( cycle + 1 ))
done
