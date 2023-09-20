#!/bin/bash

server_file="path of the serverlist file"
while IFS= read -r server;do
	#entering  into every server
	cron_out=$(ssh $server  'crontab -l | grep -i mksysb')
	#15 03 6 * * /opt/system/bin/mksysb_create.ksh nguknimmds001i4 /RTW_mksysb /mnt >/var/log/mksysb_local_cron.log 2>&1
	#15 03 6 * * /opt/system/bin/mksysb_create.ksh nguknimmds002i4 /BTE_mksysb /mnt >/var/log/mksysb_local_cron.log 2>&1

	while IFS= read -r cron_line;do
		path=$(echo "$cron_line" | awk '{print $8}')
		server1=$(echo "$cron_line" | awk '{print $7}')
		echo "The path is : $path"
		echo "The server name is : $server1"
		file="${path} ${server}"

		ssh root@$server1 "file='$file' exec sh" <<'EOF'
		path=$(echo $file | awk '{print $1}')
		server1=$(echo $file | awk '{print $2}')
		cd $path
		Allfiles=$(ls -lrt | grep -i $server1)

		if [[ $? != 0 ]];then
			#send mail to team
		else
			#removing older files
			while IFS= read -r line;do
				rm $line
			done < <(ls -lrt | grep mksysb | sed '$d'|awk '{print $9}')
		fi
		EOF
	done < <(echo "$cron_out" | grep mksysb)
done < "$server_file"
