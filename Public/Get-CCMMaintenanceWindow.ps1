function Get-CCMMaintenanceWindow {
    <#
        .SYNOPSIS
            Get ConfigMgr Maintenance Window information from computers via CIM
        .DESCRIPTION
            This function will allow you to gather maintenance window information from multiple computers using CIM queries. You can provide an array of computer names, or cimsessions,
            or you can pass them through the pipeline. You are also able to specify the Maintenance Window Type (MWType) you wish to query for.
        .PARAMETER MWType
            Specifies the types of MW you want information for. Valid options are below
                'All Deployment Service Window',
                'Program Service Window',
                'Reboot Required Service Window',
                'Software Update Service Window',
                'Task Sequences Service Window',
                'Corresponds to non-working hours'
        .PARAMETER CimSession
            Provides CimSession to gather Maintenance Window information info from
        .PARAMETER ComputerName
            Provides computer names to gather Maintenance Window information info from
        .PARAMETER PSSession
            Provides PSSessions to gather Maintenance Window information info from
        .PARAMETER ConnectionPreference
            Determines if the 'Get-CCMConnection' function should check for a PSSession, or a CIMSession first when a ComputerName
            is passed to the function. This is ultimately going to result in the function running faster. The typical use case is
            when you are using the pipeline. In the pipeline scenario, the 'ComputerName' parameter is what is passed along the
            pipeline. The 'Get-CCMConnection' function is used to find the available connections, falling back from the preference
            specified in this parameter, to the the alternative (eg. you specify, PSSession, it falls back to CIMSession), and then
            falling back to ComputerName. Keep in mind that the 'ConnectionPreference' also determines what type of connection / command
            the ComputerName parameter is passed to.
        .EXAMPLE
            C:\PS> Get-CCMMaintenanceWindow
                Return all the 'All Deployment Service Window', 'Software Update Service Window' Maintenance Windows for the local computer. These are the two default MW types
                that the function looks for
        .EXAMPLE
            C:\PS> Get-CCMMaintenanceWindow -ComputerName 'Workstation1234','Workstation4321' -MWType 'Software Update Service Window'
                Return all the 'Software Update Service Window' Maintenance Windows for Workstation1234, and Workstation4321
        .NOTES
            FileName:    Get-CCMMaintenanceWindow.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     2019-08-14
            Updated:     2020-02-27
    #>
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    [Alias('Get-CCMMW')]
    param (
        [parameter(Mandatory = $false)]
        [ValidateSet('All Deployment Service Window',
            'Program Service Window',
            'Reboot Required Service Window',
            'Software Update Service Window',
            'Task Sequences Service Window',
            'Corresponds to non-working hours')]
        [string[]]$MWType = @('All Deployment Service Window', 'Software Update Service Window'),
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
        #region Create hashtable for mapping MW types, and create CIM filter based on input params
        $MW_Type = @{
            1	=	'All Deployment Service Window'
            2	=	'Program Service Window'
            3	=	'Reboot Required Service Window'
            4	=	'Software Update Service Window'
            5	=	'Task Sequences Service Window'
            6	=	'Corresponds to non-working hours'
        }

        $RequestedTypesRaw = $MW_Type.Keys.Where( { $MW_Type[$_] -in $MWType } )
        $RequestedTypesFilter = [string]::Format('Type = {0}', [string]::Join(' OR Type =', $RequestedTypesRaw))
        #endregion Create hashtable for mapping MW types, and create CIM filter based on input params

        $getMaintenanceWindowSplat = @{
            Namespace = 'root\CCM\ClientSDK'
            ClassName = 'CCM_ServiceWindow'
            Filter    = $RequestedTypesFilter
        }
        $getTimeZoneSplat = @{
            Query = 'SELECT Caption FROM Win32_TimeZone'
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
                $TZ = switch ($Computer -eq $env:ComputerName) {
                    $true {
                        Get-CimInstance @getTimeZoneSplat @connectionSplat
                    }
                    $false {
                        Get-CCMCimInstance @getTimeZoneSplat @connectionSplat
                    }
                }
                $Result['TimeZone'] = $TZ.Caption

                [ciminstance[]]$ServiceWindows = switch ($Computer -eq $env:ComputerName) {
                    $true {
                        Get-CimInstance @getMaintenanceWindowSplat @connectionSplat
                    }
                    $false {
                        Get-CCMCimInstance @getMaintenanceWindowSplat @connectionSplat
                    }
                }

                if ($ServiceWindows -is [Object] -and $ServiceWindows.Count -gt 0) {
                    foreach ($ServiceWindow in $ServiceWindows) {
                        $Result['StartTime'] = ($ServiceWindow.StartTime).ToUniversalTime()
                        $Result['EndTime'] = ($ServiceWindow.EndTime).ToUniversalTime()
                        $Result['Duration'] = $ServiceWindow.Duration
                        $Result['DurationDescription'] = Get-StringFromTimespan -Seconds $ServiceWindow.Duration
                        $Result['MWID'] = $ServiceWindow.ID
                        $Result['Type'] = $MW_Type.Item([int]$($ServiceWindow.Type))
                        [PSCustomObject]$Result
                    }
                }
                else {
                    $Result['StartTime'] = $null
                    $Result['EndTime'] = $null
                    $Result['Duration'] = $null
                    $Result['DurationDescription'] = $null
                    $Result['MWID'] = $null
                    $Result['Type'] = "No ServiceWindow of type(s) $([string]::Join(', ',$RequestedTypesRaw))"
                    [PSCustomObject]$Result
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error $ErrorMessage
            }
        }
    }
}