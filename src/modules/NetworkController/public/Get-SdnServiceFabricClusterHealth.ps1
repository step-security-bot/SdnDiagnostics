# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Get-SdnServiceFabricClusterHealth {
    <#
    .SYNOPSIS
        Gets health information for a Service Fabric cluster from Network Controller.
    .PARAMETER NetworkController
        Specifies the name of the network controller node on which this cmdlet operates.
    .PARAMETER Credential
        Specifies a user account that has permission to perform this action. The default is the current user.
    .EXAMPLE
        PS> Get-SdnServiceFabricClusterHealth -NetworkController 'NC01' -Credential (Get-Credential)
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [System.String[]]$NetworkController = $Global:SdnDiagnostics.EnvironmentInfo.NC,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty        
    )

    try {
        if ($NetworkController) {
            Invoke-SdnServiceFabricCommand -NetworkController $NetworkController -ScriptBlock { Get-ServiceFabricClusterHealth } -Credential $Credential
        }
        else {
            Invoke-SdnServiceFabricCommand -ScriptBlock { Get-ServiceFabricClusterHealth } -Credential $Credential
        }
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}
