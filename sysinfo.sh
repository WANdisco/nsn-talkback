#!/bin/bash

############################################################################
#
# sysinfo - Extended system information tool for use with WD Talkback
#
# Copyright (C) WANdisco
#
# Author: WANdisco
#
# This program is not at all free software; you certainly can not redistribute it 
# and/or modify it under any terms. 
#
############################################################################

PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
WD_EXTENDED_INFO=${WD_EXTENDED_INFO:-}

function error() {
    echo "$1"
    exit $2
}

#Make sure root runs this script
if [ $EUID -ne 0 ]; then
    error "Please run talkback as root/superuser to get full system diagnostic information." 1
fi

ROOTDIR=$1
HNM="${HOSTNAME:-$(hostname)}"
WORKING_DIR="$ROOTDIR/sysinfo/$HNM"
#make a directory to place files
rm -rf "$WORKING_DIR" "$ROOTDIR/tmp/sysinfo/"
mkdir -p "$WORKING_DIR"
cd "$WORKING_DIR"
NOW=$(date +%Y%m%d-%H%M%S)
TAR="sysinfo_$HNM-$NOW.tar.gz"
TARBALL=${WD_TARBALL:-$TAR}
TARBALL="sysinfo/$TARBALL"
TEMP_TEXT="$WORKING_DIR/temptxt"
unset REPORT_FILE

#start writing each section
start_sec(){
	echo "Gathering $1 info...."
	REPORT_FILE="$WORKING_DIR/$1.txt"
	echo "$1 Information" >> "$REPORT_FILE"
	echo "**************************************************" >> "$REPORT_FILE"
	echo "" > "$TEMP_TEXT"
}

#close a section
end_sec(){
	if [ -n "$REPORT_FILE" ]; then 
		cat "$TEMP_TEXT" >> "$REPORT_FILE"
		echo "" > "$TEMP_TEXT"
	fi
}

#create a break and heading inside a section
sub_header() {
	printf "\n\n*-*-*-*-*-*-*-*-*-*-%s-*-*-*-*-*-*-*-*-*-*\n\n" "$1" >> "$TEMP_TEXT"
}

#put output from a command into temp text file for writing later
#usage:
#output_text "full_path_of_command" "args"
output_text(){
	if ! [ -x "$1" ]; then
		return 1
	fi
	args=("$@") 
	"${args[@]}" >> "$TEMP_TEXT" 2>&1
}

#report_command for parsing commands
#usage:
#report_command  "full_path_of_command" "sub_section_name" "args"
report_command() {
if [ -x "$1" ]; then
	echo "------------$2------------" >> "$TEMP_TEXT"
	command=$1
	shift
	shift
	args=("$@")
	echo "===\"$command ${args[@]}\"===" >> "$TEMP_TEXT"
	output_text "$command" "${args[@]}"
fi
}

#cat a file into temp text file
#usage:
#cat_file "filename_to_cat" "header(if required - use filename if not)"
cat_file() {
        if [ -e "$1" ]; then
        cat_title="$2"
        test -z "$cat_title" && cat_title=$1
                echo "------------$2------------" >> "$TEMP_TEXT"
                echo "===\"cat $1\"===" >> "$TEMP_TEXT"
                output_text "/bin/cat" "$1"
        fi
}

#Start the summary section
start_sec Summary
PLATFORM=$(uname -m)
report_command "/bin/uname" "Platform" "-m"

if [ "$PLATFORM" = "x86_64"  ] ; then
        report_command "/usr/sbin/dmidecode" "System-Type" #"|grep Product|head -1" 
fi
cat_file "/etc/redhat-release" "rhel-release info"
cat_file "/etc/SuSE-release" "SuSE-release info"
report_command "/bin/uname" "Kernel-version" "-r"
cat_file "/proc/version" "/proc/version"
report_command "/sbin/runlevel" "runlevel"
cat_file "/etc/lsb-release" "lsb-release"
cat_file "/etc/issue" "/etc/issue"
report_command "/bin/hostname" "/bin/hostname"
report_command "/bin/date" "/bin/date"
end_sec

