# Module manifest for diagnostics for Software Defined Networking.
#
# Copyright='© Microsoft Corporation. All rights reserved.'
# Licensed under the MIT License.

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'SdnDiag.Gateway.psm1'

    # Author of this module
    Author = 'Adam Rudell'

    # Company or vendor of this module
    CompanyName = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright = '(c) Microsoft Corporation. All rights reserved.'

    # Version number of this module.
    ModuleVersion = '1.0.0.0'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'SdnDiag.Gateway.Helper.psm1'
        'SdnDiag.Gateway.Health.psm1'
        'SdnDiag.Gateway.Tracing.psm1'
    )

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Functions to export from this module
    FunctionsToExport = @(
        'Disable-SdnRasGatewayTracing'
        'Enable-SdnRasGatewayTracing'
        'Get-SdnGatewayConfigurationState'
        'Test-SdnGatewayConfigState'
        'Test-SdnGatewayServiceState'
    )

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @()

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/microsoft/SdnDiagnostics'

            # A URL to the license for this module.
            LicenseUri = 'https://microsoft.mit-license.org/'

            # External dependent modules of this module
            ExternalModuleDependencies = @()
        }
    }
}
