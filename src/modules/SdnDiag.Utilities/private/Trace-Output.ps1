function Trace-Output {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Message')]
        [System.String]$Message,

        [Parameter(Mandatory = $false, ParameterSetName = 'Message')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Exception')]
        [TraceLevel]$Level = 'Information',

        [Parameter(Mandatory = $false, ParameterSetName = 'Message')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Exception')]
        [System.String]$FunctionName = (Get-PSCallStack)[0].Command,

        [parameter(Mandatory = $true, ParameterSetName = 'Exception')]
        $Exception
    )

    begin {
        $traceFile = (Get-TraceOutputFile)
        if ([string]::IsNullOrEmpty($traceFile)) {
            New-WorkingDirectory

            $traceFile = (Get-TraceOutputFile)
        }
    }
    process {
        # create custom object for formatting purposes
        $traceEvent = [PSCustomObject]@{
            Computer = $env:COMPUTERNAME.ToUpper().ToString()
            TimestampUtc = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH-mm-ss')
            FunctionName = $FunctionName
            Level = $Level.ToString()
            Message = $null
        }

        switch ($PSCmdlet.ParameterSetName) {
            'Message' {
                $traceEvent.Message = $Message
            }
            'Exception' {
                $traceEvent.Message = "{0}`n{1}" -f $Exception.Exception, $Exception.ScriptStackTrace
            }
        }

        $formattedMessage = "[{0}] {1}" -f $traceEvent.Computer, $traceEvent.Message

        # write the message to the console
        switch($Level){
            'Error' {
                $formattedMessage | Write-Host -ForegroundColor:Red
            }

            'Exception' {
                # do nothing here, as the exception should be written to the console by the caller using Write-Error
                # as this will preserve the proper call stack tracing
            }

            'Success' {
                $formattedMessage  | Write-Host -ForegroundColor:Green
            }

            'Verbose' {
                if($VerbosePreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue) {
                    $formattedMessage | Write-Verbose
                }
            }

            'Warning' {
                $formattedMessage | Write-Warning
            }

            default {
                $formattedMessage | Write-Host -ForegroundColor:Cyan
            }
        }

        # write the event to trace file to be used for debugging purposes
        $mutexInstance = Wait-OnMutex -MutexId 'SDN_TraceLogging' -ErrorAction Continue
        if ($mutexInstance) {
            $traceEvent | Export-Csv -Append -NoTypeInformation -Path $traceFile
        }
    }
    end {
        if ($mutexInstance) {
            $mutexInstance.ReleaseMutex()
        }
    }
}