#Start Kernel Section
start_sec Kernel
report_command "/bin/uname" "/bin/uname -a" "-a"
cat_file "/proc/version"
cat_file "/proc/sys/kernel/tainted"
cat_file "/boot/efi/efi/redhat/elilo.conf"
cat_file "/boot/efi/efi/SuSE/elilo.conf"
cat_file "/etc/lilo.conf"
cat_file "/etc/elilo.conf"
cat_file "/boot/grub/device.map"
cat_file "/boot/grub/grub.conf"
cat_file "/boot/grub/menu.lst"
cat_file "/etc/grub.conf"
cat_file "/proc/cmdline"
report_command "/lib/modules/$(uname -r)/modules.dep" "lib modules" "modules.dep" "cat"
report_command "/bin/rpm" "Kernels installed" "-qa" "'*kernel*'"
cat_file "/etc/modules"
cat_file "/etc/modules.conf"
cat_file "/etc/modprobe.conf"
cat_file "/etc/modprobe.conf.local"
cat_file "/etc/modprobe.d/arch/ia64"
cat_file "/etc/sysctl.conf"
report_command "/sbin/sysctl" "Configured-Kernel-Params" "-a"
report_command "/bin/ls" "ls -ltRL /boot" "-ltRL" "/boot"
if [ -n "$WD_EXTENDED_INFO" ]; then
	cat_file "/proc/ksyms"
	cat_file "/proc/kallsyms"
	cat_file "/boot/System.map"
	cat_file "/boot/System.map-$(uname -r)"
fi

sub_header "Dumputils-LKCD"
cat_file "/etc/default/hpde-support"
cat_file "/etc/default/kdump-tools"
cat_file "/proc/sys/kernel/sysrq"
cat_file "/proc/sys/kernel/kdb"
cat_file "/proc/diskdump"
cat_file "/etc/sysconfig/dump"
cat_file "/etc/sysconfig/netdump"
cat_file "/etc/sysconfig/netdump_id_dsa"
cat_file "/etc/sysconfig/netdump_id_dsa.pub"
cat_file "/etc/sysconfig/diskdump"
cat_file "/etc/dumputils.conf"
cat_file "/etc/dump"
if [ -d /var/crash ]
then
        report_command "/bin/ls" "ls -ltRL /var/crash" "-ltRL" "/var/crash"
fi
if [ -d /proc/sys/dump ]; then
        for  f in $(find /proc/sys/dump/ -type f)
        do
                cat_file "$f"
        done
fi
if [ -e /dev/vmdump ]; then
        report_command "/bin/ls" "Dump device information" "-l" "/dev/vmdump"
fi
if [ -d /var/log/dump ]; then
        report_command "/bin/ls" "ls -ltRL /var/log/dump" "-ltRL" "/var/log/dump"
fi
if [ -d /var/log/hpde-support-dumpdata ]; then
        report_command "/bin/ls" "hpde-support-dumpdata" "-ltRL" "/var/log/hpde-support-dumpdata"
fi

report_command "/sbin/lsmod" "Loaded Modules" " "

sub_header "Modinfo"
for i in $(/sbin/lsmod|grep -v Module|awk '{print $1}'|grep -v bond)
do
        report_command "/sbin/modinfo" "modinfo of $i" "$i"
done
if [ "$(/sbin/lsmod|grep bond|awk '{print $1}'|head -1)" ]; then
        report_command "/sbin/modinfo" "bonding" "bonding" 
fi
end_sec

#Start Hardware section
start_sec Hardware

report_command "/sbin/hwclock" "/sbin/hwclock"
cat_file "/proc/cpuinfo"
cat_file "/proc/meminfo"
cat_file "/proc/iomem" "/proc/iomem"

#if lspci is available use it if not try for on /proc/pci
if [ -e /sbin/lspci ]; then
	report_command "/sbin/lspci" "PCI-Devices" "-v"
else
	cat_file "/proc/pci"
fi

cat_file "/proc/ioports"
cat_file "/proc/interrupts"
cat_file "/proc/dma"
report_command "/sbin/lsusb" "lsusb" " "
cat_file "/proc/scsi/device_info"
cat_file "/proc/scsi/scsi"
cat_file "/proc/devices"

sub_header "IDE-Devices"
if [ -d /proc/ide ]; then
for i in "$(ls /proc/ide | grep hd)"
  do
        cat_file "/proc/ide/$i/model"
  done
