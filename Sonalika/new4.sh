#!/bin/bash



output=$(ssh cvardhan@192.168.223.235 'crontab -l | grep mksysb')
echo "$output"
: '
while IFS= read -r line;do
path=$(echo "$line" | awk '{print $8}')
server1=$(echo "$line" | awk '{print $7}')
echo "The path is $path"
echo "The server name is $server1"
export path
export server1
sleep 10
ssh -t cvardhan@192.168.223.235 "path='$path' exec sh"< new5.sh

done < <(echo "$output" | grep mksysb)


#ssh root@192.168.223.234 "path='$path' exec sh" < new5.sh

'
while IFS= read -r line;do
path=$(echo "$line" | awk '{print $8}')
server1=$(echo "$line" | awk '{print $7}')
echo "The path is $path"
echo "The server name is $server1"

ssh  cvardhan@192.168.223.235 "path='$path' exec sh"<< 'EOF'
echo "the 2nd server name is $server1"
echo "2nd server path is $path"
o=$(ls)
echo "$o"
if [[ $? -eq 0 ]];then
echo "fine"
else
echo "not fine"
fi

EOF

done < <(echo "$output" | grep mksysb)
