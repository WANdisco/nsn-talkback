#!/bin/bash

###########################################################################
# Script for picking up system information for support
###########################################################################
# Functions

# capture a command
# Param 1: The command to execute
# Param 2: The file to write to
function capture() {
  local command=$1
  local file=$2
  echo "
==========================================================
$command
==========================================================
" >> $file
  eval "$command" >> $file 2>> $file
}

# copy files modified in the last 15 days
# Param 1: the directory to copy from
# Param 2: the directory to copy to
function copyRecent() {
  local source=$1
  local target=$2

  if [[ ! -a $target ]]; then
    mkdir -p $target
  fi
  find $source -type f -mtime -15 -print0 2>/dev/null | xargs -I{} -0 cp --parents -pH "{}" $target >/dev/null 2>&1
}

#check to see if kerberos is running
LINENUMBER=0
function checkKerberos() {
  LINENUMBER=$(grep -n '<name>hadoop.security.authentication</name>' $HADOOP_CONFIG_DIR/configs/core-site.xml | cut -d : -f 1)
  if [[ "$LINENUMBER" -ne 0 ]]; then
    LINENUMBER=$((LINENUMBER+1))
    VALUETAG=$(sed -n ${LINENUMBER}p $HADOOP_CONFIG_DIR/configs/core-site.xml)
    if [[ $VALUETAG == *"kerberos"* ]]; then
      KERBEROS_ENABLED=true
      echo "Kerberos is enabled"
    fi
  fi

  if [[ "$KERBEROS_ENABLED" == "true" ]]; then
    read -p "Kerberos is enabled. Please provide the absolute path to the keytab you wish to use to obtain a ticket: "
    KEYTABLOCATION=$REPLY
    read -p "Please provide the corresponding username for the keytab located ${KEYTABLOCATION}: "
    USERNAME=$REPLY
    echo "Performing kinit as user: " $USERNAME
    kinit -kt $KEYTABLOCATION $USERNAME
  fi
}

function grabHadoopConfigs() {
  # $(hadoop classpath | cut -d : -f 1)
  local hadoopcfg=$HADOOPDIR/etc/hadoop
  HADOOP_CONFIG_DIR=$TMPDIR/hadoop
  mkdir -p $HADOOP_CONFIG_DIR
  if [[ -d $hadoopcfg ]]; then
    cp -pRH $hadoopcfg $HADOOP_CONFIG_DIR/configs
  else
    echo "
    ===================== ERROR ========================
    The talkback agent was unable to locate the hadoop
    config files and so they have not been included. We
    recommend you locate them and include them with the
    final talkback tarball.
    "
  fi
}

function grabHadoopLogs() {
  local logdir=$(. $HADOOP_CONFIG_DIR/configs/hadoop-env.sh; echo $HADOOP_LOG_DIR)
  if [[ -z $logdir ]]; then
    logdir=$HADOOPDIR/logs
  fi
  if [[ -d $logdir ]]; then
    mkdir $HADOOP_CONFIG_DIR/logs
    copyRecent "$logdir" $HADOOP_CONFIG_DIR/logs
  else
    echo "
    ===================== ERROR ========================
    The talkback agent was unable to locate the hadoop
    log files and so they have not been included. We
    recommend you locate them and include them with the
    final talkback tarball.
    "
  fi
}

function grabHiveConfigs() {
  local hivecfg=$HIVEDIR/conf
  HIVE_CONFIG_DIR=$TMPDIR/hive
  mkdir -p $HIVE_CONFIG_DIR
  if [[ -d $hivecfg ]]; then
    cp -pRH $hivecfg $HIVE_CONFIG_DIR/configs
  else
    echo "
    ===================== ERROR ========================
    The talkback agent was unable to locate the hive
    config files and so they have not been included. We
    recommend you locate them and include them with the
    final talkback tarball.
    "
  fi
}

function grabHiveLogs() {
  local hivelogdir=$(cat $HIVE_CONFIG_DIR/configs/hive-log4j.properties | grep "hive\.log\.dir="| sed 's/hive.log.dir=//' | sed 's/${user.name}//')
  local hivelogfile=$(cat $HIVE_CONFIG_DIR/configs/hive-log4j.properties | grep "hive\.log\.file="| sed 's/hive.log.file=//')
  if [[ -d $hivelogdir ]]; then
    mkdir -p $HIVE_CONFIG_DIR/logs
    copyRecent "$hivelogdir -name $hivelogfile" $HIVE_CONFIG_DIR/logs
  else
    echo "
    ===================== ERROR ========================
    The talkback agent was unable to locate the hive
    log files and so they have not been included. We
    recommend you locate them and include them with the
    final talkback tarball.
    "
  fi
}

function usage() {
    cat << EOF
    #######################################################################
    # WANdisco talkback - Script for picking up system & replicator       #
    # information for support                                             #
    #######################################################################

    To run this script non-interactively please set following environment vars:

    NSN_SUPPORT_TICKET          Set ticket number to give to WANdisco support team
    NSN_TALKBACK_DIRECTORY      Set the absolute path directory where the tarball will be saved
    NSN_HADOOP_DIRECTORY        Set the absolute path directory where the hadoop is installed
    NSN_HIVE_DIRECTORY          Set the absolute path directory where the hive is installed
    NSN_PERFORM_FSCK            Set to "true" or "false" to perform a file system
                                consistency check
    NSN_KERBEROS_ENABLED        Set to "true" or "false"
EOF
}

