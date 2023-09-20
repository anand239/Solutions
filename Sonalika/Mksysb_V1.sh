#!/bin/bash
server_file="servers.txt"
while IFS= read -r server;do
	echo $server
	#entering  into every server
	cron_out=$(ssh -n $server 'crontab -l | grep -i mksysb')
	#echo "$cron_out"
	while IFS= read -r cron_line;do
		path=$(echo "$cron_line" | awk '{print $8}')
		server1=$(echo "$cron_line" | awk '{print $7}')
		echo "The path is : $path"
		echo "The server name is : $server1"

		servergrep=$(ssh -n root@$server1 ls -ltr $path |grep -i $server)
		if [[ $? = 0 ]];then
			echo -e "\033[0;31m ****All files**** \033[0m"
			echo "$servergrep"
			echo -e "\033[0;31m ****Old files**** \033[0m"
			echo "$servergrep" | sed '$d'
			read -u 1 -p "Do you want to remove these files (y/n) : " yesorno
			if [[ $yesorno == y ]];then
				echo -e "\033[0;31m Removing the Files \033[0m"
				#ssh -n root@$server1 ls $path |grep -i $server |sed '$d'|xargs rm
				echo -e "\033[0;31m ************* \033[0m"
				echo -e "\033[0;31m Files are Removed \033[0m"
			else
				echo "No files removed......."
				echo -e "\033[0;31m ************* \033[0m"
			fi

		else
			echo "Backups are not present"
		fi
	done < <(echo "$cron_out")
done < "$server_file"