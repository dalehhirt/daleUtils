<#
.Description
This script elevates you into specified PIM groups.  If you want it for all, don't specify a subscription.
.EXAMPLE
C:\personal\daleUtils\src\Azure\ElevateMe.ps1 -subscriptionId "<subscription id>" -Justification "Terraform Deployment" -whatif
.EXAMPLE
C:\personal\daleUtils\src\Azure\ElevateMe.ps1 -Justification "Terraform Deployment" -whatif
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  $subscriptionId = '',
  $Justification,
  $Hours = 8,
  [ValidateNotNullOrEmpty()][DateTime]$NotBefore = [DateTime]::Now,
  $rolesToIgnore = @("Reader")
)
begin {
  function log() {
    write-host ">>> [$($env:COMPUTERNAME)]" ((Get-Date).ToUniversalTime().ToString('u')) "$args" -ForeGroundColor Green
  }
  
  function log-error() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '',
      Justification='Log error is more accurate')]
    param()
  
    Write-Error ">>> [$($env:COMPUTERNAME)] $((Get-Date).ToUniversalTime().ToString('u')) $args"
  }
  
  $filter = 'asTarget()'
  $Scope = '/'
  $isSubIdNull = [System.String]::IsNullOrWhiteSpace($subscriptionId)

  # We don't actually do anything unless subscription is specified
  if ($isSubIdNull -and ($WhatIfPreference -eq $false)) {
    log "Setting Whatif to true. Pass in subscriptionId to enable."
    $WhatIfPreference = $true
  }
}
process {
  if ($isSubIdNull) {
    log "Getting All Role(s) Information"
  }
  else {
    log "Getting $subscriptionId Role(s) Information"
  }
  $eligibleRoles = Get-AzRoleEligibilitySchedule -Scope $scope -Filter $filter -ErrorAction stop |
    Sort-Object Id

  $activatedRoles = Get-AzRoleAssignmentScheduleInstance -Scope $scope -Filter $filter -ErrorAction stop |
          Where-Object {$_.AssignmentType -EQ 'Activated' } |
          Sort-Object Id

  if (!$isSubIdNull) {
    $eligibleRoles = $eligibleRoles | Where-Object {$_.Id -like "/subscriptions/$subscriptionId*"}
    $activatedRoles = $activatedRoles | Where-Object {$_.Id -like "/subscriptions/$subscriptionId*"}
  }

  $activatedRolesIds = $activatedRoles.LinkedRoleEligibilityScheduleId

  if($null -ne $eligibleRoles) {
    log "Eligible Roles"
    log "-------------"
    $eligibleRoles | 
        Format-List Id,ScopeDisplayName,PrincipalDisplayName,RoleDefinitionDisplayName
    
    if($null -ne $activatedRoles) {
      log "Activated Roles"
      log "-------------"
      $activatedRoles |
          Format-List ScopeDisplayName,PrincipalDisplayName,RoleDefinitionDisplayName
    }

    $expirationDuration = "PT{0}H" -f $hours #[XmlConvert]::ToString([TimeSpan]::FromHours($Hours))
    [string]$roleExpireTime = $NotBefore.AddHours($Hours)
    $userPrincipalId = (get-azaduser -UserPrincipalName (get-azcontext).account.Id).Id

    if (![System.String]::IsNullOrWhiteSpace($Justification)) {
        $eligibleRoles |
        Where-Object {$activatedRolesIds -notcontains $_.Id} |
        Where-Object {$rolesToIgnore -notcontains $_.RoleDefinitionDisplayName} |
        ForEach-Object {
            $roleToActivate = $_
            log "Activating role:"
            log "  ID:       " $roleToActivate.Id
            log "  Principal:" $roleToActivate.PrincipalDisplayName
            log "  Role:     " $roleToActivate.RoleDefinitionDisplayName
            log "  Scope:    " $roleToActivate.Scope
            $roleActivateParams = @{
                Name                            = New-Guid
                Scope                           = $roleToActivate.Scope
                PrincipalId                     = $userPrincipalId
                RoleDefinitionId                = $roleToActivate.RoleDefinitionId
                RequestType                     = 'SelfActivate'
                LinkedRoleEligibilityScheduleId = $roleToActivate.Id
                ExpirationType                  = 'AfterDuration'
                ExpirationDuration              = $expirationDuration
                Justification                   = $Justification
            }
                    
            if ($PSCmdlet.ShouldProcess(
                "$($roleToActivate.RoleDefinitionDisplayName) on $($roleToActivate.ScopeDisplayName) ($($roleToActivate.ScopeId))",
                "Activate Role from $NotBefore to $roleExpireTime"
            )) {
                New-AzRoleAssignmentScheduleRequest @roleActivateParams -ErrorAction Stop
            }
        }
    }
  }
}
end {
  log "Finished"
}