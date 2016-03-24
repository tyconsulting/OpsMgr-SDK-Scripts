<#
===========================================================================
Created on:   	22/03/2016
Created by:   	Tao Yang
Filename:     	Copy-PerfRulesToOMS.ps1
-------------------------------------------------------------------------
Description:
This script is reads configurations of all performance collection rules
in a particular OpsMgr management pack, and then recreate these rules
with same configuration but stores the performance data as PerfHourly
data in your OMS workspace.

Required PS Module:
OpsMgrExtended (http://www.tyconsulting.com.au/portfolio/opsmgrextended-powershell-and-sma-module/)

Other Requirements
 - OpsMgr management group must be connected to a OMS workspace

===========================================================================
#>
Param(
	[Parameter(Mandatory=$true)][String][Alias('SDK', 'MS')]$ManagementServer,
    [Parameter(Mandatory=$false)][PSCredential][Alias('cred')]$Credential,
	[Parameter(Mandatory=$true)][String]$ManagementPackName
)

#region Variable definitions
$SCLibMPId = [guid]'7cfc5cc0-ae0a-da4f-5ac2-d64540141a55' #The Id for 'Microsoft.SystemCenter.Library' MP. This is unique.
$DWLibMPId = [guid]'c183c241-e7b5-a06f-d6d9-2d573485b91e' #The Id for 'Microsoft.SystemCenter.DataWarehouse.Library' MP. This is unique.

#endregion

#region Connect to OpsMgr SDK and checking pre-reqs
#Look for OpsMgrExtended module
Write-Verbose "Looking for OpsMgrExtended PowerShell module."
If(!(Get-Module OpsMgrExtended -ListAvailable))
{
    Throw "The PowerShell module OpsMgrExtended is not installed on this computer. Please download from 'http://www.tyconsulting.com.au/portfolio/opsmgrextended-powershell-and-sma-module/', install it on this computer and then try again."
    Exit 1
}

#Connect to OpsMgr management group
Write-Output "Connecting to OpsMgr management group via management server '$ManagementServer'."
If ($Credential)
{
    $MG = Connect-OMManagementGroup -SDK $ManagementServer -Username $Credential.UserName -Password $Credential.Password
} else {
    $MG = Connect-OMManagementGroup -SDK $ManagementServer
}

#Make sure the required OMS MP exists (The OpsMgr management group must be connected to an OMS workspace).
Write-Verbose "Looking for management pack 'Microsoft.IntelligencePacks.Types'."
$IPTypesMPCriteria = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackCriteria("Name='Microsoft.IntelligencePacks.Types'")
$IPTypesMP = $MG.GetManagementPacks($IPTypesMPCriteria)[0]
If ($IPTypesMP -eq $null)
{
    Throw "The managmenet pack 'Microsoft.IntelligencePacks.Types' does not exist on this OpsMgr management group. Please make sure the OpsMgr management group is connected to a OMS workspace."
    Exit 1
}
#endregion

Write-Verbose "Getting 'Microsoft.SystemCenter.CollectPerformanceData' Write Action Module"
$SCLibMP = $MG.GetManagementPack($SCLibMPId)
$WriteToDBWA = $SCLibMP.GetModuleType("Microsoft.SystemCenter.CollectPerformanceData")

Write-Verbose "Getting 'Microsoft.SystemCenter.DataWarehouse.PublishPerformanceData' Write Action Module"
$DWLibMP = $MG.GetManagementPack($DWLibMPId)
$WriteToDWWA= $DWLibMP.GetModuleType("Microsoft.SystemCenter.DataWarehouse.PublishPerformanceData")

Write-Verbose "Getting 'Microsoft.SystemCenter.CollectCloudPerformanceData' Write Action module"
$HttpWA = $IPTypesMP.GetModuleType("Microsoft.SystemCenter.CollectCloudPerformanceData")

Write-Output "retrieve the source MP '$ManagementPackName'."
$SourceMPCriteria = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackCriteria("Name='$ManagementPackName'")
$SourceMP = $MG.GetManagementPacks($SourceMPCriteria)[0]
If ($SourceMP.Sealed -eq $false)
{
    Write-Warning "The source management pack '$ManagementPackName' is an unsealed MP. The OMS performance rule creation will fail if any source rules are targeting classes or referencing module types defined in this unsealed MP."
}
Write-Verbose "retriving all rules from the source MP."
$SourceRules = $SourceMP.GetRules()

Write-Output "Getting all performance collection rules from source MP '$ManagementPackName'."
$arrSourcePerfRules = New-object System.Collections.ArrayList
Foreach ($rule in $SourceRules)
{
    $bIsPerfRule = $false
    Foreach ($WAModule in $rule.WriteActionCollection)
    {
        If ($WAModule.TypeId.Id -eq $WriteToDBWA.Id -or $WAModule.TypeId.Id -eq $WriteToDWWA.Id)
        {
            $bIsPerfRule = $true
        }
    }
    If ($bIsPerfRule -eq $true)
    {
        Write-Verbose "'$($rule.name)' is an OpsMgr performance collection rule."
        [void]$arrSourcePerfRules.Add($rule)
    }
}

Write-Output "Number of Performance Collection rules detected: $($arrSourcePerfRules.Count)."
If ($arrSourcePerfRules.Count -ge 1)
{
    Write-Output "Start recreating performance collection rules for OMS."
    #Lookup pre-existing destination MP
    $DestMPName = "$($SourceMP.Name)`.OMS.Perf.Collection"
    $DestMPCriteria = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackCriteria("Name='$DestMPName'")
    $DestMP = $MG.GetManagementPacks($DestMPCriteria)[0]
    If ($DestMP)
    {
        throw "The destination management pack '$DestMPName' already exists. Unable to continue. Please delete this management pack and try again."
        Exit 1
    } else {
        Write-Verbose "Creating destination management pack '$DestMPName'"
        $DestMPDisplayName = "$($SourceMP.DisplayName) OMS PerfHourly Addon"
        If ($Credential)
        {
            $CreateDestMPResult = New-OMManagementPack -SDK $ManagementServer -Username $Credential.UserName -Password $Credential.Password -Name $DestMPName -DisplayName $DestMPDisplayName    
        } else {
            $CreateDestMPResult = New-OMManagementPack -SDK $ManagementServer -Name $DestMPName -DisplayName $DestMPDisplayName
        }
        Write-Verbose "Retrieving newly created destination management pack '$DestMPName'."
        $DestMP = $DestMP = $MG.GetManagementPacks($DestMPCriteria)[0]
        Write-Verbose "Destination management pack display name: '$($DestMP.DisplayName)'."
    }

    $i=0
    Foreach ($OriginalRule in $arrSourcePerfRules)
    {
        $OMSPerfRuleName = "$($OriginalRule.Name).OMS.PerfHourly"
        $OMSPerfRuleDisplayName = "$($OriginalRule.DisplayName) OMS PerfHourly"
        Write-Output "Re-creating '$($OriginalRule.Name)' for OMS. Name of the new rule: '$OMSPerfRuleName'."
        #Get the target monitoring class
        $TargetId = $OriginalRule.Target.Id
        $Target = $MG.GetMonitoringClass($TargetId)
        #Create new rule
        $OMSPerfRule = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRule($DestMP, $OMSPerfRuleName)

        #copying properties
        $OMSPerfRule.Category = [Microsoft.EnterpriseManagement.Configuration.ManagementPackCategoryType]::$($OriginalRule.Category.ToString())
        $OMSPerfRule.DisplayName = $OMSPerfRuleDisplayName
	    $OMSPerfRule.Enabled = $OriginalRule.Enabled
	    $OMSPerfRule.Remotable = $OriginalRule.Remotable
        $OMSPerfRule.DiscardLevel = $OriginalRule.DiscardLevel
        $OMSPerfRule.Priority = [Microsoft.EnterpriseManagement.Configuration.ManagementPackWorkflowPriority]::$($OriginalRule.Priority.ToString())
        $OMSPerfRule.ConfirmDelivery = $OriginalRule.ConfirmDelivery
        $OMSPerfRule.Target = $Target

        #Copying data source modules
        Foreach ($OriginalDS in $OriginalRule.DataSourceCollection)
        {
            $NewDSModule = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModule($OMSPerfRule, $OriginalDS.Name)
            $NewDSModuleType = $MG.GetMonitoringModuleType($OriginalDS.TypeID.Id)
            $NewDSModule.TypeID = $NewDSModuleType
            $NewDSModule.RunAs = $OriginalDS.RunAs
            $NewDSModule.Configuration = $OriginalDS.Configuration
            $NewDSModule.Description = $OriginalDS.Description
            $NewDSModule.DisplayName = $OriginalDS.DisplayName
            $OMSPerfRule.DataSourceCollection.Add($NewDSModule)
        }
        
        #Copying condition detection module
        If ($OriginalRule.ConditionDetection -ne $null)
        {
            $NewCDModule = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackConditionDetectionModule($OMSPerfRule, $OriginalRule.ConditionDetection.Name)
            $NewCdModuleType = $MG.GetMonitoringModuleType($OriginalRule.ConditionDetection.TypeID.Id)
            $NewCDModule.TypeID = $NewCdModuleType
            $NewCDModule.RunAs = $OriginalRule.ConditionDetection.RunAs
            $NewCDModule.Description = $OriginalRule.ConditionDetection.Description
            $NewCDModule.DisplayName = $OriginalRule.ConditionDetection.DisplayName
            $NewCDModule.Configuration = $OriginalRule.ConditionDetection.Configuration
        }
        
        #Creating a Write Action member module to ship perf data to OMS as PerfHourly type.
        $NewWAModule = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackWriteActionModule($OMSPerfRule, 'HttpWA')
        $NewWAModule.TypeID = $HttpWA
        $OMSPerfRule.WriteActionCollection.Add($NewWAModule)
        #Verify and save the rules
        Write-Verbose "Verifying MP and saving newly created rule '$OMSPerfRuleName'"
        Try {
            $DestMP.verify()
            $DestMP.AcceptChanges()
	        Write-Verbose "OMS perf collection rule '$OMSPerfRuleName' successfully created in Management Pack '$DestMPName'($($DestMP.Version))."
        } Catch {
            Write-Error $_.Exception.InnerException
	        $MP.RejectChanges()
            Write-Error "Failed to create OMS perf collection rule '$OMSPerfRuleName' in management pack $DestMPName."
        }
    }
}
Write-Output "Done!"
