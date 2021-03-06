function Repair-CCMCacheLocation {
    <#
        .SYNOPSIS
            Repairs ConfigMgr cache location from computers via CIM. This cleans up \\ and ccmcache\ccmcache in path
        .DESCRIPTION
            This function will allow you to clean the existing cache path for multiple computers using CIM queries.
            You can provide an array of computer names, or cimsessions, or you can pass them through the pipeline.
            It will return a hashtable with the computer as key and boolean as value for success
        .PARAMETER CimSession
            Provides CimSessions to repair the cache location for
        .PARAMETER ComputerName
            Provides computer names to repair the cache location for
        .PARAMETER PSSession
            Provides PSSessions to repair the cache location for
        .PARAMETER ConnectionPreference
            Determines if the 'Get-CCMConnection' function should check for a PSSession, or a CIMSession first when a ComputerName
            is passed to the function. This is ultimately going to result in the function running faster. The typical use case is
            when you are using the pipeline. In the pipeline scenario, the 'ComputerName' parameter is what is passed along the 
            pipeline. The 'Get-CCMConnection' function is used to find the available connections, falling back from the preference
            specified in this parameter, to the the alternative (eg. you specify, PSSession, it falls back to CIMSession), and then 
            falling back to ComputerName. Keep in mind that the 'ConnectionPreference' also determines what type of connection / command
            the ComputerName parameter is passed to. 
        .EXAMPLE
            C:\PS> Repair-CCMCacheLocation -Location d:\windows\ccmcache
                Repair cache for local computer
        .EXAMPLE
            C:\PS> Repair-CCMCacheLocation -ComputerName 'Workstation1234','Workstation4321'
                Repair Cache location for Workstation1234, and Workstation4321
        .NOTES
            FileName:    Repair-CCMCacheLocation.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     2019-11-06
            Updated:     2020-02-24
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ComputerName')]
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
            $Return = [ordered]@{ }

            try {
                if ($PSCmdlet.ShouldProcess("[ComputerName = '$Computer']", "Repair CCM Cache Location")) {
                    $Cache = Get-CCMCacheInfo @connectionSplat
                    if ($Cache -is [pscustomobject]) {
                        $CurrentLocation = $Cache.Location
                        $NewLocation = $CurrentLocation -replace '\\\\', '\' -replace '(ccmcache\\?)+', 'ccmcache'
                        switch ($NewLocation -eq $CurrentLocation) {
                            $true {
                                $Return[$Computer] = $true
                            }
                            $false {
                                $connectionSplat['Location'] = $NewLocation
                                $SetCache = Set-CCMCacheLocation @connectionSplat
                                $Return[$Computer] = $SetCache.$Computer
                            }
                        }
                    }
                    Write-Output $Return
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error $ErrorMessage
            }
        }
    }
}