function performFSCK() {
  capture "sudo -u hdfs hadoop --config /etc/hadoop/conf fsck / -blocks -locations -racks -files -openforwrite" $TMPDIR/fsck
}

function askVariableIfRequired() {
  # RETURN-TO-VARIABLE INPUT-VARIABLE MESSAGE DEFAULT-VALUE
  if [[ -z $2 ]]; then
    read -p "$3 [$4] "
    eval "$1=${REPLY:-$4}"
  else
    eval "$1=$2"
  fi
}

usage

echo "
      ===================== INFO ========================
      The talkback agent will capture relevant configuration
      and log files to help WANdisco diagnose the problem
      you may be encountering.
"

TICKET=${NSN_SUPPORT_TICKET:-}

askVariableIfRequired ROOTDIR "$NSN_TALKBACK_DIRECTORY" "Which directory would you like the talkback tarball saved to?" "/tmp"
askVariableIfRequired HADOOPDIR "$NSN_HADOOP_DIRECTORY" "Hadoop directory:" "/opt/nsn/ngdb/hadoop"
askVariableIfRequired HIVEDIR "$NSN_HIVE_DIRECTORY" "Hive directory:" "/opt/nsn/ngdb/hive"

JAVA_HOME=$(echo $JAVA_HOME)
if [[ -z "$JAVA_HOME" ]]; then
    JAVA_HOME="/usr"
fi

HADOOP_EXEC=$HADOOPDIR/bin/hadoop

TALKBACKNAME=talkback-$(date +"%Y%m%d%H%M")-$(uname -n)
TMPDIR="$ROOTDIR/$TALKBACKNAME"
rm -rf $TMPDIR
SYSFILES=$TMPDIR/system
mkdir -p $SYSFILES

# copy system files
cp -pR \
/etc/services \
/etc/inetd.conf \
/etc/xinetd.conf \
/etc/sysctl.conf \
/proc/sys/fs/file-max \
/etc/prefs.conf \
/proc/sys/fs/file-nr \
/etc/security/limits.conf \
$SYSFILES 2>/dev/null

# copy recent system logs
copyRecent "/var/log/sys*" "$SYSFILES/logs"
copyRecent "/var/log/message*" "$SYSFILES/logs"

# retrieve current system state information
echo "Retrieving current system state information"
SYSINFO=$SYSFILES/sys-status
capture "uptime" "$SYSINFO"
capture "pwd" "$SYSINFO"
capture "uname -a" "$SYSINFO"
capture "df -k" "$SYSINFO"
capture "mount" "$SYSINFO"
capture "$JAVA_HOME/bin/java -version" "$SYSINFO"
capture "/bin/bash -version" "$SYSINFO"
OS_TYPE=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
case ${OS_TYPE} in
  centos|redhat|fedora|amazonami)
    capture "rpm -qa | grep coreutil" "$SYSINFO"
    ;;
  ubuntu|debian)
    capture "apt-cache policy coreutils" "$SYSINFO"
    ;;
  *)
    echo "WARNING: Unsupported OS! (${OS_TYPE})"
    ;;
esac
echo "
==========================================================
PATH
==========================================================

  $PATH
" >> $SYSINFO

PROCESSES=$SYSFILES/processes
capture "ps -leaf | grep java" "$PROCESSES"
capture "ps -C java -L -o tid,pcpu,time" "$PROCESSES"
capture "ps -leaf" "$PROCESSES"

capture "top -b -n 1" "$SYSFILES/top"

capture "netstat -an" "$SYSFILES/netstat"

grabHadoopConfigs
grabHadoopLogs

grabHiveConfigs
grabHiveLogs

if [[ -z $KERBEROS_ENABLED ]]; then
  checkKerberos
fi

if [[ -z $NSN_PERFORM_FSCK ]]; then
  # Run hadoop fsck - optional as this can be so large
  echo "Would you like to include hadoop fsck? This can take some time to complete and may drastically increase the size of the tarball."
  select yn in "Yes" "No"; do
      case $yn in
          Yes ) performFSCK; break;;
          No ) break;;
      esac
  done
elif [[ "$NSN_PERFORM_FSCK" == "true" ]]; then
  performFSCK
fi

if [[ "$KERBEROS_ENABLED" == "true" ]]; then
  kdestroy
fi

echo "Running sysinfo script to capture maximum hardware and software information..."
TALKBACKSCRIPTDIR=$( (cd "$(dirname $0)" && pwd) )
"$TALKBACKSCRIPTDIR"/sysinfo.sh "$ROOTDIR"
mkdir -p "$TMPDIR/sysinfo" 2>&1 >/dev/null
mv "$ROOTDIR"/sysinfo/sysinfo*.tar.gz "$TMPDIR/sysinfo" >/dev/null 2>&1
if [[ -n $TICKET ]]; then
  touch $TMPDIR/$TICKET
fi

# tar up the results and delete the temp file
TARBALL=$TMPDIR.tar.gz
tar zcf $TARBALL -C $ROOTDIR $TALKBACKNAME 2>/dev/null
rm -rf $TMPDIR
rm -rf "$ROOTDIR"/sysinfo
echo "
TALKBACK COMPLETE

---------------------------------------------------------------
 Please upload the file:

     $TARBALL

 to WANdisco support with a description of the issue.

 Note: do not email the talkback files, only upload them
 via ftp or attach them via the web ticket user interface.
--------------------------------------------------------------
"
