#!/bin/bash

#-----------------------------------------------------------------------------------
# Use this script to install Oracle DB v. 11.0.2.4 x68_64 EE
# Before installation please copy these files to $INSTFILES directory: 
#
#		p13390677_112040_Linux-x86-64_{1,2}of7.zip
#		db.rsp
#		systemdbprop.sql
#-----------------------------------------------------------------------------------

INSTFILES='/home/oracle'
DISTRFILEMASK='p13390677_112040_Linux-x86-64_'
ORAINSTFILE='/etc/oraInst.loc'
ORACLE_MOUNTPOINT='/u01'
ORACLE_HOME='/u01/app/oracle/product/11.2/db'
ORACLE_INVENTORY='/u01/app/oraInventory'
RESPONSEFILE='db.rsp'
DBSETTINGS='systemdbprop.sql'

if [[ ! -d $ORACLE_MOUNTPOINT/distr ]]; then
	mkdir -p $ORACLE_MOUNTPOINT/distr
	chown -R oracle:oinstall $ORACLE_MOUNTPOINT/distr
elif [[ ! -d $ORACLE_MOUNTPOINT/app ]]; then
	mkdir -p $ORACLE_MOUNTPOINT/app
	chown -R oracle:oinstall $ORACLE_MOUNTPOINT/app
elif [[ ! -d $ORACLE_MOUNTPOINT/oradata ]]; then
	mkdir -p $ORACLE_MOUNTPOINT/oradata
	chown -R oracle:oinstall $ORACLE_MOUNTPOINT/oradata
fi

if [ `ls -l $INSTFILES/$DISTRFILEMASK*| wc -l` -eq 2 ]; then
	echo "Correct amount of ZIPs found, proceeding..."
	ls $INSTFILES/$DISTRFILEMASK* |xargs -I {} unzip {} -d $ORACLE_MOUNTPOINT/distr
	chown -R oracle:oinstall $ORACLE_MOUNTPOINT/distr/database
else
	echo "There are no files like $DISTRFILEMASK in $INSTFILES directory"
	exit 1
fi

if [[ -f $INSTFILES/$RESPONSEFILE ]]; then
	su oracle -c "cd $ORACLE_MOUNTPOINT/distr/database; ./runInstaller -silent -waitForCompletion -responseFile $INSTFILES/$RESPONSEFILE"
	$ORACLE_INVENTORY/orainstRoot.sh
	$ORACLE_HOME/root.sh
else
	echo "There is no a response file in $INSTFILES directory"
fi

su oracle -c "echo '
#Oracle PATH
export ORACLE_HOME=$ORACLE_HOME
export PATH=$ORACLE_HOME/bin:$PATH' >> ~/.bash_profile"

echo "-------------------------------------------------------------------------------"

ask() {
    while true; do
         if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi
        read -p "$1 [$prompt] " REPLY
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}

inst() {
	while :
	do	
	echo "Please enter value of ORACLE_SID variable (INSTANCE_NAME) [$SID]: "	
	read -p "$1" sid
	if [[ -z "$sid" ]] ; then 
		echo "The ORACLE_SID=$SID"
		ORACLE_SID=$SID
		break
	elif [[ `echo $sid | wc -m` -ge 13 ]]; then
		echo "It should be shorter than 13 chars."
		continue
	elif [[ "$sid" =~ ^[a-zA-Z][a-zA-Z0-9]{1,11}$ ]]; then 
		SID=`echo $sid | tr [:lower:] [:upper:]`
		SYSPASS=`echo $sid | tr [:upper:] [:lower:]`ora
		break
	else
		echo "The value should only start from [Aa-Zz] and contain alphanumeric characters."
		continue
	fi
	done
}

SID=`uname -n | awk -F. '{print $1}'|sed 's/-//g'|tr [:lower:] [:upper:]`

while ask "Do you want to create an instance? "; do 
	inst
done

echo "[GENERAL]
RESPONSEFILE_VERSION = "11.2.0"
OPERATION_TYPE = "createDatabase"
[CREATEDATABASE]
GDBNAME = "$SID"
SID = "$SID"
TEMPLATENAME = "General_Purpose.dbc"
SYSPASSWORD = "$SYSPASS"
SYSTEMPASSWORD = "$SYSPASS"
CHARACTERSET = "AL32UTF8"
NATIONALCHARACTERSET= "UTF8"" > $INSTFILES/$SID_dbca.rsp

chown oracle:oinstall $INSTFILES/$SID.rsp
chmod 700 $INSTFILES/$SID.rsp
su --login oracle -c "dbca -silent -responseFile $INSTFILES/$SID_dbca.rsp"

echo "-------------------------------------------------------------------------------"

echo "Set up necessary settings..."
arr=($(grep -v "#" /etc/oratab|awk -F: '{print $1}'))
for sidname in `echo ${arr[@]}`; do
	if [[ -f "$INSTFILES/$DBSETTINGS" ]]; then
		echo "Start applying to $sidname instance..." 
		su --login oracle -c "export ORACLE_SID=$sidname;echo '@$INSTFILES/$DBSETTINGS' | sqlplus / as sysdba"
	else
		echo "There's no file with DB settings"
	exit 1
	fi
done
