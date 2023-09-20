##############################################################
# UCMS id : 49070
# Title : BUR#Netbackup#Backup#Script# Automated DSR Status Report
# Author : a.chintalapudi@dxc.com
# Date : 18/09/2021
# Last Edited: 18/09/2021, by Anand
# Description: The script was created to genearte DSR Report and send mail
##############################################################

1.Config File Parameters
	InputFilePath : It is a .csv File which has Host names, IP addresses and corresponding Filepaths of each server.
	SmtpServer    : Smtp Server details.
	From          : From address.
	To            : To Address. Can be seperated with ";"(Semicolon) ("to@dxc.com;to@dxc.com") if there are multiple.
	cc            : Can be seperated with ";"(Semicolon) ("cc@dxc.com;cc@dxc.com") if there are multiple. Else remove that parameter.
	Subject       : Subject of the mail.

2.Input.csv parameters
	Hostname      : Hostnames
	Ip            : IP's of corresponding Hostnames.
	Filepath      : Paths of Corresponding Hostnames.
	
3.Run.bat
	Provide Powershell(.ps1) script name to run the script.

###############################################################
Main Reason for Error
	Provide "\\" in the InputFilepath instead of "\".
	End each parameter with "," except last in config file.
	If unable to run RUN.bat, go to properties of file and unblock it.