function Get-CCMLastHeartbeat {
    <#
        .SYNOPSIS
            Returns info about the last time a heartbeat ran. Also known as a DDR.
        .DESCRIPTION
            This function will return info about the last time Discovery Data Collection Cycle was ran. This is pulled from the InventoryActionStatus WMI Class.
            The Discovery Data Collection Cycle major, and minor version is included.

            This is also known as a 'Heartbeat' or 'DDR'
        .PARAMETER CimSession
            Provides CimSessions to gather Discovery Data Collection Cycle last run info from
        .PARAMETER ComputerName
            Provides computer names to gather Discovery Data Collection Cycle last run info from
        .PARAMETER PSSession
            Provides PSSession to gather Discovery Data Collection Cycle last run info from
        .PARAMETER ConnectionPreference
            Determines if the 'Get-CCMConnection' function should check for a PSSession, or a CIMSession first when a ComputerName
            is passed to the function. This is ultimately going to result in the function running faster. The typical use case is
            when you are using the pipeline. In the pipeline scenario, the 'ComputerName' parameter is what is passed along the
            pipeline. The 'Get-CCMConnection' function is used to find the available connections, falling back from the preference
            specified in this parameter, to the the alternative (eg. you specify, PSSession, it falls back to CIMSession), and then
            falling back to ComputerName. Keep in mind that the 'ConnectionPreference' also determines what type of connection / command
            the ComputerName parameter is passed to.
        .EXAMPLE
            C:\PS> Get-CCMLastHeartbeat
                Returns info regarding the last Discovery Data Collection Cycle for the local computer
        .EXAMPLE
        C:\PS> Get-CCMLastHeartbeat -ComputerName 'Workstation1234','Workstation4321'
            Returns info regarding the last Discovery Data Collection Cycle for Workstation1234, and Workstation4321
        .NOTES
            FileName:    Get-CCMLastHeartbeat.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     2020-01-01
            Updated:     2020-02-27
    #>
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    [Alias('Get-CCMLastDDR')]
    param (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CimSession')]
        [Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ComputerName')]
        [Alias('Connection', 'PSComputerName', 'PSConnectionName', 'IPAddress', 'ServerName', 'HostName', 'DNSHostName')]
        [string[]]$ComputerName = $env:ComputerName,
        [Parameter(Mandatory = $false, ParameterSetName = 'PSSession')]
        [Alias('Session')]      
        [System.Management.Automation.Runspaces.PSSession[]]$PSSession,
        [Parameter(Mandatory = $false, ParameterSetName = 'ComputerName')]
        [ValidateSet('CimSession', 'PSSession')]
        [string]$ConnectionPreference
    )
    begin {
        $getLastDDRSplat = @{
            Namespace = 'root\CCM\InvAgt'
            Query     = "SELECT LastCycleStartedDate, LastReportDate, LastMajorReportVersion, LastMinorReportVersion, InventoryActionID FROM InventoryActionStatus WHERE InventoryActionID = '{00000000-0000-0000-0000-000000000003}'"
        }
    }
    process {
        foreach ($Connection in (Get-Variable -Name $PSCmdlet.ParameterSetName -ValueOnly)) {
            $getConnectionInfoSplat = @{
                $PSCmdlet.ParameterSetName = $Connection
            }
            switch ($PSBoundParameters.ContainsKey('ConnectionPreference')) {
                $true {
                    $getConnectionInfoSplat['Prefer'] = $ConnectionPreference
                }
            }
            $ConnectionInfo = Get-CCMConnection @getConnectionInfoSplat
            $Computer = $ConnectionInfo.ComputerName
            $connectionSplat = $ConnectionInfo.connectionSplat

            $Result = [ordered]@{ }
            $Result['ComputerName'] = $Computer

            try {
                [ciminstance[]]$LastDDR = switch ($Computer -eq $env:ComputerName) {
                    $true {
                        Get-CimInstance @getLastDDRSplat @connectionSplat
                    }
                    $false {
                        Get-CCMCimInstance @getLastDDRSplat @connectionSplat
                    }
                }
                if ($LastDDR -is [Object] -and $LastDDR.Count -gt 0) {
                    foreach ($Occurrence in $LastDDR) {
                        $Result['LastCycleStartedDate'] = $Occurrence.LastCycleStartedDate
                        $Result['LastReportDate'] = $Occurrence.LastReportDate
                        $Result['LastMajorReportVersion'] = $Occurrence.LastMajorReportVersion
                        $Result['LastMinorReportVersion'] = $Occurrence.LastMinorReportVersion
                        [PSCustomObject]$Result
                    }
                }
                else {
                    Write-Warning "No Discovery Data Collection Cycle run found for $Computer"
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error $ErrorMessage
            }
        }
    }
}