<#
.SYNOPSIS
  Expand-VMwareCdrive.ps1
  To expand the C drive of a VM
    
.NOTES
  Script:         Expand-VMwareCdrive.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0
  Creation Date:  23/06/2023
  Modified Date:  23/06/2023 

  .History:
        Version Date            Author                       Description        
        0.0.0     23/06/2023   Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Expand-VMwareCdrive.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ConfigFile = "config.json"
)
function Get-Config
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ConfigFile # = "config.json"
    ) 
    try
    {
        if (Test-Path -Path $ConfigFile)
        {
            Write-Verbose "Parsing $ConfigFile"
            $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        }
    }
    catch
    {
        Write-Error "Error Parsing $ConfigFile" 
    }
    Write-Output $config
}

Function Get-CredentialForm
{

    # Create a form
    $Crendential_form = New-Object System.Windows.Forms.Form
    $Crendential_form.Text = "Credential Input"
    $Crendential_form.Size = New-Object System.Drawing.Size(500,300)
    $Crendential_form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $Crendential_form.StartPosition = "CenterScreen"

    # Create a label
    $Crendential_label = New-Object System.Windows.Forms.Label
    $Crendential_label.Location = New-Object System.Drawing.Point(20, 20)
    $Crendential_label.Size = New-Object System.Drawing.Size(260, 20)
    $Crendential_label.Text = "Enter your VM($VM) credentials:"
    $Crendential_form.Controls.Add($Crendential_label)

    # Create a label
    $Username_label = New-Object System.Windows.Forms.Label
    $Username_label.Location = New-Object System.Drawing.Point(20, 60)
    $Username_label.Size = New-Object System.Drawing.Size(100, 20)
    $Username_label.Text = "Username:"
    $Crendential_form.Controls.Add($Username_label)

    # Create a text box for username
    $Username_textBox = New-Object System.Windows.Forms.TextBox
    $Username_textBox.Location = New-Object System.Drawing.Point(150, 60)
    $Username_textBox.Size = New-Object System.Drawing.Size(200, 20)
    $Crendential_form.Controls.Add($Username_textBox)

    # Create a label
    $Password_label = New-Object System.Windows.Forms.Label
    $Password_label.Location = New-Object System.Drawing.Point(20, 100)
    $Password_label.Size = New-Object System.Drawing.Size(100, 20)
    $Password_label.Text = "Password:"
    $Crendential_form.Controls.Add($Password_label)

    
    # Create a text box for password
    $Password_textBox = New-Object System.Windows.Forms.TextBox
    $Password_textBox.Location = New-Object System.Drawing.Point(150, 100)
    $Password_textBox.Size = New-Object System.Drawing.Size(200, 20)
    $Password_textBox.PasswordChar = '*'
    $Crendential_form.Controls.Add($Password_textBox)

    # Create an OK button
    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Location = New-Object System.Drawing.Point(80, 130)
    $buttonOK.Size = New-Object System.Drawing.Size(120, 30)
    $buttonOK.Text = "OK"
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $Crendential_form.AcceptButton = $buttonOK
    $Crendential_form.Controls.Add($buttonOK)

    # Create a Cancel button
    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Location = New-Object System.Drawing.Point(220, 130)
    $buttonCancel.Size = New-Object System.Drawing.Size(120, 30)
    $buttonCancel.Text = "Cancel"
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $Crendential_form.CancelButton = $buttonCancel
    $Crendential_form.Controls.Add($buttonCancel)
    $CredentialForm_Result = $Crendential_form.ShowDialog()
    
    $Password = $Password_textBox.Text
    $Username = $Username_textBox.Text
    $Password,$Username,$CredentialForm_Result
}

