ScriptName : Get-EnvironmentData.ps1
UCMS : 58630

Script Running Procedure:
	1. Before Extracting please go to properties of zip file and unblock if blocked.
	2. Provide the required details in config.json file.
	3. Run the run.bat file.
	4. Report will be generated in the given path as "Report.csv".

Config.json Parameters:
	1. CellInfoFile :
		1.Give the file name if script and file are in same path.
			eg: "Cell_Info"
		2.Provide the full path if file is located in another directory, seperated by "\\".
			eg: "C:\\BURAuto\\Get-EnvironmentData\\Cell_Info"
	2. HostsFile :
		1.Give the file name if script and file are in same path.
			eg: "Hosts"
		2.Provide the full path if file is located in another directory, seperated by "\\".
			eg: "C:\\BURAuto\\Get-EnvironmentData\\Hosts"
	3. BackupReportFile :
		1.Give the file name if script and file are in same path.
			eg: "SCC_BackupReport 02 Feb 2022"
		2.Provide the full path if file is located in another directory, seperated by "\\".
			eg: "C:\\BURAuto\\Get-EnvironmentData\\SCC_BackupReport 02 Feb 2022.csv"
	4. ReportPath : Provide the path where report needs to be generated.
		eg: "C:\\BURAuto\\Get-EnvironmentData"
