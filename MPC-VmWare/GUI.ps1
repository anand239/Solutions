Add-Type -AssemblyName System.Windows.Forms


Function Get-CredentialForm
{

    # Create a form
    $Crendential_form = New-Object System.Windows.Forms.Form
    $Crendential_form.Text = "Credential Input"
    $Crendential_form.Size = New-Object System.Drawing.Size(400, 200)
    $Crendential_form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $Crendential_form.StartPosition = "CenterScreen"

    # Create a label
    $Crendential_label = New-Object System.Windows.Forms.Label
    $Crendential_label.Location = New-Object System.Drawing.Point(20, 20)
    $Crendential_label.Size = New-Object System.Drawing.Size(200, 20)
    $Crendential_label.Text = "Enter your credentials:"
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
    $buttonOK.Location = New-Object System.Drawing.Point(20, 130)
    $buttonOK.Size = New-Object System.Drawing.Size(120, 30)
    $buttonOK.Text = "OK"
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $Crendential_form.AcceptButton = $buttonOK
    $Crendential_form.Controls.Add($buttonOK)

    # Create a Cancel button
    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Location = New-Object System.Drawing.Point(160, 130)
    $buttonCancel.Size = New-Object System.Drawing.Size(120, 30)
    $buttonCancel.Text = "Cancel"
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $Crendential_form.CancelButton = $buttonCancel
    $Crendential_form.Controls.Add($buttonCancel)
    $CredentialForm_Result = $Crendential_form.ShowDialog()
    
    $Password = $Password_textBox.Text
    $Username = $Username_textBox.Text
    $Password,$Username,$CredentialForm_Result,$CredentialForm
}

Function Get-DropDownForm
{
    $Dropdown_form = New-Object System.Windows.Forms.Form
    $Dropdown_form.Text = "Dropdown Input"
    $Dropdown_Form.Size = New-Object System.Drawing.Size(1200,800)

    # Create the dropdown menu
    $dropdown_menu = New-Object System.Windows.Forms.ComboBox
    $dropdown_menu.Location = New-Object System.Drawing.Point(50, 50)
    $dropdown_menu.Width = 200
    $dropdown_menu.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

    # Add items to the dropdown menu
    $dropdown_menu.Items.Add("10") |out-null
    $dropdown_menu.Items.Add("20") |out-null
    $dropdown_menu.Items.Add("30") |out-null

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
$form.Text = "PowerShell Form"
$form.Size = New-Object System.Drawing.Size(400, 200)
$form.StartPosition = "CenterScreen"

# Create a label
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.Size = New-Object System.Drawing.Size(260, 20)
$label.Text = "Enter Servername:"
$form.Controls.Add($label)

# Create a text box
$ServerName_TextBox = New-Object System.Windows.Forms.TextBox
$ServerName_TextBox.Location = New-Object System.Drawing.Point(20, 50)
$ServerName_TextBox.Size = New-Object System.Drawing.Size(260, 20)
$form.Controls.Add($ServerName_TextBox)

$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(20, 80)
$button.Size = New-Object System.Drawing.Size(260, 30)
$button.Text = "Submit"
$button.Add_Click({
    # Button click event handler
    $ServerName = $ServerName_TextBox.Text
    if ($ServerName -ne "") 
    {
        $form.Close()
        $Password,$Username, $CredentialForm_Result,$CredentialForm = Get-CredentialForm
        if($CredentialForm_Result -eq [System.Windows.Forms.DialogResult]::OK) 
        {
            if($Password -and $Username)
            {
                $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString -AsPlainText -Force)
                $SelectedSize,$DropdownForm_Result = Get-DropDownForm

            }
            else
            {
                [System.Windows.Forms.MessageBox]::Show("Did not entered username or password", "Error")
            }
        }
        else
        {
            [System.Windows.Forms.MessageBox]::Show("Process cancelled", "Error")
        }
    } 
    else 
    {
        [System.Windows.Forms.MessageBox]::Show("Please enter your name.", "Error")
    }
})
$form.Controls.Add($button)


$form.ShowDialog() | Out-Null




