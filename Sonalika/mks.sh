sudo su -
#enter password

cd $path
o=$(ls -lrt | grep -i $server)

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
