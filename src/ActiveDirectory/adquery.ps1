<#
.Description
This script runs.
.EXAMPLE
$account = C:\dd\query.ps1 -name "username";$account.properties
.EXAMPLE
$account = C:\dd\query.ps1 -name "username";$account.properties.memberof
.EXAMPLE
C:\dd\query.ps1 -name "username" | sort path | ft @{label="samaccountname";expression={$_.properties.samaccountname}},@{label="DisplayName";expression={$_.properties.displayname}}
.EXAMPLE
$users = C:\work\query.ps1 -name "username" -PassThrough
$users | sort path | ft @{label="samaccountname";expression={$_.properties.samaccountname}},@{label="DisplayName";expression={$_.properties.displayname}}
.EXAMPLE
$users = C:\work\query.ps1 -name "groupname" -PassThrough -group
$users | sort path | ft @{label="samaccountname";expression={$_.properties.samaccountname}},@{label="DisplayName";expression={$_.properties.displayname}}
.EXAMPLE
# Find by property name
C:\personal\daleUtils\src\ActiveDirectory\adquery.ps1 -PassThrough |where {$_.properties.employeenumber -eq "3"} | ft @{label="samaccountname";expression={$_.properties.samaccountname}},@{label="EmployeeNumber";expression={$_.properties.employeenumber}}
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  $RootOU = "DC=LOCAL,DC=MAVIS-HQ,DC=COM",
  $name = "",
  [switch]$group,
  [switch]$PassThrough
)
begin {
  function log() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '',Justification='Log function')]
    param()
    write-host ">>> [$($env:COMPUTERNAME)]" ((Get-Date).ToUniversalTime().ToString('u')) "$args" -ForeGroundColor Green
  }

  function log-error() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '',
      Justification='Log error is more accurate')]
    param()
  
    Write-Error ">>> [$($env:COMPUTERNAME)] $((Get-Date).ToUniversalTime().ToString('u')) $args"
  }

  function log-verbose() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '',
      Justification='Log verbose is more accurate')]
    param()
    write-verbose ">>> [$($env:COMPUTERNAME)] $((Get-Date).ToUniversalTime().ToString('u')) $args"
  }

  function Using-Object
  {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '',
      Justification='Using C# Idioms to enable easier usage.')]
    [CmdletBinding()]
    param (
          [Parameter(Mandatory = $true)]
          [AllowEmptyString()]
          [AllowEmptyCollection()]
          [AllowNull()]
          [Object]
          $InputObject,
  
          [Parameter(Mandatory = $true)]
          [scriptblock]
          $ScriptBlock
    )
  
    try
    {
      . $ScriptBlock
    }
    finally
    {
      if ($null -ne $InputObject -and $InputObject -is [System.IDisposable])
      {
        log-Verbose "Disposing of object" $InputObject.GetType()
        $InputObject.Dispose()
      }
    }
  }

  function Get-UserGroups() {
    param($Searcher, $distinguishedName)

    # This is the LDAP filter we need to use in order to get recursive (implicit) group membership
    $LDAPGroupMemberFilterRecursive = "(member:1.2.840.113556.1.4.1941:={0})"

    $Searcher.Filter = $LDAPGroupMemberFilterRecursive -f $distinguishedName#, $foundName
    $Searcher.PropertiesToLoad.Clear()
    $Searcher.SearchScope = [DirectoryServices.SearchScope]::Subtree

    return $searcher.FindAll()
  }

  function Get-User() {
    param($Searcher, $userName)

    $filter = "(objectClass=user)"
    if(![System.String]::IsNullOrWhiteSpace($userName)) {
        $filter = "(&$filter(samAccountName=*$userName*))"
    }

    $Searcher.Filter = $filter
    $Searcher.PropertiesToLoad.Clear()
    $Searcher.PropertiesToLoad.Add("memberOf") | out-null
    $Searcher.PropertiesToLoad.Add("msDS-UserPasswordExpiryTimeComputed") | out-null
    $Searcher.PropertiesToLoad.Add("*") | out-null
    return $searcher.FindAll()
  }

  function Get-Group() {
    param($Searcher, $groupName)

    $filter = "(objectClass=group)"
    if(![System.String]::IsNullOrWhiteSpace($groupName)) {
        $filter = "(&$filter(name=*$groupName*))"
    }

    $Searcher.Filter = $filter
    $Searcher.PropertiesToLoad.Clear()  | out-null
    $Searcher.PropertiesToLoad.Add("member") | out-null
    $Searcher.PropertiesToLoad.Add("*") | out-null
    return $searcher.FindAll()
  }

  function write-properties(){
    param($level, $key, $property)
    $indent = "  " * $level
    if($property -is [System.DirectoryServices.ResultPropertyValueCollection] ) {
      $val = "$indent$key = ["

      if($property[0] -is [System.Byte[]]) {
        $val += $property | foreach {"$_"}
      }
      else {
          $val += ($property | Sort-Object) -join ","
      }

      $val += "]"
      log $val
    }
    else {
      log "$indent$key = $property"
    }

  }

}
process {
  $returnValue = [System.Collections.ArrayList]::new()
  Using-Object($Searcher = New-Object DirectoryServices.DirectorySearcher) {
    log "Creating Searcher Object"
    $Searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($rootOu)")
    $Searcher.PageSize = 1001  # This should enable us to get all objects
    if($group) {
      log "Searching groups for $name"
      $results = Get-Group -Searcher $Searcher -groupName $name
      if($PassThrough) {
        $results | ForEach-Object {[void]$returnValue.Add($_)}
      }
      else {
        $results | ForEach-Object {
          $result = $_
          log "Found group" $result.path
          [void]$returnValue.Add($result)
          $properties = $result.Properties

          log "  Members:"
          $properties["member"] | Sort-Object | ForEach-Object {log "  " $_}
          log "  Properties"
          $properties.keys | Sort-Object | ForEach-Object {
            $propertyKey = $_
            write-properties -level 2 -key $propertyKey -property $properties[$propertyKey]
          }
        }
      }
    }
    else {
      log "Searching users for $name"
      $results = Get-User -Searcher $Searcher -userName $name
      if($PassThrough) {
        $results | ForEach-Object {[void]$returnValue.Add($_)}
      }
      else {
        $results | ForEach-Object {
          $result = $_
          log "Found user:" $result.path

          [void]$returnValue.Add($result)

          $properties = $result.Properties

          $groups = $properties["memberOf"]  | sort-object 
          log "  Member of $($groups.count) groups explicitly:"
          $groups| ForEach-Object {log "  " $_}

          $distinguishedName=$properties["distinguishedName"]

          $ugResult = Get-UserGroups -Searcher $Searcher -distinguishedName $distinguishedName[0]
          if($ugResult) {
            $ugGroups = $ugResult | ForEach-Object {$_.Properties["Distinguishedname"]} | where {$groups -notcontains $_} | sort-Object
          log "  Member of $($ugGroups.count) groups implicitly:"
            $ugGroups | ForEach-Object {log "  " $_}
          }

          log "  Properties"
          $properties.keys | Sort-Object | ForEach-Object {
                        $propertyKey = $_
            switch ($propertyKey) {
              # "msds-userpasswordexpirytimecomputed" { 
              #   write-properties -level 2 -key $propertyKey -property $properties[$propertyKey]
              #   write-properties -level 2 -key $propertyKey -property ([System.TimeSpan]::FromTicks(([long] $properties[$propertyKey][0])))
              #   write-properties -level 2 -key $propertyKey -property ([System.DateTime]::Now.AddTicks(([long] $properties[$propertyKey][0])))
              #  }
              Default {
                write-properties -level 2 -key $propertyKey -property $properties[$propertyKey]
              }
            }
          }
        }
      }
    }
  }
}
end {
  if($PassThrough) {
    $returnValue
  }
}
