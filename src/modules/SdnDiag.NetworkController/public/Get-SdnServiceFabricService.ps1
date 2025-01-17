function Get-SdnServiceFabricService {
    <#
    .SYNOPSIS
        Gets a list of Service Fabric services from Network Controller.
    .PARAMETER ApplicationName
        A service fabric application name that exists on the provided ring, such as fabric:/NetworkController.
    .PARAMETER ServiceName
        A service fabric service name that is under the provided ApplicationName on the provided ring, such as fabric:/NetworkController/ApiService.
    .PARAMETER ServiceTypeName
        A service fabric service TypeName, such as VSwitchService
    .PARAMETER NetworkController
        Specifies the name of the network controller node on which this cmdlet operates.
    .PARAMETER Credential
        Specifies a user account that has permission to perform this action. The default is the current user.
    .EXAMPLE
        PS> Get-SdnServiceFabricService -NetworkController 'Prefix-NC01' -Credential (Get-Credential)
    .EXAMPLE
        PS> Get-SdnServiceFabricService -NetworkController 'Prefix-NC01' -Credential (Get-Credential) -ServiceTypeName 'ApiService'
    #>

    [CmdletBinding(DefaultParameterSetName = 'NamedService')]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'NamedService')]
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'NamedServiceTypeName')]
        [System.String]$ApplicationName = 'fabric:/NetworkController',

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'NamedService')]
        [System.String]$ServiceName,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'NamedServiceTypeName')]
        [System.String]$ServiceTypeName,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'NamedService')]
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'NamedServiceTypeName')]
        [System.String[]]$NetworkController = $global:SdnDiagnostics.EnvironmentInfo.NetworkController,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'NamedService')]
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'NamedServiceTypeName')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    try {
        switch ($PSCmdlet.ParameterSetName) {
            'NamedService' {
                if ($ServiceName) {
                    $sb = {
                        Get-ServiceFabricApplication -ApplicationName $using:ApplicationName | Get-ServiceFabricService -ServiceName $using:ServiceName
                    }
                }
                else {
                    $sb = {
                        Get-ServiceFabricApplication -ApplicationName $using:ApplicationName | Get-ServiceFabricService
                    }
                }
            }

            'NamedServiceTypeName' {
                if ($ServiceTypeName) {
                    $sb = {
                        Get-ServiceFabricApplication -ApplicationName $using:ApplicationName | Get-ServiceFabricService -ServiceTypeName $using:ServiceTypeName
                    }
                }
                else {
                    $sb = {
                        Get-ServiceFabricApplication -ApplicationName $using:ApplicationName | Get-ServiceFabricService
                    }
                }
            }

            default {
                $sb = {
                    Get-ServiceFabricApplication | Get-ServiceFabricService
                }
            }
        }

        if ($NetworkController) {
            Invoke-SdnServiceFabricCommand -NetworkController $NetworkController -ScriptBlock $sb -Credential $Credential
        }
        else {
            Invoke-SdnServiceFabricCommand -ScriptBlock $sb -Credential $Credential
        }
    }
    catch {
        $_ | Trace-Exception
        $_ | Write-Error
    }
}
