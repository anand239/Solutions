#!/bin/bash


while IFS= read -r server
do
#entering  into every server
ssh $server

out=$(crontab -l | grep -i mksysb)
#15 03 6 * * /opt/system/bin/mksysb_create.ksh nguknimmds001i4 /RTW_mksysb /mnt >/var/log/mksysb_local_cron.log 2>&1
#15 03 6 * * /opt/system/bin/mksysb_create.ksh nguknimmds002i4 /BTE_mksysb /mnt >/var/log/mksysb_local_cron.log 2>&1
if [[ $? = 0 ]];then
#continues if command generates output
echo "$out"

while IFS= read -r cron_out
do

echo "$cron_out"
path=$(echo "$cron_out" | awk '{print $8}')
server1=$(echo "$cron_out" | awk '{print $7}')
echo "This is path : $path"
echo "This is server name : $server1"
exit

ssh $server1
#enter password

sudo su -
#enter password

cd $path
$o=$(ls -lrt | grep -i $server)

if [[ $? != 0 ]];then
#send mail to team
else
# check how many entries are there
oo=$(echo "$o" | wc -l)

if [[ $oo -eq 1 ]];then
echo "$o"
echo "Everythig is fine"
elif [[ $oo -gt 1]];then
#compare dates of entries and delete the older one
readarray -t line < <(ls -lrt | grep -i $server | awk '{print $9}')
source_file=${line[0]}
target_file=${line[1]}
if [ "$source_file" -nt "$target_file" ]
then
    printf '%s\n' "$target_file is older than $source_file"
    echo "Removing $target_file"
    rm $target_file
else
    printf '%s\n' "$source_file is older than $target_file"
    echo "Removing $source_file"
    rm $source_file
fi

fi
 
fi

done < <(crontab -l | grep -i mksysb)

else
echo "Crontab does not contain mksysb job"
fi

done < server.txt



