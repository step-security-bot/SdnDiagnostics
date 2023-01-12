# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Update-NetworkControllerCertificateInManifest {
    <#
    .SYNOPSIS
        Update Network Controller Manifest File with new Network Controller Certificate.
    .PARAMETER NcVMs
        The list of Network Controller VMs.
    .PARAMETER ManifestFolder
        The Manifest Folder contains the orginal Manifest Files.
    .PARAMETER ManifestFolderNew
        The New Manifest Folder contains the new Manifest Files. Updated manifest file save here.
    .PARAMETER CertRotateConfig
        The Config generated by New-SdnCertificateRotationConfig to include NC REST certificate thumbprint and node certificate thumbprint.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]
        $NcNodeList,
        [Parameter(Mandatory = $true)]
        [String]
        $ManifestFolder,
        [Parameter(Mandatory = $true)]
        [String]
        $ManifestFolderNew,
        [Parameter(Mandatory = $true)]
        [hashtable]
        $CertRotateConfig,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    if ($NcNodeList.Count -eq 0) {
        throw New-Object System.NotSupportedException("NcNodeList is empty")
    }

    # Prepare the cert thumbprint to be used
    # Update certificates ClusterManifest.current.xml
    
    $clusterManifestXml = [xml](Get-Content "$ManifestFolder\ClusterManifest.current.xml")

    if ($null -eq $clusterManifestXml) {
        Trace-Output "ClusterManifest not found at $ManifestFolder\ClusterManifest.current.xml" -Level:Error
        throw 
    }

    $NcRestCertThumbprint = $CertRotateConfig["NcRestCert"]

    # Update encrypted secret
    # Get encrypted secret from Cluster Manifest
    $fileStoreServiceSection = ($clusterManifestXml.ClusterManifest.FabricSettings.Section | Where-Object name -eq FileStoreService)
    $OldEncryptedSecret = ($fileStoreServiceSection.Parameter | Where-Object Name -eq "PrimaryAccountNTLMPasswordSecret").Value
    $newEncryptedSecret = New-NetworkControllerClusterSecret -OldEncryptedSecret $OldEncryptedSecret -NcRestCertThumbprint $NcRestCertThumbprint -Credential $Credential

    # Update new encrypted secret in Cluster Manifest
    ($fileStoreServiceSection.Parameter | Where-Object Name -eq "PrimaryAccountNTLMPasswordSecret").Value = "$newEncryptedSecret"
    ($fileStoreServiceSection.Parameter | Where-Object Name -eq "SecondaryAccountNTLMPasswordSecret").Value = "$newEncryptedSecret"
    
    # Update SecretsCertificate to new REST Cert
    
    Trace-Output "Updating SecretsCertificate with new rest cert thumbprint $NcRestCertThumbprint"
    $clusterManifestXml.ClusterManifest.Certificates.SecretsCertificate.X509FindValue = "$NcRestCertThumbprint"
    
    $securitySection = $clusterManifestXml.ClusterManifest.FabricSettings.Section | Where-Object Name -eq "Security"
    $ClusterCredentialType = $securitySection.Parameter | Where-Object Name -eq "ClusterCredentialType"

    $infrastructureManifestXml = [xml](Get-Content "$ManifestFolder\InfrastructureManifest.xml")

    # Update Node Certificate to new Node Cert if the ClusterCredentialType is X509 certificate
    if($ClusterCredentialType.Value -eq "X509")
    {
        foreach ($node in $clusterManifestXml.ClusterManifest.NodeTypes.NodeType) {
            $ncNode = $node.Name
            $ncNodeCertThumbprint = $CertRotateConfig[$ncNode.ToLower()]
            Write-Verbose "Updating node $ncNode with new thumbprint $ncNodeCertThumbprint"
            $node.Certificates.ClusterCertificate.X509FindValue = "$ncNodeCertThumbprint"
            $node.Certificates.ServerCertificate.X509FindValue = "$ncNodeCertThumbprint"
            $node.Certificates.ClientCertificate.X509FindValue = "$ncNodeCertThumbprint"
        }

        # Update certificates InfrastructureManifest.xml
        
        foreach ($node in $infrastructureManifestXml.InfrastructureInformation.NodeList.Node) {
            $ncNodeCertThumbprint = $CertRotateConfig[$node.NodeName.ToLower()]
            $node.Certificates.ClusterCertificate.X509FindValue = "$ncNodeCertThumbprint"
            $node.Certificates.ServerCertificate.X509FindValue = "$ncNodeCertThumbprint"
            $node.Certificates.ClientCertificate.X509FindValue = "$ncNodeCertThumbprint"
        }
    }

    # Update certificates for settings.xml
    foreach ($ncNode in $NcNodeList) {
        $ncVm = $ncNode.IpAddressOrFQDN
        $settingXml = [xml](Get-Content "$ManifestFolder\$ncVm\Settings.xml")
        if($ClusterCredentialType.Value -eq "X509")
        {
            $ncNodeCertThumbprint = $CertRotateConfig[$ncNode.NodeName.ToLower()]
            $fabricNodeSection = $settingXml.Settings.Section | Where-Object Name -eq "FabricNode"
            $parameterToUpdate = $fabricNodeSection.Parameter | Where-Object Name -eq "ClientAuthX509FindValue"
            $parameterToUpdate.Value = "$ncNodeCertThumbprint"
            $parameterToUpdate = $fabricNodeSection.Parameter | Where-Object Name -eq "ServerAuthX509FindValue"
            $parameterToUpdate.Value = "$ncNodeCertThumbprint"
            $parameterToUpdate = $fabricNodeSection.Parameter | Where-Object Name -eq "ClusterX509FindValue"
            $parameterToUpdate.Value = "$ncNodeCertThumbprint"
        }

        # Update encrypted secret in settings.xml
        $fileStoreServiceSection = $settingXml.Settings.Section | Where-Object Name -eq "FileStoreService"
        ($fileStoreServiceSection.Parameter | Where-Object Name -eq "PrimaryAccountNTLMPasswordSecret").Value = "$newEncryptedSecret"
        ($fileStoreServiceSection.Parameter | Where-Object Name -eq "SecondaryAccountNTLMPasswordSecret").Value = "$newEncryptedSecret" 

        $settingXml.Save("$ManifestFolderNew\$ncVm\Settings.xml")
    }

    $infrastructureManifestXml.Save("$ManifestFolderNew\InfrastructureManifest.xml")
    $clusterManifestXml.Save("$ManifestFolderNew\ClusterManifest.current.xml")
}