fi

sub_header "Extra Info"
report_command "/usr/sbin/dmidecode" "Dmidecode"
if [ -f /etc/redhat-release ] ; then
	release=$(cat /etc/redhat-release| awk '{print $7}')
	if [ "$release" == "4" ] ; then
		report_command "/usr/bin/lshal" "lshal"
	else
		report_command "/usr/bin/lshal" "lshal -l" "-l"
	fi
fi
report_command "systool" "systool" "-c" "fc_host" "-v"
if [ -d /proc/scsi/lpfc ] ; then
  start_submain "/proc/scsi/lpfc"
for i in $(ls /proc/scsi/lpfc)
  do
        cat_file "/proc/scsi/lpfc/$i"
  done
  end_submain
fi
if [ -d /proc/scsi/lpfcmpl ] ; then
  start_submain "/proc/scsi/lpfcmpl"
for i in $(ls /proc/scsi/lpfcmpl)
  do
        cat_file "/proc/scsi/lpfcmpl/$i"
  done
  end_submain
fi

#extra SuSe info if we support it in future...
if [ -f /etc/SuSE-release ] ; then
        release=$(cat /etc/SuSE-release| awk '{print $5}')
        if [ "$release" == "9" ] ; then
                report_command "/usr/bin/lshal" "lshal"
        else
                report_command "/usr/bin/lshal" "lshal" "-l"
        fi
fi
end_sec

#Start FileSystems section
start_sec File-Systems
cat_file "/proc/partitions"
report_command "fdisk" "fdisk -l" "-l"
cat_file "/etc/fstab"
report_command "/bin/mount" "/bin/mount"
report_command "/sbin/swapon" "Swap-Information" "-s"
report_command "/bin/df" "Disk-Free" "-hTal"
cat_file "/etc/exports"
cat_file "/proc/lvm/global/"
report_command "/usr/sbin/pvdisplay" "pvdisplay -v" "-v"
report_command "/sbin/pvdisplay" "pvdisplay -v" "-v"
report_command "/usr/sbin/vgdisplay" "vgdisplay -v" "-v"
report_command "/sbin/vgdisplay" "vgdisplay -v" "-v"
report_command "/usr/sbin/lvdisplay" "lvdisplay -v" "-v"
report_command "/sbin/lvdisplay" "lvdisplay -v" "-v"
cat_file "/etc/mdadm.conf"
cat_file "/proc/mdstat"
cat_file "/etc/raidtab"
end_sec

#Start Network section
start_sec Network
cat_file "/etc/host.conf"
cat_file "/etc/hosts"
cat_file "/etc/hosts.allow"
cat_file "/etc/hosts.deny"
cat_file "/etc/hosts.equiv"
sub_header "Interfaces"
#Red Hat
if [ -d /etc/sysconfig/networking/devices ]
then
for z in $(ls /etc/sysconfig/networking/devices)
  do
    cat_file "/etc/sysconfig/networking/devices/$z"
  done
fi
#Suse
if [ -d /etc/sysconfig/network ]
then
for y in $(ls /etc/sysconfig/network/ifcfg-eth*)
  do
      cat_file "$y"
  done
fi

sub_header "NIC-Settings"
report_command "/sbin/ifconfig" "Ifconfig" "-a"
for NIC in $(ifconfig |grep eth|awk '{print $1}')
do
	report_command "/usr/sbin/ethtool" "$NIC" "$NIC"
done

sub_header "Extra Info"
if [ -d /proc/net/bonding ]; then
	start_submain "bonding"
	for i in $(ls /proc/net/bonding)
	do
		cat_file "/proc/net/bonding/$i"
	done
	end_submain
fi
cat_file "/etc/nsswitch.conf"
cat_file "/etc/resolv.conf"
report_command "/sbin/route" "Route-Table"
report_command "/bin/netstat" "Netstat -a" "-a"
report_command "/bin/netstat" "Netstat -in" "-in"
report_command "/bin/netstat" "Netstat -su" "-su"
report_command "/sbin/iptables" "IPtable" " -t" "filter" "-nvL"
cat_file "/etc/hostapd/hostapd.conf"
cat_file "/etc/default/hostapd"
cat_file "/etc/dhcp/dhcpd.conf"
end_sec

