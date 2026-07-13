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
  # Person Parameter Set
  [Parameter(Mandatory = $true, ParameterSetName = 'Person')]
  [string]$SamAccountName,
  # Group Parameter Set
  [Parameter(Mandatory = $true, ParameterSetName = 'Group')]
  [string]$GroupName,
  # Computer Parameter Set
  [Parameter(Mandatory = $true, ParameterSetName = 'Computer')]
  [string]$ComputerName,

  # Common Parameter Set
  $RootOU = "DC=LOCAL,DC=MAVIS-HQ,DC=COM",
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

    $filter = "(sAMAccountType=805306368)"
    if(![System.String]::IsNullOrWhiteSpace($userName)) {
        $filter = "(&$filter(samAccountName=*$userName*))"
    }

    log "Filter: $filter"
    $Searcher.Filter = $filter
    $Searcher.PropertiesToLoad.Clear()
    $Searcher.PropertiesToLoad.Add("distinguishedName") | out-null
    $Searcher.PropertiesToLoad.Add("memberOf") | out-null
    $Searcher.PropertiesToLoad.Add("msDS-UserPasswordExpiryTimeComputed") | out-null

    if ($VerbosePreference -ne 'SilentlyContinue') {
    # Verbose mode is currently active
      $Searcher.PropertiesToLoad.Add("*") | out-null
    }

    return $searcher.FindAll()
  }

  function Write-User() {
    param(
      [Parameter(ValueFromPipeline=$true)]
      $user,
      $searcher
    )
    process {
      log "Found user:" $user.path
      $properties = $user.Properties
      $groups = $properties["memberOf"]  | sort-object 
      log "  Member of $($groups.count) groups explicitly:"
      $groups| ForEach-Object {log "  " $_}
      $distinguishedName=$properties["distinguishedName"]
      $ugResult = Get-UserGroups -Searcher $searcher -distinguishedName $distinguishedName[0]
      if($ugResult) {
        $ugGroups = $ugResult | ForEach-Object {$_.Properties["Distinguishedname"]} | Where-Object {$groups -notcontains $_} | sort-Object
        
        log "  Member of $($ugGroups.count) groups implicitly:"
        $ugGroups | ForEach-Object {log "  " $_}
      }
      log "  Properties"
      $properties.keys | Sort-Object | ForEach-Object {
        $propertyKey = $_
        write-properties -level 2 -key $propertyKey -property $properties[$propertyKey]
      }
    }
  }

  function Get-Group() {
    param($Searcher, $groupName)

    $filter = "(sAMAccountType=268435456)"
    if(![System.String]::IsNullOrWhiteSpace($groupName)) {
        $filter = "(&$filter(name=*$groupName*))"
    }

    log "Filter: $filter"
    $Searcher.Filter = $filter
    $Searcher.PropertiesToLoad.Clear()  | out-null
    $Searcher.PropertiesToLoad.Add("member") | out-null

    if ($VerbosePreference -ne 'SilentlyContinue') {
    # Verbose mode is currently active
      $Searcher.PropertiesToLoad.Add("*") | out-null
    }

    return $searcher.FindAll()
  }

  function Write-Group() {
    param(
      [Parameter(ValueFromPipeline=$true)]
      $group,
      $searcher
    )
    process {
      log "Found group" $group.path
      $properties = $group.Properties

      log "  Members:"
      $properties["member"] | Sort-Object | ForEach-Object {log "  " $_}

      log "  Properties"
      $properties.keys | Sort-Object | ForEach-Object {
        $propertyKey = $_
        write-properties -level 2 -key $propertyKey -property $properties[$propertyKey]
      }
    }
  }

  function Get-Computer() {
    param($Searcher, $computerName)

    $filter = "(sAMAccountType=805306369)"
    if(![System.String]::IsNullOrWhiteSpace($computerName)) {
        $filter = "(&$filter(name=*$computerName*))"
    }

    log "Filter: $filter"
    $Searcher.Filter = $filter
    $Searcher.PropertiesToLoad.Clear()  | out-null
    $Searcher.PropertiesToLoad.Add("dNSHostName") | out-null

    if ($VerbosePreference -ne 'SilentlyContinue') {
    # Verbose mode is currently active
      $Searcher.PropertiesToLoad.Add("*") | out-null
    }

    return $searcher.FindAll()
  }
  function Write-Computer() {
    param(
      [Parameter(ValueFromPipeline=$true)]
      $computer,
      $searcher
    )
    process {
      log "Found computer" $computer.path
      $properties = $computer.Properties

      log "  Properties"
      $properties.keys | Sort-Object | ForEach-Object {
        $propertyKey = $_
        write-properties -level 2 -key $propertyKey -property $properties[$propertyKey]
      }
    }
  }
  
  function write-filetimeproperty() {
    param($level, $key, $property)
    $indent = "  " * $level
    $neverExpiresValues = @(9223372036854775807, 0)
    log "$($indent)$($key):"
    for ($i = 0; $i -lt $property.length; $i++ ) {
      log "$($indent)  Original Value[$i]: $($property[$i])"
      if ($neverExpiresValues -contains $property[$i]) {
        log "$($indent)  Computed Value([$i]: Never Expires"
      }
      else {
        log "$($indent)  Computed Value[$i]:" ([DateTime]::FromFileTime($property[$i]))
      }
    }
  }

  function write-properties(){
    param($level, $key, $property)
    $filetimeProperties = @("msds-userpasswordexpirytimecomputed", "pwdlastset", "usncreated", "usnchanged", "lastlogon", "lastlogontimestamp", "accountexpires")

    if ($filetimeProperties -contains $key) {
      write-filetimeproperty -level $level -key $key -property $property
      return
    }

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
    if($SamAccountName) {
      log "Searching for Person: $SamAccountName" -ForegroundColor Cyan
      $results = Get-User -Searcher $Searcher -userName $SamAccountName | sort Path
      $results | ForEach-Object {[void]$returnValue.Add($_)}
      if(!$PassThrough) {
        $results | Write-User -searcher $Searcher
      }
    }
    if ($GroupName) {
      log "Searching for Group: $GroupName" -ForegroundColor Green
      $results = Get-Group -Searcher $Searcher -groupName $GroupName | sort Path
      $results | ForEach-Object {[void]$returnValue.Add($_)}
      if(!$PassThrough) {
        $results | Write-Group -searcher $Searcher
      }
    }
    if ($ComputerName) {
      log "Searching for Computer: $ComputerName" -ForegroundColor Yellow
      $results = Get-Computer -Searcher $Searcher -computerName $ComputerName | sort Path
      $results | ForEach-Object {[void]$returnValue.Add($_)}
      if(!$PassThrough) {
        $results | Write-Computer -searcher $Searcher
      }
    }
  }
}
end {
  if($PassThrough) {
    $returnValue
  }
}
