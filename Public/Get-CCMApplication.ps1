function Get-CCMApplication {
    <#
        .SYNOPSIS
            Return deployed applications from a computer
        .DESCRIPTION
            Pulls a list of deployed applications from the specified computer(s) or CIMSession(s) with optional filters, and can be passed on
            to Invoke-CCMApplication if desired.

            Note that the parameters for filter are all joined together with OR.
        .PARAMETER ApplicationName
            An array of ApplicationName to filter on
        .PARAMETER ApplicationID
            An array of application ID to filter on
        .PARAMETER IncludeIcon
            Switch that determines if the Icon property will be included in the output. As this can be a sizeable field, it is excluded by
            default to minimize the time it takes for this to run, and the amount of memory that will be consumed.
        .PARAMETER CimSession
            Provides CimSession to gather deployed application info from
        .PARAMETER ComputerName
            Provides computer names to gather deployed application info from
        .PARAMETER PSSession
           Provides PSSessions to gather deployed application info from
        .PARAMETER ConnectionPreference
            Determines if the 'Get-CCMConnection' function should check for a PSSession, or a CIMSession first when a ComputerName
            is passed to the function. This is ultimately going to result in the function running faster. The typical use case is
            when you are using the pipeline. In the pipeline scenario, the 'ComputerName' parameter is what is passed along the 
            pipeline. The 'Get-CCMConnection' function is used to find the available connections, falling back from the preference
            specified in this parameter, to the the alternative (eg. you specify, PSSession, it falls back to CIMSession), and then 
            falling back to ComputerName. Keep in mind that the 'ConnectionPreference' also determines what type of connection / command
            the ComputerName parameter is passed to. 
        .EXAMPLE
            PS> Get-CCMApplication
                Returns all deployed applications listed in WMI on the local computer
        .EXAMPLE
            PS> Get-CCMApplication -ApplicationID ScopeId_BE389CA5-D6CC-42AF-B8F5-A059F9C9AD91/Application_0607d288-fc0b-42b7-9a61-76abedf0673e -ApplicationName 'Software Install - Silent'
                Returns all deployed applications listed in WMI on the local computer which have either a application name of 'Software Install' or
                a ID of 'ScopeId_BE389CA5-D6CC-42AF-B8F5-A059F9C9AD91/Application_0607d288-fc0b-42b7-9a61-76abedf0673e'
        .NOTES
            FileName:    Get-CCMApplication.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     2020-01-21
            Updated:     2020-02-27
    #>
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param (
        [Parameter(Mandatory = $false)]
        [string[]]$ApplicationName,
        [Parameter(Mandatory = $false)]
        [string[]]$ApplicationID,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeIcon,
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
        #region define our hash tables for parameters to pass to Get-CIMInstance and our return hash table
        $getapplicationsplat = @{
            NameSpace = 'root\CCM\ClientSDK'
            ClassName = 'CCM_Application'
        }
        #endregion define our hash tables for parameters to pass to Get-CIMInstance and our return hash table

        #region EvaluationState hashtable for mapping
        $evaluationStateMap = @{
            0  = 'No state information is available.'
            1  = 'Application is enforced to desired/resolved state.'
            2  = 'Application is not required on the client.'
            3  = 'Application is available for enforcement (install or uninstall based on resolved state). Content may/may not have been downloaded.'
            4  = 'Application last failed to enforce (install/uninstall).'
            5  = 'Application is currently waiting for content download to complete.'
            6  = 'Application is currently waiting for content download to complete.'
            7  = 'Application is currently waiting for its dependencies to download.'
            8  = 'Application is currently waiting for a service (maintenance) window.'
            9  = 'Application is currently waiting for a previously pending reboot.'
            10 =	'Application is currently waiting for serialized enforcement.'
            11 =	'Application is currently enforcing dependencies.'
            12 =	'Application is currently enforcing.'
            13 =	'Application install/uninstall enforced and soft reboot is pending.'
            14 =	'Application installed/uninstalled and hard reboot is pending.'
            15 =	'Update is available but pending installation.'
            16 =	'Application failed to evaluate.'
            17 =	'Application is currently waiting for an active user session to enforce.'
            18 =	'Application is currently waiting for all users to logoff.'
            19 =	'Application is currently waiting for a user logon.'
            20 =	'Application in progress, waiting for retry.'
            21 =	'Application is waiting for presentation mode to be switched off.'
            22 =	'Application is pre-downloading content (downloading outside of install job).'
            23 =	'Application is pre-downloading dependent content (downloading outside of install job).'
            24 =	'Application download failed (downloading during install job).'
            25 =	'Application pre-downloading failed (downloading outside of install job).'
            26 =	'Download success (downloading during install job).'
            27 =	'Post-enforce evaluation.'
            28 =	'Waiting for network connectivity.'
        }
        #endregion EvaluationState hashtable for mapping
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
            $Return['ComputerName'] = $Computer

            try {
                $FilterParts = switch ($PSBoundParameters.Keys) {
                    'ApplicationName' {
                        [string]::Format('$AppFound.Name -eq "{0}"', [string]::Join('" -or $AppFound.Name -eq "', $ApplicationName))
                    }
                    'ApplicationID' {
                        [string]::Format('$AppFound.ID -eq "{0}"', [string]::Join('" -or $AppFound.ID -eq "', $ApplicationID))
                    }
                }
                [ciminstance[]]$applications = switch ($Computer -eq $env:ComputerName) {
                    $true {
                        Get-CimInstance @getapplicationsplat @connectionSplat
                    }
                    $false {
                        Get-CCMCimInstance @getapplicationsplat @connectionSplat
                    }
                }
                if ($applications -is [Object] -and $applications.Count -gt 0) {
                    #region Filterering is not possible on the CCM_Application class, so instead we loop and compare properties to filter
                    $Condition = switch ($null -ne $FilterParts) {
                        $true {
                            [scriptblock]::Create([string]::Join(' -or ', $FilterParts))
                        }
                    }
                    foreach ($AppFound in $applications) {
                        $AppToReturn = switch ($null -ne $Condition) {
                            $true {
                                switch ($Condition.Invoke()) {
                                    $true {
                                        $AppFound
                                    }
                                }
                            }
                            $false {
                                $AppFound
                            }
                        }
                        switch ($null -ne $AppToReturn) {
                            $true {
                                $Return['Name'] = $AppToReturn.Name
                                $Return['FullName'] = $AppToReturn.FullName
                                $Return['SoftwareVersion'] = $AppToReturn.SoftwareVersion
                                $Return['Publisher'] = $AppToReturn.Publisher
                                $Return['Description'] = $AppToReturn.Description
                                $Return['Id'] = $AppToReturn.Id
                                $Return['Revision'] = $AppToReturn.Revision
                                $Return['EvaluationState'] = $evaluationStateMap[[int]$AppToReturn.EvaluationState]
                                $Return['ErrorCode'] = $AppToReturn.ErrorCode
                                $Return['AllowedActions'] = $AppToReturn.AllowedActions
                                $Return['ResolvedState'] = $AppToReturn.ResolvedState
                                $Return['InstallState'] = $AppToReturn.InstallState
                                $Return['ApplicabilityState'] = $AppToReturn.ApplicabilityState
                                $Return['ConfigureState'] = $AppToReturn.ConfigureState
                                $Return['LastEvalTime'] = $AppToReturn.LastEvalTime
                                $Return['LastInstallTime'] = $AppToReturn.LastInstallTime
                                $Return['StartTime'] = $AppToReturn.StartTime
                                $Return['Deadline'] = $AppToReturn.Deadline
                                $Return['NextUserScheduledTime'] = $AppToReturn.NextUserScheduledTime
                                $Return['IsMachineTarget'] = $AppToReturn.IsMachineTarget
                                $Return['IsPreflightOnly'] = $AppToReturn.IsPreflightOnly
                                $Return['NotifyUser'] = $AppToReturn.NotifyUser
                                $Return['UserUIExperience'] = $AppToReturn.UserUIExperience
                                $Return['OverrideServiceWindow'] = $AppToReturn.OverrideServiceWindow
                                $Return['RebootOutsideServiceWindow'] = $AppToReturn.RebootOutsideServiceWindow
                                $Return['AppDTs'] = $AppToReturn.AppDTs
                                $Return['ContentSize'] = $AppToReturn.ContentSize
                                $Return['DeploymentReport'] = $AppToReturn.DeploymentReport
                                $Return['EnforcePreference'] = $AppToReturn.EnforcePreference
                                $Return['EstimatedInstallTime'] = $AppToReturn.EstimatedInstallTime
                                $Return['FileTypes'] = $AppToReturn.FileTypes
                                $Return['HighImpactDeployment'] = $AppToReturn.HighImpactDeployment
                                $Return['InformativeUrl'] = $AppToReturn.InformativeUrl
                                $Return['InProgressActions'] = $AppToReturn.InProgressActions
                                $Return['PercentComplete'] = $AppToReturn.PercentComplete
                                $Return['ReleaseDate'] = $AppToReturn.ReleaseDate
                                $Return['SupersessionState'] = $AppToReturn.SupersessionState
                                $Return['Type'] = $AppToReturn.Type
                                switch ($IncludeIcon.IsPresent) {
                                    $true {
                                        $Return['Icon'] = $AppToReturn.Icon
                                    }
                                }
                                [pscustomobject]$Return
                            }
                        }
                    }
                    #endregion Filterering is not possible on the CCM_Application class, so instead we loop and compare properties to filter
                }
                else {
                    Write-Warning "No deployed applications found for $Computer based on input filters"
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error $ErrorMessage
            }
        }
    }
}