#Start Services section
start_sec "Services"
report_command "/usr/sbin/sestatus" "SeLinux status"
report_command "/sbin/chkconfig" "chkconfig" " --list"
sub_header "Inetd-Services-Enabled"
cat_file "/etc/xinetd.conf"
#maybe ckconfig is enough..
if [ -d /etc/xinetd.d ]; then
for i in $(ls /etc/xinetd.d/*)
  do
if [ "$(grep disable $i|grep no|awk '{print $3}')" ];  then
    cat_file "$i" "$(basename $i)" 
    if [ "$i" =  "/etc/xinetd.d/wu-ftpd" ]; then
        sub_header "Ftp-configuration-files"
	for x in $(ls /etc/ftp*)
	do
		cat_file "$x"
	done
    else
		cat_file "/etc/pam.d/$(basename $i)"
    fi
  fi
  done
fi

cat_file "/etc/inetd.conf"

sub_header "Cron Information"
for x in $(/bin/ls -d /etc/cron*)
do
for f in $(find $x -type f)
   do
     cat_file "$f"
   done
done
end_sec

#Start Processes & software section
start_sec "Software"
report_command "/bin/ps" "Running-Processes" "-efl"
report_command "/bin/ps" "Yet-Another-ps" "--sort" "-pcpu" "-eo" "pid,ppid,s,tid,nlwp,sched,rtprio,ni,pri,psr,sgi_p,pcpu,etime,cputime,stat,eip,wchan:25,f,args:80"
#Red Hat
report_command "/usr/sbin/lsof" "Lsof"
#Suse
report_command "/usr/bin/lsof" "Lsof"
report_command "/sbin/multipath" "multipath -ll" "-ll"
report_command "/bin/rpm" "Installed Software" "-qa" #"--queryformat" "'%{installtime} %{installtime:date} %{name}-%{version}-%{release}-%{arch} \n'"
cat_file "/etc/apt/sources.list"
report_command "/usr/bin/dpkg" "Installed-Software" "-l"
report_command "/usr/bin/apt-show-versions" "apt-show-versions"
end_sec

#Start System Stats section
start_sec "Stats"
report_command "/usr/bin/uptime" "Uptime" 
report_command "/usr/bin/iostat" "Iostat"
report_command "/usr/bin/vmstat" "Vmstat"
report_command "/usr/bin/w" " " "w"
report_command "/usr/bin/last" "/usr/bin/last -ax" "-ax"
report_command "/usr/bin/free" "Mem/Swap free"
cat_file "/proc/stat"
cat_file "/proc/slabinfo"
TERM=dumb
report_command "/usr/bin/top" "top" "-n1"
if [ -d /var/log/sa ]
then
 sub_header "sar"
for i in $(ls /var/log/sa/*|grep -v sar)
  do 
    report_command "/usr/bin/sar" "$i" "-A" "-f" "$i"
  done
fi
report_command "/usr/bin/ipcs" "ipcs"
end_sec

#Start Misc info & conf files section
start_sec "Misc-Files"
cat_file "/etc/inittab"
cat_file "/etc/security/limits.conf"
cat_file "/etc/pam.d/system-auth"
cat_file "/etc/smb.conf"
cat_file "/etc/pam_smb.conf"
cat_file "/etc/yp.conf"
cat_file "/etc/ypserv.conf"
cat_file "/etc/ld.so.conf"
cat_file "/etc/iscsid.conf"
cat_file "/etc/udev/udev.conf"
report_command "/bin/ls" "/etc/udev/rules.d" "-ltr" "/etc/udev/rules.d"
cat_file "/etc/multipath.conf"
cat_file "/etc/ha.d/ha.cf"
end_sec

#THE END - CLEAN UP TEMP FILES AND TAR OUTPUT
rm -rf "$TEMP_TEXT"
cd $ROOTDIR
tar czf "$TARBALL" -C "$ROOTDIR/sysinfo" "$HNM" && rm -rf "$WORKING_DIR"
echo "THE FILE $TARBALL HAS BEEN CREATED BY sysinfo"
exit 0
