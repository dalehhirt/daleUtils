<#
.Description
This script elevates you into specified PIM groups.  If you want it for all, don't specify a subscription.
.EXAMPLE
C:\personal\daleUtils\src\Azure\ElevateMe.ps1 -subscriptionId "<subscription id>" -Justification "Terraform Deployment" -whatif
.EXAMPLE
C:\personal\daleUtils\src\Azure\ElevateMe.ps1 -Justification "Terraform Deployment" -whatif
.EXAMPLE
Get-AzSubscription | foreach {C:\personal\daleUtils\src\Azure\ElevateMe.ps1 -subscriptionId $_.SubscriptionId -Justification "Terraform Deployment" -whatif}
.EXAMPLE
Get-Azsubscription| sort Name | C:\personal\daleUtils\src\Azure\ElevateMe.ps1 -Justification "Terraform Deployment" 
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory, ParameterSetName = 'subscriptions', ValueFromPipeline)]
  [object[]]$subscriptions,

  [Parameter(Mandatory, ParameterSetName = 'subscriptionId')]
  [string]$subscriptionId,

  [Parameter(ParameterSetName = 'subscriptions')]
  [Parameter(ParameterSetName = 'subscriptionId')]
  $Justification,

  [Parameter(ParameterSetName = 'subscriptions')]
  [Parameter(ParameterSetName = 'subscriptionId')]
  $Hours = 8,

  [Parameter(ParameterSetName = 'subscriptions')]
  [Parameter(ParameterSetName = 'subscriptionId')]
  [ValidateNotNullOrEmpty()][DateTime]$NotBefore = [DateTime]::Now,
  $rolesToIgnore = @("Reader")
)
begin {
  function log() {
    write-host ">>> [$($env:COMPUTERNAME)]" ((Get-Date).ToUniversalTime().ToString('u')) "$args" -ForeGroundColor Green
  }
  
  function log-error() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '',
      Justification = 'Log error is more accurate')]
    param()
  
    Write-Error ">>> [$($env:COMPUTERNAME)] $((Get-Date).ToUniversalTime().ToString('u')) $args"
  }

  function Enable-AzRoles {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
      $subscriptionName, 
      $subscriptionId,
      $Justification,
      $Hours,
      $rolesToIgnore
    )
    
    begin {
      log "Getting role information for $($subscriptionName) [$($subscriptionId)]."
      
      $filter = 'asTarget()'
      $Scope = "/subscriptions/$subscriptionId"
    }
    
    process {
      $eligibleRoles = Get-AzRoleEligibilitySchedule -Scope $scope -Filter $filter -ErrorAction stop |
        # Where-Object { $_.Id -like "/subscriptions/$subscriptionId*" } |
        Sort-Object PrincipalDisplayName, RoleDefinitionDisplayName

      if ($null -ne $eligibleRoles) {
        log "  $(($eligibleRoles | Measure-Object).Count) eligible role(s) found"
        log "  --------------------------"
        $eligibleRoles | 
          Sort-Object EndDateTime |
          Format-Table -AutoSize PrincipalDisplayName, RoleDefinitionDisplayName, EndDateTime
    
        $activatedRoles = Get-AzRoleAssignmentScheduleInstance -Scope $scope -Filter $filter -ErrorAction stop |
          Where-Object { $_.AssignmentType -EQ 'Activated' } |
          # Where-Object { $_.Id -like "/subscriptions/$subscriptionId*" } |
          Sort-Object PrincipalDisplayName, RoleDefinitionDisplayName

        $activatedRolesIds = $activatedRoles.LinkedRoleEligibilityScheduleId

        if ($null -ne $activatedRoles) {
          log "  $(($activatedRoles | Measure-Object).Count) activated role(s) found"
          log "  ---------------------------"
          $activatedRoles |
            Sort-Object EndDateTime |
            Format-Table -AutoSize PrincipalDisplayName, RoleDefinitionDisplayName, EndDateTime
        }
        else {
          log "  No active role(s) found."
        }

        $expirationDuration = "PT{0}H" -f $hours #[XmlConvert]::ToString([TimeSpan]::FromHours($Hours))
        [string]$roleExpireTime = $NotBefore.AddHours($Hours)
        $userPrincipalId = (get-azaduser -UserPrincipalName (get-azcontext).account.Id).Id

        if (![System.String]::IsNullOrWhiteSpace($Justification)) {
          $newlyActivatedRoles = $eligibleRoles |
            Where-Object { $activatedRolesIds -notcontains $_.Id } |
            Where-Object { $rolesToIgnore -notcontains $_.RoleDefinitionDisplayName } |
            ForEach-Object {
              $roleToActivate = $_
              log "  Activating role:"
              log "    ID:       " $roleToActivate.Id
              log "    Principal:" $roleToActivate.PrincipalDisplayName
              log "    Role:     " $roleToActivate.RoleDefinitionDisplayName
              log "    Scope:    " $roleToActivate.Scope
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
          
          $newlyActivatedRoles |
            Sort-Object ExpirationDuration |
            Format-Table -AutoSize PrincipalDisplayName, RoleDefinitionDisplayName, ExpirationDuration, ExpirationType
        }
      }
      else {
        log "  No eligible role(s) found."
      }      
    }
    end {
    }
  }

  log "Starting"
}
process {
  if ($subscriptionId) {
    $subObject = Get-AzSubscription -SubscriptionId $subscriptionId
    Enable-AzRoles -subscriptionName $subObject.Name  -subscriptionId $subObject.SubscriptionId -Justification $Justification -Hours $Hours -rolesToIgnore $rolesToIgnore
  }
  else {
    foreach ($subObject in $subscriptions) {
      Enable-AzRoles -subscriptionName $subObject.Name  -subscriptionId $subObject.SubscriptionId -Justification $Justification -Hours $Hours -rolesToIgnore $rolesToIgnore
    }
  }
}
end {
  log "Finished"
}