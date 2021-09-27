# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Install-SdnDiagnostics {
    <#
    .SYNOPSIS
        Install SdnDiagnostic Module to remote computers if not installed or version mismatch.
    .PARAMETER ComputerName
        Type the NetBIOS name, an IP address, or a fully qualified domain name of one or more remote computers.
    .PARAMETER Credential
        Specifies a user account that has permission to perform this action. The default is the current user.
        Type a user name, such as User01 or Domain01\User01, or enter a PSCredential object generated by the Get-Credential cmdlet. If you type a user name, you're prompted to enter the password.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String[]]$ComputerName,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    try {
        $filteredComputerName = [System.Collections.ArrayList]::new()

        # if we have multiple modules installed on the current workstation, 
        # abort the operation because side by side modules can cause some interop issues
        # to the remote nodes
        $localModule = Get-Module -Name 'SdnDiagnostics'
        if ($localModule.Count -gt 1) {
            throw New-Object System.ArgumentOutOfRangeException("Detected more than one module version of SdnDiagnostics. Remove existing modules and restart your PowerShell session.")
        }

        # make sure that in instances where we might be on a node within the sdn dataplane, 
        # that we do not remove the module locally
        foreach ($computer in $ComputerName) {
            if (Test-ComputerNameIsLocal -ComputerName $computer) {
                "Detected that {0} is local machine. Skipping update operation for {0}." -f $computer | Trace-Output -Level:Warning
                continue
            }
            else {
                [void]$filteredComputerName.Add($computer)
            }
        }

        # clean up the module directory on remote computers
        Invoke-PSRemoteCommand -ComputerName $filteredComputerName -Credential $Credential -ScriptBlock {
            $modulePath = 'C:\Program Files\WindowsPowerShell\Modules\SdnDiagnostics'
            if (Test-Path -Path $modulePath -PathType Container) {
                Remove-Item -Path $modulePath -Recurse -Force
            }
        }

        # copy the module base directory to the remote computers
        # currently hardcoded to machine's module path. Use the discussion at https://github.com/microsoft/SdnDiagnostics/discussions/68 to get requirements and improvement
        Copy-FileToPSRemoteSession -Path $localModule.ModuleBase -ComputerName $filteredComputerName -Destination "C:\Program Files\WindowsPowerShell\Modules" -Credential $Credential -Recurse -Force

        # ensure that we destroy the current pssessions for the computer to prevent any caching issues
        Remove-PSRemotingSession -ComputerName $filteredComputerName
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}