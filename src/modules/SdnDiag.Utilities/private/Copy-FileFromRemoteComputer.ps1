function Copy-FileFromRemoteComputer {
    <#
    .SYNOPSIS
        Copies an item from one location to another using FromSession
    .PARAMETER Path
        Specifies, as a string array, the path to the items to copy. Wildcard characters are permitted.
    .PARAMETER ComputerName
        Type the NetBIOS name, an IP address, or a fully qualified domain name of one or more remote computers.
    .PARAMETER Destination
        Specifies the path to the new location. The default is the current directory.
        To rename the item being copied, specify a new name in the value of the Destination parameter.
    .PARAMETER Credential
        Specifies a user account that has permission to perform this action. The default is the current user.
        Type a user name, such as User01 or Domain01\User01, or enter a PSCredential object generated by the Get-Credential cmdlet. If you type a user name, you're prompted to enter the password.
    .PARAMETER Recurse
        Indicates that this cmdlet does a recursive copy.
    .PARAMETER Force
        Indicates that this cmdlet copies items that can't otherwise be changed, such as copying over a read-only file or alias.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.String[]]$Path,

        [Parameter(Mandatory = $true)]
        [System.String[]]$ComputerName,

        [Parameter(Mandatory = $false)]
        [System.IO.FileInfo]$Destination = (Get-WorkingDirectory),

        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [Switch]$Recurse,

        [Parameter(Mandatory = $false)]
        [Switch]$Force
    )

    try {
        foreach ($object in $ComputerName) {
            if (Test-ComputerNameIsLocal -ComputerName $object) {
                "Detected that {0} is local machine" -f $object | Trace-Output
                foreach ($subPath in $Path) {
                    if ($subPath -eq $Destination.FullName) {
                        "Path {0} and Destination {1} are the same. Skipping" -f $subPath, $Destination.FullName | Trace-Output -Level:Warning
                    }
                    else {
                        "Copying {0} to {1}" -f $subPath, $Destination.FullName | Trace-Output
                        Copy-Item -Path $subPath -Destination $Destination.FullName -Recurse -Force -ErrorAction:Continue
                    }
                }
            }
            else {
                # try SMB Copy first and fallback to WinRM
                try {
                    Copy-FileFromRemoteComputerSMB -Path $Path -ComputerName $object -Destination $Destination -Force:($Force.IsPresent) -Recurse:($Recurse.IsPresent) -ErrorAction Stop
                }
                catch {
                    "{0}. Attempting to copy files using WinRM" -f $_ | Trace-Output -Level:Warning

                    try {
                        Copy-FileFromRemoteComputerWinRM -Path $Path -ComputerName $object -Destination $Destination -Force:($Force.IsPresent) -Recurse:($Recurse.IsPresent) -Credential $Credential
                    }
                    catch {
                        # Catch the copy failed exception to not stop the copy for other computers which might success
                        "{0}. Unable to copy files" -f $_ | Trace-Output -Level:Exception
                        continue
                    }
                }
            }
        }
    }
    catch {
       $_ | Trace-Output -Level:Error
    }
}