Function Get-DropDownForm
{
    $Dropdown_form = New-Object System.Windows.Forms.Form
    $Dropdown_form.Text = "Dropdown Input"
    $Dropdown_Form.Size = New-Object System.Drawing.Size(500,200)
    $Dropdown_Form.StartPosition = "CenterScreen"

    $Info_label = New-Object System.Windows.Forms.Label
    $Info_label.Location = New-Object System.Drawing.Point(60, 20)
    $Info_label.Size = New-Object System.Drawing.Size(400, 20)
    $Info_label.Text = "Please select the size to be expanded!!"
    $Dropdown_Form.Controls.Add($Info_label)

    #create lable
    $Dropdown_label = New-Object System.Windows.Forms.Label
    $Dropdown_label.Location = New-Object System.Drawing.Point(20, 60)
    $Dropdown_label.Size = New-Object System.Drawing.Size(100, 20)
    $Dropdown_label.Text = "Size (GB) :"
    $Dropdown_Form.Controls.Add($Dropdown_label)

    # Create the dropdown menu
    $dropdown_menu = New-Object System.Windows.Forms.ComboBox
    $dropdown_menu.Location = New-Object System.Drawing.Point(140, 60)
    $dropdown_menu.Width = 180
    $dropdown_menu.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

    # Add items to the dropdown menu
    $dropdown_menu.Items.Add("10") |out-null
    $dropdown_menu.Items.Add("20") |out-null
    $dropdown_menu.Items.Add("30") |out-null
    $dropdown_menu.Items.Add("40") |out-null
    $dropdown_menu.Items.Add("50") |out-null

    # Create an EXPAND button
    $expand_button = New-Object System.Windows.Forms.Button
    $expand_button.Location = New-Object System.Drawing.Point(180, 100)
    $expand_button.Size = New-Object System.Drawing.Size(120, 30)
    $expand_button.Text = "Expand"
    $expand_button.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $Dropdown_form.AcceptButton = $expand_button
    
    $Dropdown_form.Controls.Add($expand_button)
    $Dropdown_form.Controls.Add($dropdown_menu)
    $DropdownForm_Result = $Dropdown_form.ShowDialog()
    $DropDown_SelectedItem = $dropdown_menu.SelectedItem
    $DropDown_SelectedItem,$DropdownForm_Result
}

$config = Get-Config -ConfigFile $ConfigFile

