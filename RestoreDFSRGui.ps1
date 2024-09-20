function Test-WritePermission {
    param (
        [string]$FilePath
    )
    $acl = Get-Acl -Path $FilePath
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $hasWritePermission = $false

    foreach ($access in $acl.Access) {
        if ($access.IdentityReference -eq $currentUser.Name -and
            $access.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Write -and
            $access.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) {
            $hasWritePermission = $true
            break
        }
    }
    return $hasWritePermission
}

function Grant-WritePermission {
    param (
        [string]$FilePath
    )
    $acl = Get-Acl -Path $FilePath
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $currentUser.Name,
        [System.Security.AccessControl.FileSystemRights]::Write,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $FilePath -AclObject $acl
}

# Function to check if the script is running as an administrator
function Test-IsAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Self-elevation function
function Elevate-Script {
    if (-not (Test-IsAdmin)) {
        $newProcess = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# Call the self-elevation function at the start of the script
Elevate-Script


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Remove-ReadOnlyAttribute {
    param (
        [string]$FilePath
    )
    try {
        Set-ItemProperty -Path $FilePath -Name IsReadOnly -Value $false
        Write-host "Removed read-only attribute from $FilePath."
    } catch {
        Write-host "Failed to remove read-only attribute: $_"
    }
}
function Set-ReadOnlyAttribute {
    param (
        [string]$FilePath
    )
    try {
        Set-ItemProperty -Path $FilePath -Name IsReadOnly -Value $true
        Write-Output "Set read-only attribute for $FilePath."
    } catch {
        Write-Output "Failed to set read-only attribute: $_"
    }
}

function Test-ReadWritePermission {
    param (
        [string]$FilePath
    )
    $acl = Get-Acl -Path $FilePath
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $hasReadWritePermission = $false

    foreach ($access in $acl.Access) {
        if ($access.IdentityReference -eq $currentUser.Name -and
            $access.FileSystemRights -band ([System.Security.AccessControl.FileSystemRights]::Read -bor [System.Security.AccessControl.FileSystemRights]::Write) -and
            $access.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) {
            $hasReadWritePermission = $true
            break
        }
    }
    return $hasReadWritePermission
}

function Grant-ReadWritePermission {
    param (
        [string]$FilePath
    )
    $acl = Get-Acl -Path $FilePath
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $currentUser.Name,
        [System.Security.AccessControl.FileSystemRights]::Read, [System.Security.AccessControl.FileSystemRights]::Write,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $FilePath -AclObject $acl
}

function Grant-FullControl {
    param (
        [string]$DirectoryPath
    )
    try {
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $acl = Get-Acl -Path $DirectoryPath
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $currentUser,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $DirectoryPath -AclObject $acl
        Write-host "Full control granted to $currentUser for directory $DirectoryPath."
    } catch {
        Write-host "Failed to grant full control: $_"
    }
}

function Load-Files {
    param (
        [string]$XmlPath
    )
    $xml = [xml](Get-Content -Path $XmlPath)
    $files = @()
    foreach ($file in $xml.ConflictAndDeletedManifest.Resource) {
        $files += [pscustomobject]@{
            Path = $file.Path
            NewName = $file.NewName
        }
    }
    return $files, $xml
}

function Remove-FileEntry {
    param (
        [xml]$xml,
        [string]$Path
    )
    $entry = $xml.ConflictAndDeletedManifest.Resource | Where-Object { $_.Path -eq $Path }
    Write-host "OK"
    if ($entry) {
        $xml.ConflictAndDeletedManifest.RemoveChild($entry)
    }
}

function Restore-File {
    param (
        [string]$ConflictDir,
        [string]$Path,
        [string]$restorefile
    )
    $filetorestore ="$ConflictDir$restorefile"
    #$restorefilepath = $Path -split " \| "
    $RestoreFileName = Split-Path -Path $Path -Leaf
    Write-host $Path
    Write-host $$RestoreFileName
    Write-host $filetorestore
    # Implement actual logic to restore files
    If (Test-Path -path $filetorestore -PathType Leaf) {
    Move-Item -Path "$filetorestore" -Destination "c:\temp\$RestoreFileName" -ErrorAction SilentlyContinue
    #Move-Item -Path "$filetorestore" -Destination "$path" -ErrorAction SilentlyContinue
    
}
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "DFS Restore"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "ConflictAndDeletedManifest.xml Path:"
$label.Location = New-Object System.Drawing.Point(10, 20)
$label.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($label)

$textbox = New-Object System.Windows.Forms.TextBox
$textbox.Location = New-Object System.Drawing.Point(10, 50)
$textbox.Size = New-Object System.Drawing.Size(460, 20)
$form.Controls.Add($textbox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Browse"
$browseButton.Location = New-Object System.Drawing.Point(480, 47)
$browseButton.Size = New-Object System.Drawing.Size(80, 25)
$form.Controls.Add($browseButton)

$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(10, 80)
$listBox.Size = New-Object System.Drawing.Size(750, 200)
$listBox.SelectionMode = "MultiExtended"
$listBox.ScrollAlwaysVisible = $true
$listBox.HorizontalScrollbar = $true
$form.Controls.Add($listBox)

$removeButton = New-Object System.Windows.Forms.Button
$removeButton.Text = "Recover Selected File(s)"
$removeButton.Location = New-Object System.Drawing.Point(10, 290)
$removeButton.Size = New-Object System.Drawing.Size(150, 30)
$form.Controls.Add($removeButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(170, 295)
$statusLabel.Size = New-Object System.Drawing.Size(390, 20)
$form.Controls.Add($statusLabel)

# Form closing event handler
$form.Add_FormClosing({
    $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to close this form?", "Confirm Exit", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq [System.Windows.Forms.DialogResult]::No) {
        $_.Cancel = $true
    } else {
        if ($textbox.Text) {
            Set-ReadOnlyAttribute -FilePath $textbox.Text
        }
    }
})


$browseButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "XML files (*.xml)|*.xml"
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $xmlPath = $openFileDialog.FileName 
        $textbox.Text = $xmlPath
        
        $directoryPath = [System.IO.Path]::GetDirectoryName($xmlPath)
        Grant-FullControl -DirectoryPath $directoryPath
        
        if (-not (Test-WritePermission -FilePath $xmlPath)) {
            try {
                Grant-WritePermission -FilePath $xmlPath
                $statusLabel.Text = "Write permissions granted to the current user."
            } catch {
                $statusLabel.Text = "Failed to grant write permissions: $_"
                return
            }
        }
        if (-not (Test-ReadWritePermission -FilePath $xmlPath)) {
            try {
                Grant-ReadWritePermission -FilePath $xmlPath
                $statusLabel.Text = "Read and write permissions granted to the current user."
            } catch {
                $statusLabel.Text = "Failed to grant read and write permissions: $_"
                return
            }
        }
        
        Remove-ReadOnlyAttribute -FilePath $xmlPath

        $listBox.Items.Clear()
        
        $files, $xml = Load-Files -XmlPath $xmlPath
        
        foreach ($file in $files) {
            $listBox.Items.Add("$($file.Path) | $($file.NewName)")
        }
    }
})

$removeButton.Add_Click({
    $selectedItems = $listBox.SelectedItems
    if ($selectedItems.Count -gt 0) {
        $xmlPath = $textbox.Text
        $files, $xml = Load-Files -XmlPath $xmlPath
        $file = Get-Childitem $xmlPath  -ErrorAction SilentlyContinue
        $FileLocation = $File.DirectoryName
        $ConflictDir = "$FileLocation\ConflictAndDeleted\"
        foreach ($item in $selectedItems) {
            $path = $item -split " \| "
            Restore-File -Path $path[0].substring(4) -restorefile $path[1] -ConflictDir $ConflictDir
            Remove-FileEntry -xml $xml -Path $path[0]
        }
        #Save ConflictandDeleted.xml
        $xml.Save($xmlPath)
        $statusLabel.Text = "Selected files recovered successfully."

        $listBox.Items.Clear()
        $files, $xml = Load-Files -XmlPath $xmlPath
        foreach ($file in $files) {
            $listBox.Items.Add("$($file.Path) | $($file.NewName)")
        }
    } else {
        $statusLabel.Text = "No files selected."
    }
})

[void]$form.ShowDialog()