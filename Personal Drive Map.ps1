# Get the username of the currently logged-in user
$currentUsername = $env:USERNAME

# Define the LDAP path for the current user
$ldapPath = "LDAP://<SID=" + (New-Object System.Security.Principal.NTAccount($currentUsername)).Translate([System.Security.Principal.SecurityIdentifier]).Value + ">"

# Create a DirectoryEntry object
$userEntry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)

# Get the Distinguished Name (DN) of the current user
$userDN = $userEntry.DistinguishedName

# Log the userDN to see what information it receives
Write-Host "User DistinguishedName: $userDN"

# Define the list of valid OU names
$validOUs = @("Administration", "Ejendomsmaeglere", "Facility", "Teknik")

# Initialize $ouName to null
$ouName = $null

# Loop through valid OU names and check if they are present in the DistinguishedName
foreach ($validOU in $validOUs) {
    if ($userDN -like "*OU=$validOU,*") {
        $ouName = $validOU
        break
    }
}

# Check if a valid OU name was found
if (-not $ouName) {
    Write-Host "Error: Unable to determine a valid OU name for user $currentUsername"
    Pause
    exit
}

# Specify the base path where user folders will be created
$baseFolderPath = "\\FTP-AAl\User Folders"

# Construct the path for the user's folder with the Main OU name
$theFolderPath = "\\FTP-AAL\$ouName\$currentUsername"



# Check if the user's folder already exists, if not, create it
if (-not (Test-Path $theFolderPath -PathType Container)) {
    New-Item -Path $theFolderPath -ItemType Directory
    Write-Host "Folder created for user $currentUsername at $theFolderPath"
	Start-Sleep -Seconds 5
    # Create an ACL object
    $acl = Get-Acl $theFolderPath
    
    # Set ACL protection
    $acl.SetAccessRuleProtection($true, $false)

    # Add individual user to the ACL
    $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$currentUsername", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($userRule)

    # Add security group(s) to the ACL
    $securityGroup1 = "It ADM Sec"
    $securityGroup2 = "Administrators"

    $groupRule1 = New-Object System.Security.AccessControl.FileSystemAccessRule($securityGroup1, "Fullcontrol", "ContainerInherit,ObjectInherit", "None", "Allow")
    $groupRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule($securityGroup2, "Fullcontrol", "ContainerInherit,ObjectInherit", "None", "Allow")

    $acl.AddAccessRule($groupRule1)
    $acl.AddAccessRule($groupRule2)

    # Apply the ACL to the folder
    Set-Acl $theFolderPath $acl
} else {
    Write-Host "Folder for user $currentUsername already exists at $theFolderPath"
}


# Map the folder as a drive2
$driveLetter = "P"
New-PSDrive -Name "P" -PSProvider FileSystem -Root $theFolderPath -Persist -Scope Global

Start-Sleep -Seconds 5

$a = New-Object -ComObject shell.application
$a.NameSpace( "P:\").self.name = "Personligt"

Write-Host "Drive mapped: $driveLetter -> $theFolderPath"

