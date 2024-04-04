function Start-SdnMuxCertificateRotation {
    <#
    .SYNOPSIS
        Performs a certificate rotation operation for the Load Balancer Muxes.
    .PARAMETER Credential
        Specifies a user account that has permission to perform this action on the Load Balancer Mux and Network Controller nodes. The default is the current user.
    .PARAMETER NcRestCredential
        Specifies a user account that has permission to access the northbound NC API interface. The default is the current user.
    .PARAMETER GenerateCertificate
        Switch to determine if certificate rotate function should generate self-signed certificates.
    .PARAMETER CertPassword
        SecureString password for accessing the .pfx files, or if using -GenerateCertificate, what the .pfx files will be encrypted with.
    .PARAMETER NotAfter
        Expiration date when using -GenerateCertificate. If ommited, defaults to 3 years.
    .PARAMETER Force
        Switch to force the rotation without being prompted, when Service Fabric is unhealthy.
    #>

    [CmdletBinding(DefaultParameterSetName = 'GenerateCertificate')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'GenerateCertificate')]
        [System.String]$NetworkController = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true, ParameterSetName = 'GenerateCertificate')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter(Mandatory = $false, ParameterSetName = 'GenerateCertificate')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $NcRestCredential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $true, ParameterSetName = 'GenerateCertificate')]
        [Switch]$GenerateCertificate,

        [Parameter(Mandatory = $true, ParameterSetName = 'GenerateCertificate')]
        [System.Security.SecureString]$CertPassword,

        [Parameter(Mandatory = $false, ParameterSetName = 'GenerateCertificate')]
        [datetime]$NotAfter = (Get-Date).AddYears(3),

        [Parameter(Mandatory = $false, ParameterSetName = 'GenerateCertificate')]
        [switch]$Force
    )

    # ensure that the module is running as local administrator
    $elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-NOT $elevated) {
        throw New-Object System.Exception("This function requires elevated permissions. Run PowerShell as an Administrator and import the module again.")
    }

    $config = Get-SdnModuleConfiguration -Role 'NetworkController'
    $confirmFeatures = Confirm-RequiredFeaturesInstalled -Name $config.windowsFeature
    if (-NOT ($confirmFeatures)) {
        throw New-Object System.NotSupportedException("The current machine is not a NetworkController, run this on NetworkController.")
    }

    $array = @()
    $headers = @{"Accept"="application/json"}
    $content = "application/json; charset=UTF-8"

    try {
        "Starting certificate rotation" | Trace-Output
        "Retrieving current SDN environment details" | Trace-Output

        if ([String]::IsNullOrEmpty($CertPath)) {
            [System.String]$CertPath = "$(Get-WorkingDirectory)\MuxCert_{0}" -f (Get-FormattedDateTimeUTC)

            if (-NOT (Test-Path -Path $CertPath -PathType Container)) {
                $null = New-Item -Path $CertPath -ItemType Directory -Force
            }
        }

        [System.IO.FileSystemInfo]$CertPath = Get-Item -Path $CertPath -ErrorAction Stop
        $sdnFabricDetails = Get-SdnInfrastructureInfo -NetworkController $NetworkController -Credential $Credential -NcRestCredential $NcRestCredential -ErrorAction Stop
        $loadBalancerMuxes = Get-SdnLoadBalancerMux -NcUri $sdnFabricDetails.NcUrl -Credential $NcRestCredential -ErrorAction Stop

        # before we proceed with anything else, we want to make sure that all the Network Controllers and MUXes within the SDN fabric are running the current version
        Install-SdnDiagnostics -ComputerName $sdnFabricDetails.NetworkController -ErrorAction Stop
        Install-SdnDiagnostics -ComputerName $sdnFabricDetails.LoadBalancerMux -ErrorAction Stop

        #####################################
        #
        # Create Certificate (Optional)
        #
        #####################################

        if ($PSCmdlet.ParameterSetName -ieq 'GenerateCertificate') {
            "== STAGE: CREATE SELF SIGNED CERTIFICATES ==" | Trace-Output

            # retrieve the corresponding virtualserver reference for each loadbalancermux
            # and invoke remote operation to the mux to generate the self-signed certificate that matches the managementAddress for x509 credentials
            foreach ($muxResource in $loadBalancerMuxes) {
                $virtualServer = Get-SdnResource -NcUri $sdnFabricDetails.NcUrl -ResourceRef $muxResource.properties.virtualServer.resourceRef
                $virtualServerConnection = $virtualServer.properties.connections | Where-Object { $_.credentialType -ieq "X509Certificate" -or $_.credentialType -ieq "X509CertificateSubjectName" }
                $managementAddress = $virtualServerConnection.managementAddresses[0]

                $muxCert = Invoke-PSRemoteCommand -ComputerName $managementAddress -Credential $Credential -ScriptBlock {
                    param(
                        [Parameter(Position = 0)][DateTime]$param1,
                        [Parameter(Position = 1)][PSCredential]$param2,
                        [Parameter(Position = 2)][String]$param3,
                        [Parameter(Position = 3)][System.Object]$param4
                    )

                    New-SdnMuxCertificate -NotAfter $param1 -Credential $param2 -Path $param3 -FabricDetails $param4
                } -ArgumentList @($NotAfter, $Credential, $CertPath.FullName, $sdnFabricDetails)

                $array += [PSCustomObject]@{
                    ManagementAddress = $managementAddress
                    ResourceRef = $virtualServer.resourceRef
                    Certificate = $muxCert.Certificate
                }
            }
        }

        # loop through all the objects to perform PUT operation against the virtualServer resource
        # to update the base64 encoding for the certificate that NC should use when communicating with the virtualServer resource
        foreach ($obj in $array) {
            "Updating certificate information for {0}" -f $obj.ResourceRef | Trace-Output
            $virtualServer = Get-SdnResource -NcUri $sdnFabricDetails.NcUrl -Credential $NcRestCredential -ResourceRef $obj.ResourceRef
            $encoding = [System.Convert]::ToBase64String($obj.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))

            $endpoint = Get-SdnApiEndpoint -NcUri $sdnFabricDetails.NcUrl  -ResourceRef $virtualServer.resourceRef
            if ($virtualServer.properties.certificate) {
                $virtualServer.properties.certificate = $encoding
            }
            else {
                # in instances where the certificate property does not exist, we will need to add it
                # this typically will occur if converting from CA issued certificate to self-signed certificate
                $virtualServer.properties | Add-Member -MemberType NoteProperty -Name 'certificate' -Value $encoding -Force
            }
            $jsonBody = $virtualServer | ConvertTo-Json -Depth 100

            $null = Invoke-RestMethodWithRetry -Method 'Put' -UseBasicParsing -Uri $endpoint -Headers $headers -ContentType $content -Body $jsonBody -Credential $NcRestCredential
            if (-NOT (Confirm-ProvisioningStateSucceeded -Uri $endpoint -Credential $NcRestCredential -UseBasicParsing)) {
                throw New-Object System.Exception("ProvisioningState is not succeeded")
            }
            else {
                "Successfully updated the certificate information for {0}" -f $obj.ResourceRef | Trace-Output
            }

            # after we have generated the certificates and updated the servers to use the new certificate
            # we will want to go and locate certificates that may conflict with the new certificate
            "Checking certificates on {0} that match {1}" -f $obj.managementAddress, $obj.Certificate.Subject | Trace-Output
            $certsToExamine = Invoke-PSRemoteCommand -ComputerName $obj.managementAddress -Credential $Credential -ScriptBlock {
                param([Parameter(Mandatory = $true)]$param1)
                $certs = Get-SdnCertificate -Path 'Cert:\LocalMachine\My' -Subject $param1.Subject
                if ($certs.Count -ge 2) {
                    $certToRemove = $certs | Where-Object {$_.Thumbprint -ine $param1.Thumbprint}

                    return $certToRemove
                }
            } -ArgumentList $obj.Certificate

            if ($certsToExamine) {
                foreach ($cert in $certsToExamine) {
                    "Examine certificate subject {0} and thumbprint {1} on {2} and remove if no longer needed" -f $cert.Subject, $cert.Thumbprint, $obj.managementAddress | Trace-Output -Level:Warning
                }
            }

            # restart the slb mux service on the mux
            $null = Invoke-PSRemoteCommand -ComputerName $obj.managementAddress -Credential $Credential -ScriptBlock {
                Restart-Service -Name SlbMux -Force
            }
        }

        "Certificate rotation for Load Balancer Muxes has completed" | Trace-Output -Level:Success
    }
    catch {
        $_ | Trace-Exception
        $_ | Write-Error
    }
}