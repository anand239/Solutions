Add-Type -AssemblyName System.Windows.Forms


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
    $Dropdown_Form.Size = New-Object System.Drawing.Size(500,300)
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
    $expand_button.Location = New-Object System.Drawing.Point(20, 130)
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


# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "VmWare C-Drive Expansion"
$form.Size = New-Object System.Drawing.Size(500, 300)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(120, 20)
$label.Size = New-Object System.Drawing.Size(260, 20)
$label.Text = "Please enter Vcenter details!!"
$form.Controls.Add($label)

# Create a label
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(20, 60)
$label.Size = New-Object System.Drawing.Size(170, 20)
$label.Text = "Vcenter Servername:"
$form.Controls.Add($label)

# Create a text box
$ServerName_TextBox = New-Object System.Windows.Forms.TextBox
$ServerName_TextBox.Location = New-Object System.Drawing.Point(190, 60)
$ServerName_TextBox.Size = New-Object System.Drawing.Size(260, 20)
$form.Controls.Add($ServerName_TextBox)


# Create a label
$Username_label = New-Object System.Windows.Forms.Label
$Username_label.Location = New-Object System.Drawing.Point(20, 100)
$Username_label.Size = New-Object System.Drawing.Size(160, 20)
$Username_label.Text = "Username:"
$form.Controls.Add($Username_label)

# Create a text box for username
$Username_textBox = New-Object System.Windows.Forms.TextBox
$Username_textBox.Location = New-Object System.Drawing.Point(190, 100)
$Username_textBox.Size = New-Object System.Drawing.Size(260, 20)
$form.Controls.Add($Username_textBox)

# Create a label
$Password_label = New-Object System.Windows.Forms.Label
$Password_label.Location = New-Object System.Drawing.Point(20, 140)
$Password_label.Size = New-Object System.Drawing.Size(160, 20)
$Password_label.Text = "Password:"
$form.Controls.Add($Password_label)

    
# Create a text box for password
$Password_textBox = New-Object System.Windows.Forms.TextBox
$Password_textBox.Location = New-Object System.Drawing.Point(190, 140)
$Password_textBox.Size = New-Object System.Drawing.Size(260, 20)
$Password_textBox.PasswordChar = '*'
$form.Controls.Add($Password_textBox)

# Create a label
$VmName_label = New-Object System.Windows.Forms.Label
$VmName_label.Location = New-Object System.Drawing.Point(20, 180)
$VmName_label.Size = New-Object System.Drawing.Size(160, 20)
$VmName_label.Text = "VM Name:"
$form.Controls.Add($VmName_label)

# Create a text box for username
$VmName_textBox = New-Object System.Windows.Forms.TextBox
$VmName_textBox.Location = New-Object System.Drawing.Point(190, 180)
$VmName_textBox.Size = New-Object System.Drawing.Size(260, 20)
$form.Controls.Add($VmName_textBox)


# Create an OK button
$buttonOK = New-Object System.Windows.Forms.Button
$buttonOK.Location = New-Object System.Drawing.Point(120, 210)
$buttonOK.Size = New-Object System.Drawing.Size(120, 30)
$buttonOK.Text = "OK"
#$buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK

# Create a Cancel button
$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Location = New-Object System.Drawing.Point(260, 210)
$buttonCancel.Size = New-Object System.Drawing.Size(120, 30)
$buttonCancel.Text = "Cancel"
$buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $buttonCancel
$form.Controls.Add($buttonCancel)



$buttonOK.Add_Click({
    # Button click event handler
    $vCenterServer = $ServerName_TextBox.Text
    $VmName = $VmName_textBox.Text
    $form.Close()
    if ($vCenterServer -ne "") 
    {
        $Password = $Password_textBox.Text
        $Username = $Username_textBox.Text
        if($Password -and $Username)
        {
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString -AsPlainText -Force)
            $SelectedSize,$DropdownForm_Result = Get-DropDownForm

            $VcenterConnection = Connect-VIServer -Server $vCenterServer -credentail $credential
            if($VcenterConnection.IsConnected -eq $true)
            {
                $VM = Get-VM -Name $VmName
                if($VM)
                {
                    $Expand = Get-HardDisk -VM $VM -Name "Hard disk 1" | Set-HardDisk -CapacityGB $SelectedSize -Confirm:$false

                    $ScriptBlock = 
                    {
                        $MaxSize = (Get-PartitionSupportedSize -DriveLetter C).Sizemax
                        Resize-Partition -DriveLetter C -Size $MaxSize
                    }

                    #$VmPassword,$VmUsername,$VmCredentialForm_Result = Get-CredentialForm
                    #if($VmCredentialForm_Result -eq "OK")
                    #{
                        #if($VmPassword -and $VmUsername)
                        #{
                            $Out = Invoke-Command -ComputerName $VmName -ScriptBlock $ScriptBlock
                            [System.Windows.Forms.MessageBox]::Show("Operation completed successfully")
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
                        [System.Windows.Forms.MessageBox]::Show("Unable to fetch VM details", "Error")
                }
            }
            else
            {
                [System.Windows.Forms.MessageBox]::Show("Failed to connect to Vcenter server", "Error")
            }

        }
        else
        {
            [System.Windows.Forms.MessageBox]::Show("Did not entered username or password", "Error")
        }
    } 
    else 
    {
        [System.Windows.Forms.MessageBox]::Show("Vcenter name is not entered.", "Error")
    }
})
$form.Controls.Add($buttonOK)


$form.ShowDialog() | Out-Null



