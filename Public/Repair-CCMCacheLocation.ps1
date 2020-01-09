function Repair-CCMCacheLocation {
    <#
    .SYNOPSIS
        Repairs ConfigMgr cache location from computers via CIM. This cleans up \\ and ccmcache\ccmcache in path
    .DESCRIPTION
        This function will allow you to clean the existing cache path for multiple computers using CIM queries. 
        You can provide an array of computer names, or cimsessions, or you can pass them through the pipeline.
        It will return a hastable with the computer as key and boolean as value for success
    .PARAMETER CimSession
        Provides CimSessions to repair the cache location for
    .PARAMETER ComputerName
        Provides computer names to repair the cache location for
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
        Updated:     2020-12-09
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ComputerName')]
    param (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CimSession')]
        [CimSession[]]$CimSession,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ComputerName')]
        [Alias('Connection', 'PSConnectionName', 'IPAddress', 'ServerName', 'HostName', 'DNSHostName')]
        [string[]]$ComputerName = $env:ComputerName
    )
    begin {
        $GetCCMCacheSplat = @{ }
        $SetCCMCacheSplat = @{ }
    }
    process {
        foreach ($Connection in (Get-Variable -Name $PSCmdlet.ParameterSetName -ValueOnly)) {
            $Computer = switch ($PSCmdlet.ParameterSetName) {
                'ComputerName' {
                    Write-Output -InputObject $Connection
                    switch ($Connection -eq $env:ComputerName) {
                        $false {
                            if ($ExistingCimSession = Get-CimSession -ComputerName $Connection -ErrorAction Ignore) {
                                Write-Verbose "Active CimSession found for $Connection - Passing CimSession to CIM cmdlets"
                                $GetCCMCacheSplat.Remove('ComputerName')
                                $GetCCMCacheSplat['CimSession'] = $ExistingCimSession
                                $SetCCMCacheSplat.Remove('ComputerName')
                                $SetCCMCacheSplat['CimSession'] = $ExistingCimSession
                            }
                            else {
                                Write-Verbose "No active CimSession found for $Connection - falling back to -ComputerName parameter for CIM cmdlets"
                                $GetCCMCacheSplat.Remove('CimSession')
                                $GetCCMCacheSplat['ComputerName'] = $Connection
                                $SetCCMCacheSplat.Remove('CimSession')
                                $SetCCMCacheSplat['ComputerName'] = $Connection
                            }
                        }
                        $true {
                            $GetCCMCacheSplat.Remove('CimSession')
                            $GetCCMCacheSplat.Remove('ComputerName')
                            $SetCCMCacheSplat.Remove('CimSession')
                            $SetCCMCacheSplat.Remove('ComputerName')
                            Write-Verbose 'Local computer is being queried - skipping computername, and cimsession parameter'
                        }
                    }
                }
                'CimSession' {
                    Write-Verbose "Active CimSession found for $Connection - Passing CimSession to CIM cmdlets"
                    Write-Output -InputObject $Connection.ComputerName
                    $GetCCMCacheSplat.Remove('ComputerName')
                    $SetCCMCacheSplat.Remove('ComputerName')
                    $GetCCMCacheSplat['CimSession'] = $Connection
                    $SetCCMCacheSplat['CimSession'] = $Connection
                }
            }
            $Return = [System.Collections.Specialized.OrderedDictionary]::new()

            try {
                if ($PSCmdlet.ShouldProcess("[ComputerName = '$Computer']", "Repair CCM Cache Location")) {
                    $Cache = Get-CCMCache @GetCCMCacheSplat
                    if ($Cache -is [hashtable]) {
                        $CurrentLocation = $Cache.$Computer.Location
                        $NewLocation = $CurrentLocation -replace '\\\\', '\' -replace 'ccmcache\\ccmcache', 'ccmcache' 
                        switch ($NewLocation -eq $CurrentLocation) {
                            $true {
                                $Return[$Computer] = $true
                            }
                            $false {
                                $SetCCMCacheSplat['Location'] = $NewLocation
                                $SetCache = Set-CCMCacheLocation @SetCCMCacheSplat
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