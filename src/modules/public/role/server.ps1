function Get-OvsdbAddressMapping {
    <#
    .SYNOPSIS
        Returns a list of address mappings from within the SDN OVSDB servers
    #>

    try {
        $arrayList = [System.Collections.ArrayList]::new()

        $ovsdbResults = Get-OvsdbDatabase -Table ms_vtep
        $paMappingTable = $ovsdbResults | Where-Object {$_.caption -eq 'Physical_Locator table'}
        $caMappingTable = $ovsdbResults | Where-Object {$_.caption -eq 'Ucast_Macs_Remote table'}
        $logicalSwitchTable = $ovsdbResults | Where-Object {$_.caption -eq 'Logical_Switch table'}

        # enumerate the json rules for each of the tables and create psobject for the mappings
        # unfortunately these values do not return in key/value pair and need to manually map each property
        foreach($caMapping in $caMappingTable.Data){
            $mac = $caMapping[0]
            $uuid = $caMapping[1][1]
            $ca = $caMapping[2]
            $locator = $caMapping[3][1]
            $logicalSwitch = $caMapping[4][1]
            $mappingType = $caMapping[5]

            $pa = [string]::Empty
            $encapType = [string]::Empty
            $rdid = [string]::Empty
            $vsid = 0

            # Get PA from locator table
            foreach($paMapping in $paMappingTable.Data){
                $curLocator = $paMapping[0][1]
                if($curLocator -eq $locator){
                    $pa = $paMapping[3]
                    $encapType = $paMapping[4]
                    break
                }
            }

            # Get Rdid and VSID from logical switch table
            foreach($switch in $logicalSwitchTable.Data){
                $curSwitch = $switch[0][1]
                if($curSwitch -eq $logicalSwitch){
                    $rdid = $switch[1]
                    $vsid = $switch[3]
                    break
                }
            }

            # create the psobject now that we have all the mappings identified
            $result = New-Object PSObject -Property @{
                UUID = $uuid
                CustomerAddress = $ca 
                ProviderAddress = $pa 
                MAC = $mac
                RoutingDomainID = $rdid
                VirtualSwitchID = $vsid
                MappingType = $mappingType
                EncapType = $encapType
            }

            # add the psobject to the array
            [void]$arrayList.Add($result)
        }

        return $arrayList
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-OvsdbFirewallRuleTable {
    <#
    .SYNOPSIS
        Returns a list of firewall rules from the SDN OVSDB servers
    #>

    try {
        $arrayList = [System.Collections.ArrayList]::new()

        $ovsdbResults = Get-OvsdbDatabase -Table ms_firewall
        $firewallTable = $ovsdbResults | Where-Object {$_.caption -eq 'FW_Rules table'}

        # enumerate the json rules and create object for each firewall rule returned
        # there is no nice way to generate this and requires manually mapping as only the values are return
        foreach($obj in $firewallTable.data){
            $result = New-Object PSObject -Property @{
                uuid = $obj[0][1]
                action = $obj[1]
                direction = $obj[2]
                dst_ip_addresses = $obj[3]
                dst_ports = $obj[4]
                logging_state = $obj[5]
                priority = $obj[6]
                protocols = $obj[7]
                rule_id = $obj[8]
                rule_state = $obj[9]
                rule_type = $obj[10]
                src_ip_addresses = $obj[11]
                src_ports = $obj[12]
                vnic_id = $obj[13].Trim('{','}')
            }

            # add the psobject to array list
            [void]$arrayList.Add($result)
        }
        
        return $arrayList
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-OvsdbPhysicalPortTable {
    <#
    .SYNOPSIS
        Returns a list of ports from within the SDN OVSDB servers
    #>

    try {
        $arrayList = [System.Collections.ArrayList]::new()

        $ovsdbResults = Get-OvsdbDatabase -Table ms_vtep
        $portTable = $ovsdbResults | Where-Object {$_.caption -eq 'Physical_Port table'}

        # enumerate the json objects and create psobject for each port
        foreach($obj in $portTable.data){
            $result = New-Object PSObject -Property @{
                uuid = $obj[0][1]
                description = $obj[1]
                name = $obj[2].Trim('{','}')
            }
            # there are numerous key/value pairs within this object with some having different properties
            # enumerate through the properties and add property and value for each on that exist
            foreach($property in $obj[4][1]){
                $result | Add-Member -MemberType NoteProperty -Name $property[0] -Value $property[1]
            }
            
            # add the psobject to array
            [void]$arrayList.Add($result)
        }

        return $arrayList
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-OvsdbUcastMacRemoteTable {
    <#
    .SYNOPSIS
        Returns a list of mac addresses defined within the Ucast_Macs_Remote table
    #>

    try {
        $arrayList = [System.Collections.ArrayList]::new()

        $ovsdbResults = Get-OvsdbDatabase -Table ms_vtep
        $ucastMacsRemoteTable = $ovsdbResults | Where-Object {$_.caption -eq 'Ucast_Macs_Remote table'}

        # enumerate the json objects and create psobject for each port
        foreach($obj in $ucastMacsRemoteTable.data){
            $result = New-Object PSObject -Property @{
                uuid = $obj[1][1]
                mac = $obj[0]
                ipaddr = $obj[2]
                locator = $obj[3][1]
                logical_switch = $obj[4][1]
                mapping_type = $obj[5]
            }

            [void]$arrayList.Add($result)
        }

        return $arrayList
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-OvsdbGlobalTable {
    <#
    .SYNOPSIS
        Returns the global table configuration from OVSDB
    #>

    try {      
        $arrayList = [System.Collections.ArrayList]::new()

        $ovsdbResults = Get-OvsdbDatabase -Table ms_vtep
        $globalTable = $ovsdbResults | Where-Object {$_.caption -eq 'Global table'}

        # enumerate the json results and add to psobject
        foreach($obj in $globalTable.data){
            $result = New-Object PSObject -Property @{
                uuid = $obj[0][1]
                cur_cfg = $obj[1]
                next_cfg = $obj[4]
                switches = $obj[6][1]
            }
            # add the psobject to array
            [void]$arrayList.Add($result)
        }

        return $arrayList
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-VfpVmSwitchPorts {
    <#
    .SYNOPSIS
        Returns a list of ports from within VFP
    #>

    try {
        $arrayList = [System.Collections.ArrayList]::new()
    
        $vfpResults = vfpctrl /list-vmswitch-port
        if(!$vfpResults){
            $msg = "Unable to retrieve vmswitch ports from vfpctrl`n{0}" -f $_
            throw New-Object System.NullReferenceException($msg)
        }

        foreach($line in $vfpResults){
            # lines in the VFP output that contain : contain properties and values
            # need to split these based on count of ":" to build key and values
            if($line.Contains(":")){
                $results = $line.Split(":").Trim().Replace(" ","")
                if($results.Count -eq 3){
                    $key = "$($results[0])-$($results[1])"
                    $value = $results[2]        
                }
                elseif($results.Count -eq 2){
                    $key = $results[0]
                    $value = $results[1] 
                }

                # all ports begin with this property and value so need to create a new psobject when we see these keys
                if($key -eq "Portname"){
                    $port = New-Object -TypeName PSObject
                }

                # add the line values to the object
                $port | Add-Member -MemberType NoteProperty -Name $key -Value $value
            }

            # all the ports are seperated with a blank line
            # use this as our end of properties to add the current obj to the array list
            if([string]::IsNullOrEmpty($line)){
                if($port){
                    [void]$arrayList.Add($port)
                }
            }
        }

        return $arrayList
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-VfpPortLayer {
    param (
        [Parameter(Mandatory = $true)]
        [GUID]$PortId,

        [Parameter(Mandatory = $false)]
        [System.String]$Name
    )

    try {
        $arrayList = [System.Collections.ArrayList]::new()
        $vfpLayers = vfpctrl /list-layer /port $PortId

        foreach($line in $vfpLayers){
            # lines in the VFP output that contain : contain properties and values
            # need to split these based on count of ":" to build key and values
            if($line.Contains(':')){
                [System.String[]]$results = $line.Split(':').Trim()
                if($results.Count -eq 2){
                    $key = $results[0]

                    # if the key is priority, we want to declare the value as an int value so we can properly sort the results
                    if($key -ieq 'Priority'){
                        [int]$value = $results[1] 
                    }
                    else {
                        [System.String]$value = $results[1]
                    }
                }
        
                # all layers begin with this property and value so need to create a new psobject when we see these keys
                if($key -ieq 'Layer'){
                    $object = New-Object -TypeName PSObject
                }
        
                # add the line values to the object
                $object | Add-Member -MemberType NoteProperty -Name $key -Value $value
            }
        
            # all the layers are seperated with a blank line
            # use this as our end of properties to add the current obj to the array list
            if([string]::IsNullOrEmpty($line)){
                if($object){
                    [void]$arrayList.Add($object)
                }
            }
        }
        
        if($Name){
            return ($arrayList | Where-Object {$_.LAYER -eq $Name})
        }
        else {
            return ($arrayList | Sort-Object -Property Priority)
        }
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-VfpPortGroup {
    param (
        [Parameter(Mandatory = $true)]
        [GUID]$PortId,

        [Parameter(Mandatory = $true)]
        [System.String]$Layer,

        [Parameter(Mandatory = $false)]
        [System.String]$Name
    )

    try {
        $arrayList = [System.Collections.ArrayList]::new()
        $vfpGroups = vfpctrl /list-group /port $PortId /layer $Layer

        foreach($line in $vfpGroups){

            # in situations where the value might be nested in another line we need to do some additional data processing
            # subvalues is declared below if the value is null after the split
            if($subValues){
                if(!$subArrayList){
                    $subArrayList = [System.Collections.ArrayList]::new()
                }

                # if we hit here, we have captured all of the conditions within the group that need processing
                # and we can now add the arraylist to the object and null out the values
                if($line.Contains('Match type')){
                    $object | Add-Member -NotePropertyMembers $subArrayList -TypeName $key

                    $subValues = $false
                    $subArrayList = $null
                }
                else {
                    if($line.Contains(':')){
                        [System.String[]]$results = $line.Split(':').Trim()
                        if($results.Count -eq 2){
                            $subObject = @{
                                $results[0] = $results[1]
                            }

                            [void]$subArrayList.Add($subObject)

                            continue
                        }
                    }
                    elseif($line.Contains('<none>')){
                        $object | Add-Member -MemberType NoteProperty -Name $key -Value $null
    
                        $subValues = $false
                        $subArrayList = $null
    
                        continue
                    }
                    else {
                        $object | Add-Member -MemberType NoteProperty -Name $key -Value $line.Trim()
                        
                        $subValues = $false
                        $subArrayList = $null

                        continue
                    }
                }
            }

            # lines in the VFP output that contain : contain properties and values
            # need to split these based on count of ":" to build key and values
            if($line.Contains(':')){
                [System.String[]]$results = $line.Split(':').Trim()
                if($results.Count -eq 2){
                    $key = $results[0]

                    # if the key is priority, we want to declare the value as an int value so we can properly sort the results
                    if($key -ieq 'Priority'){
                        [int]$value = $results[1] 
                    }
                    else {

                        # if we split the object and the second object is null or white space
                        # we can assume that the lines below it have additional data we need to capture and as such
                        # need to do further processing
                        if([string]::IsNullOrWhiteSpace($results[1])){
                            $subValues = $true
                            continue
                        }

                        [System.String]$value = $results[1]
                    }
                }
        
                # all groups begin with this property and value so need to create a new psobject when we see these keys
                if($key -ieq 'Group'){
                    $object = New-Object -TypeName PSObject
                }
        
                # add the line values to the object
                $object | Add-Member -MemberType NoteProperty -Name $key -Value $value
            }
        
            # all the groups are seperated with a blank line
            # use this as our end of properties to add the current obj to the array list
            if([string]::IsNullOrEmpty($line)){
                if($object){
                    [void]$arrayList.Add($object)
                }
            }
        }
        
        if($Name){
            return ($arrayList | Where-Object {$_.GROUP -eq $Name})
        }
        else {
            return ($arrayList | Sort-Object -Property Priority)
        }
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-VfpPortRule {
    param (
        [Parameter(Mandatory = $true)]
        [GUID]$PortId,

        [Parameter(Mandatory = $true)]
        [System.String]$Layer,

        [Parameter(Mandatory = $true)]
        [System.String]$Group,

        [Parameter(Mandatory = $false)]
        [System.String]$Name
    )

    try {
        $arrayList = [System.Collections.ArrayList]::new()
        $vfpRules = vfpctrl /list-rule /port $PortId /layer $Layer /group $Group

        foreach($line in $vfpRules){

            # in situations where the value might be nested in another line we need to do some additional data processing
            # subvalues is declared below if the value is null after the split
            if($subValues){
                if(!$subArrayList){
                    $subArrayList = [System.Collections.ArrayList]::new()
                }

                # if we hit here, we have captured all of the conditions within the group that need processing
                # and we can now add the arraylist to the object and null out the values
                if($line.Contains('Match type')){
                    $object | Add-Member -NotePropertyMembers $subArrayList -TypeName $key

                    $subValues = $false
                    $subArrayList = $null
                }
                else {
                    if($line.Contains(':')){
                        [void]$subArrayList.Add($line.trim())
                        continue
                    }
                    elseif($line.Contains('<none>')){
                        $object | Add-Member -MemberType NoteProperty -Name $key -Value $null
    
                        $subValues = $false
                        $subArrayList = $null
    
                        continue
                    }
                    else {
                        $object | Add-Member -MemberType NoteProperty -Name $key -Value $line.Trim()
                        
                        $subValues = $false
                        $subArrayList = $null

                        continue
                    }
                }
            }

            # lines in the VFP output that contain : contain properties and values
            # need to split these based on count of ":" to build key and values
            if($line.Contains(':')){
                [System.String[]]$results = $line.Split(':').Trim()
                if($results.Count -eq 2){
                    $key = $results[0]

                    # all groups begin with this property and value so need to create a new psobject when we see these keys
                    if($key -ieq 'RULE'){
                        $object = New-Object -TypeName PSObject
                        continue
                    }

                    # if the key is priority, we want to declare the value as an int value so we can properly sort the results
                    if($key -ieq 'Priority'){
                        [int]$value = $results[1] 
                    }
                    else {

                        # if we split the object and the second object is null or white space
                        # we can assume that the lines below it have additional data we need to capture and as such
                        # need to do further processing
                        if([string]::IsNullOrWhiteSpace($results[1])){
                            $subValues = $true
                            continue
                        }

                        [System.String]$value = $results[1]
                    }
                }
        
                # add the line values to the object
                $object | Add-Member -MemberType NoteProperty -Name $key -Value $value
            }
        
            # all the groups are seperated with a blank line
            # use this as our end of properties to add the current obj to the array list
            if([string]::IsNullOrEmpty($line)){
                if($object){
                    [void]$arrayList.Add($object)
                }
            }
        }
        
        if($Name){
            # return ($arrayList | Where-Object {$_.GROUP -eq $Name})
        }
        else {
            return ($arrayList | Sort-Object -Property Priority)
        }
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}

function Get-SdnServerConfigurationState {
    <#
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$OutputDirectory
    )

    $ProgressPreference = 'SilentlyContinue'

    try {
        $config = Get-SdnRoleConfiguration -Role:Server

        # ensure that the appropriate windows feature is installed and ensure module is imported
        $confirmFeatures = Confirm-RequiredFeaturesInstalled -Name $config.windowsFeature
        if(!$confirmFeatures){
            throw New-Object System.Exception("Required feature is missing")
        }

        $confirmModules = Confirm-RequiredModulesLoaded -Name $config.requiredModules
        if(!$confirmModules){
            throw New-Object System.Exception("Required module is not loaded")
        }

        # create the OutputDirectory if does not already exist
        if(!(Test-Path -Path $OutputDirectory.FullName -PathType Container)){
            $null = New-Item -Path $OutputDirectory.FullName -ItemType Directory -Force
        }

        # dump out the regkey properties
        Export-RegistryKeyConfigDetails -Path $config.properties.regKeyPaths -OutputDirectory (Join-Path -Path $OutputDirectory.FullName -ChildPath "Registry")

        # Gather VFP port configuration details
        "Gathering VFP port details" | Trace-Output -Level:Verbose
        foreach ($vm in (Get-WmiObject -na root\virtualization\v2 msvm_computersystem)){
            foreach ($vma in $vm.GetRelated("Msvm_SyntheticEthernetPort")){
                foreach ($port in $vma.GetRelated("Msvm_SyntheticEthernetPortSettingData").GetRelated("Msvm_EthernetPortAllocationSettingData").GetRelated("Msvm_EthernetSwitchPort")){
                    
                    $outputDir = New-Item -Path (Join-Path -Path $OutputDirectory.FullName -ChildPath "VFP\$($vm.ElementName)") -ItemType Directory -Force
                    vfpctrl /list-nat-range /port $($port.Name) | Export-ObjectToFile -FilePath $outputDir.FullName -Prefix 'NatInfo' -Name $port.Name -FileType txt
                    vfpctrl /list-rule /port $($port.Name) | Export-ObjectToFile -FilePath $outputDir.FullName -Prefix 'RuleInfo' -Name $port.Name -FileType txt
                    vfpctrl /list-mapping /port $($port.Name) | Export-ObjectToFile -FilePath $outputDir.FullName -Prefix 'ListMapping' -Name $port.Name -FileType txt
                }
            }
        }

        vfpctrl /list-vmswitch-port | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'vfpctrl_list-vmswitch-port' -FileType json

        # Gather OVSDB databases
        "Gathering ovsdb database output" | Trace-Output -Level:Verbose
        ovsdb-client.exe dump tcp:127.0.0.1:6641 ms_vtep | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'ovsdb_vtep' -FileType txt
        ovsdb-client.exe dump tcp:127.0.0.1:6641 ms_firewall | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'ovsdb_firewall' -FileType txt

        # Gather Hyper-V network details
        "Gathering hyper-v configuration details" | Trace-Output -Level:Verbose
        Get-PACAMapping | Sort-Object PSComputerName | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'Get-PACAMapping' -FileType txt -Format Table
        Get-ProviderAddress | Sort-Object PSComputerName | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'Get-ProviderAddress' -FileType txt -Format Table
        Get-CustomerRoute | Sort-Object PSComputerName | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'Get-CustomerRoute' -FileType txt -Format Table
        Get-NetAdapterVPort | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'Get-NetAdapterVPort' -FileType txt -Format Table
        Get-NetAdapterVmqQueue | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'Get-NetAdapterVmqQueue' -FileType txt -Format Table
        Get-VMSwitch | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'Get-VMSwitch' -FileType txt -Format List 
        Get-VMSwitchTeam | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'Get-VMSwitchTeam' -FileType txt -Format List
        Get-VMNetworkAdapterPortProfile -AllVMs | Export-ObjectToFile -FilePath $OutputDirectory.FullName -Name 'Get-VMNetworkAdapterPortProfile' -FileType txt -Format Table

        Get-GeneralConfigurationState -OutputDirectory $OutputDirectory.FullName
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }

    $ProgressPreference = 'Continue'
}

function Get-VMNetworkAdapterPortProfile {
    <#
    #>

    [CmdletBinding(DefaultParameterSetName = 'SingleVM')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleVM')]
        [System.String]$VMName,

        [Parameter(Mandatory = $true, ParameterSetName = 'AllVMs')]
        [Switch]$AllVMs,

        [Parameter(Mandatory = $false, ParameterSetName = 'SingleVM')]
        [Parameter(Mandatory = $false, ParameterSetName = 'AllVMs')]
        [System.Guid]$PortProfileFeatureId = '9940cd46-8b06-43bb-b9d5-93d50381fd56'
    )

    try {

        if($null -eq (Get-Module -Name Hyper-V)){
            Import-Module -Name Hyper-V -Force
        }

        $arrayList = [System.Collections.ArrayList]::new()

        if($AllVMs){
            $netAdapters = Get-VMNetworkAdapter -All
        }
        else {
            $netAdapters = Get-VMNetworkAdapter -VMName $VMName
        }

        foreach($adapter in $netAdapters | Where-Object {$_.IsManagementOs -eq $false}){
            $currentProfile = Get-VMSwitchExtensionPortFeature -FeatureId $PortProfileFeatureId -VMNetworkAdapter $adapter

            if($null -eq $currentProfile){
                "{0} does not have a port profile" -f $adapter.Name | Trace-Output -Level:Warning
            }
            else {
                $arrayList += [PSCustomObject]@{
                    Name = $adapter.Name
                    MacAddress = $adapter.MacAddress
                    Id = $currentProfile.SettingData.ProfileId
                    Data = $currentProfile.SettingData.ProfileData
                }
            }
        }

        return ($arrayList | Sort-Object -Property Name)
    }
    catch {
        "{0}`n{1}" -f $_.Exception, $_.ScriptStackTrace | Trace-Output -Level:Error
    }
}