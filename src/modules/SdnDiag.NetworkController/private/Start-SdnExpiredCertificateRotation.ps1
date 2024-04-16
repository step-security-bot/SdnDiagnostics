function Start-SdnExpiredCertificateRotation {
    <#
    .SYNOPSIS
        Start the Network Controller Certificate Update.
    .DESCRIPTION
        Start the Network Controller Certificate Update.
        This will use the latest issued certificate on each of the NC VMs to replace existing certificates. Ensure below before execute this command:
        - NC Rest Certificate and NC Node certificate created on each NC and trusted.
        - "Network Service" account have read access to the private file of the new certificates.
        - NC Rest Certificate need to be trusted by all SLB MUX VMs and SDN Hosts.

        For Self-Signed Certificate. This can also be created by 'New-NetworkControllerCertificate'. To get more details, run 'Get-Help New-NetworkControllerCertificate'

        About SDN Certificate Requirement:
        https://docs.microsoft.com/en-us/windows-server/networking/sdn/security/sdn-manage-certs

    .PARAMETER CertRotateConfig
        The Config generated by New-SdnCertificateRotationConfig to include NC REST certificate thumbprint and node certificate thumbprint.
    .EXAMPLE
        Start-SdnExpiredCertificateRotation -NetworkController nc01
    #>

    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $CertRotateConfig,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $NcRestCredential = [System.Management.Automation.PSCredential]::Empty
    )

    $NcUpdateFolder = "$(Get-WorkingDirectory)\NcCertUpdate_{0}" -f (Get-FormattedDateTimeUTC)
    $ManifestFolder = "$NcUpdateFolder\manifest"
    $ManifestFolderNew = "$NcUpdateFolder\manifest_new"

    $NcInfraInfo = Get-SdnNetworkControllerInfoOffline -Credential $Credential
    Trace-Output -Message "Network Controller Infrastrucutre Info detected:"
    Trace-Output -Message "ClusterCredentialType: $($NcInfraInfo.ClusterCredentialType)"
    Trace-Output -Message "NcRestName: $($NcInfraInfo.NcRestName)"

    $NcNodeList = $NcInfraInfo.NodeList

    if ($null -eq $NcNodeList -or $NcNodeList.Count -eq 0) {
        throw "Failed to get NC Node List from NetworkController: $($env:COMPUTERNAME)"
    }

    Trace-Output -Message "NcNodeList: $($NcNodeList.IpAddressOrFQDN)"
    Trace-Output -Message "Validate CertRotateConfig"
    if(!(Test-SdnCertificateRotationConfig -NcNodeList $NcNodeList -CertRotateConfig $CertRotateConfig -Credential $Credential)){
        throw "Invalid CertRotateConfig, please correct the configuration and try again"
    }

    if ([String]::IsNullOrEmpty($NcInfraInfo.NcRestName)) {
        Trace-Output -Message "Failed to get NcRestName using current secret certificate thumbprint. This might indicate the certificate not found on $(HOSTNAME). We won't be able to recover." -Level:Error
        throw New-Object System.NotSupportedException("Current Network Controller Rest certificate not found.")
    }

    $NcVms = $NcNodeList.IpAddressOrFQDN

    if (Test-Path -Path $NcUpdateFolder) {
        $items = Get-ChildItem -Path $NcUpdateFolder -ErrorAction Ignore
        if ($items.Count -gt 0) {
            $confirmCleanup = Read-Host "The Folder $NcUpdateFolder not empty. Need to be cleared. Enter Y to confirm"
            if ($confirmCleanup -eq "Y") {
                $items | Remove-Item -Force -Recurse
            }
            else {
                return
            }
        }
    }

    foreach ($nc in $NcVms) {
        Invoke-Command -ComputerName $nc -ScriptBlock {
            Write-Host "[$(HostName)] Stopping Service Fabric Service"
            Stop-Service FabricHostSvc -Force
        }
    }

    Trace-Output -Message "Step 1 Copy manifests and settings.xml from Network Controller"
    Copy-ServiceFabricManifestFromNetworkController -NcNodeList $NcNodeList -ManifestFolder $ManifestFolder -ManifestFolderNew $ManifestFolderNew -Credential $Credential

    # Step 2 Update certificate thumbprint
    Trace-Output -Message "Step 2 Update certificate thumbprint and secret in manifest"
    Update-NetworkControllerCertificateInManifest -NcNodeList $NcNodeList -ManifestFolder $ManifestFolder -ManifestFolderNew $ManifestFolderNew -CertRotateConfig $CertRotateConfig -Credential $Credential

    # Step 3 Copy the new files back to the NC vms
    Trace-Output -Message "Step 3 Copy the new files back to the NC vms"
    Copy-ServiceFabricManifestToNetworkController -NcNodeList $NcNodeList -ManifestFolder $ManifestFolderNew -Credential $Credential

    # Step 5 Start FabricHostSvc and wait for SF system service to become healty
    Trace-Output -Message "Step 4 Start FabricHostSvc and wait for SF system service to become healty"
    Trace-Output -Message "Step 4.1 Update Network Controller Certificate ACL to allow 'Network Service' Access"
    Update-NetworkControllerCertificateAcl -NcNodeList $NcNodeList -CertRotateConfig $CertRotateConfig -Credential $Credential
    Trace-Output -Message "Step 4.2 Start Service Fabric Host Service and wait"
    $clusterHealthy = Wait-ServiceFabricClusterHealthy -NcNodeList $NcNodeList -CertRotateConfig $CertRotateConfig -Credential $Credential
    Trace-Output -Message "ClusterHealthy: $clusterHealthy"
    if($clusterHealthy -ne $true){
        throw New-Object System.NotSupportedException("Cluster unheathy after manifest update, we cannot continue with current situation")
    }
    # Step 6 Invoke SF Cluster Upgrade
    Trace-Output -Message "Step 5 Invoke SF Cluster Upgrade"
    Update-ServiceFabricCluster -NcNodeList $NcNodeList -CertRotateConfig $CertRotateConfig -ManifestFolderNew $ManifestFolderNew -Credential $Credential
    $clusterHealthy = Wait-ServiceFabricClusterHealthy -NcNodeList $NcNodeList -CertRotateConfig $CertRotateConfig -Credential $Credential
    Trace-Output -Message "ClusterHealthy: $clusterHealthy"
    if($clusterHealthy -ne $true){
        throw New-Object System.NotSupportedException("Cluster unheathy after cluster update, we cannot continue with current situation")
    }

    # Step 7 Fix NC App
    Trace-Output -Message "Step 6 Fix NC App"
    Trace-Output -Message "Step 6.1 Updating Network Controller Global and Cluster Config"
    if ($NcInfraInfo.ClusterCredentialType -eq "X509") {
        Update-NetworkControllerConfig -NcNodeList $NcNodeList -CertRotateConfig $CertRotateConfig -Credential $Credential
    }

    # Step 7 Restart
    Trace-Output -Message "Step 7 Restarting Service Fabric Cluster after configuration change"
    $clusterHealthy = Wait-ServiceFabricClusterHealthy -NcNodeList $NcNodeList -CertRotateConfig $CertRotateConfig -Credential $Credential -Restart
}