if($config)
{
    $CredentialPath = $config.CredentialFile
    if (!(Test-Path -Path $CredentialPath) )
    {
        $Credential = Get-Credential -Message "Enter Credentials"
        $Credential | Export-Clixml $CredentialPath -Force
    }
    try
    {
        $Credential = Import-Clixml $CredentialPath
    }
    catch
    {
        Write-Host "Invalid Credential File!" -ForegroundColor Red
        exit
    }
    $Vcenters = $config.VcenterServers
    if(!($Vcenters))
    { 
        Write-Host "Vcenter servers are not provided" -ForegroundColor Red
    }

    
    Add-Type -AssemblyName System.Windows.Forms

    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "VmWare C-Drive Expansion"
    $form.Size = New-Object System.Drawing.Size(500, 200)
    $form.StartPosition = "CenterScreen"

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(120, 20)
    $label.Size = New-Object System.Drawing.Size(260, 20)
    $label.Text = "Please enter Vcenter details!!"
    $form.Controls.Add($label)


    # Create a label
    $VmName_label = New-Object System.Windows.Forms.Label
    $VmName_label.Location = New-Object System.Drawing.Point(20, 60)
    $VmName_label.Size = New-Object System.Drawing.Size(100, 20)
    $VmName_label.Text = "VM Name:"
    $form.Controls.Add($VmName_label)

    # Create a text box for username
    $VmName_textBox = New-Object System.Windows.Forms.TextBox
    $VmName_textBox.Location = New-Object System.Drawing.Point(120, 60)
    $VmName_textBox.Size = New-Object System.Drawing.Size(260, 20)
    $form.Controls.Add($VmName_textBox)


    # Create an OK button
    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Location = New-Object System.Drawing.Point(120, 100)
    $buttonOK.Size = New-Object System.Drawing.Size(120, 30)
    $buttonOK.Text = "OK"
    #$buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK

    # Create a Cancel button
    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Location = New-Object System.Drawing.Point(260, 100)
    $buttonCancel.Size = New-Object System.Drawing.Size(120, 30)
    $buttonCancel.Text = "Cancel"
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $buttonCancel
    $form.Controls.Add($buttonCancel)



    $buttonOK.Add_Click({
        # Button click event handler
        $VmName = $VmName_textBox.Text
        $form.Close()
        if ($VmName) 
        {            
            foreach($Vcenter in $Vcenters)
            {
                $VcenterConnection = Connect-VIServer -Server $Vcenter -credential $Credential
                if($VcenterConnection.IsConnected -eq $true)
                {
                    $VM = Get-VM -Name $VmName
                    if($VM)
                    {
                        break
                    }
                    else
                    {
                        Disconnect-VIServer -Server $Vcenter -Confirm:$false
                    }
                }
                else
                {
                    [System.Windows.Forms.MessageBox]::Show("Failed to connect to Vcenter server", "Error")
                }
            }
            if($VM)
            {
                $SelectedSize,$DropdownForm_Result = Get-DropDownForm
                $Error.Clear()
                try
                {
                    $HardDisk = Get-HardDisk -VM $VM | Where-Object {$_.Name -eq "Hard Disk 1"}

                    [int]$CurrentSize = ( $HardDisk | Select-Object CapacityGB).CapacityGB
                    [int]$Target_Disk = $SelectedSize
                    $Final_Size = $Target_Disk+$CurrentSize

                    $Expand = $HardDisk | Set-HardDisk -CapacityGB $Final_Size -Confirm:$false
                   
                    $HardDisk = Get-HardDisk -VM $VM | Where-Object {$_.Name -eq "Hard Disk 1"}

                    $AfterSize = ( $HardDisk | Select-Object CapacityGB).CapacityGB

                    if($CurrentSize -ne $AfterSize)
                    {
                        $ScriptBlock = 
                        {
                            $MaxSize = (Get-PartitionSupportedSize -DriveLetter C).Sizemax
                            $NewMaxSize = (Get-PartitionSupportedSize -DriveLetter C).Sizemax
                            $clear = Update-HostStorageCache
                            $Resize = Resize-Partition -DriveLetter C -Size $NewMaxSize                       
                            $MaxSize_After = (Get-PartitionSupportedSize -DriveLetter C).Sizemax
                            $MaxSize,$MaxSize_After
                        }

                        #$VmPassword,$VmUsername,$VmCredentialForm_Result = Get-CredentialForm
                        #if($VmCredentialForm_Result -eq "OK")
                        #{
                            #if($VmPassword -and $VmUsername)
                            #{
                        
                                $MaxSiz_Beforee,$MaxSize_After = Invoke-Command -ComputerName $VmName -ScriptBlock $ScriptBlock
                                [System.Windows.Forms.MessageBox]::Show(" Operation completed successfully `n`n VMware Level:`n Before Expansion: $CurrentSize GB `n After Expansion: $AfterSize GB `n`n OS Level:`n Before Expansion: $($MaxSiz_Beforee/1gb) GB `n After Expansion: $($MaxSize_After/1gb) GB ")
                            #}
                            #else
                            #{
                            #    [System.Windows.Forms.MessageBox]::Show("Did not entered VM credentials", "Error")
                            #}
                        #}
                        #else
                        #{
                        #    [System.Windows.Forms.MessageBox]::Show("Cancelled the operation", "Error")
                        #}
                    }
                    else
                    {
                        [System.Windows.Forms.MessageBox]::Show("Failed to expand the harddisk in VMware level.", "Error")
                    }
                }
                catch
                {
                    [System.Windows.Forms.MessageBox]::Show($Error.exception.message,"Error")
                }
            }
            else
            {
                [System.Windows.Forms.MessageBox]::Show("Failed to fetch VM from the given Vcenters", "Error")
            }                   
        } 
        else 
        {
            [System.Windows.Forms.MessageBox]::Show("Vcenter name is not entered.", "Error")
        }
    })
    $form.Controls.Add($buttonOK)


    $form.ShowDialog() | Out-Null


}

else
{
    Write-Host "Invalid $ConfigFile" -ForegroundColor Red
}
Write-Host "Completed" -ForegroundColor Green 


