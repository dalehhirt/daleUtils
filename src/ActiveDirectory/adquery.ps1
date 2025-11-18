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
    write-host ">>> [$($env:COMPUTERNAME)]" ((Get-Date).ToUniversalTime().ToString('u')) "$args" -ForeGroundColor Green
  }

  function log-verbose() {
    write-verbose ">>> [$($env:COMPUTERNAME)] $((Get-Date).ToUniversalTime().ToString('u')) $args"
  }

  function Using-Object
  {
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
    # param($rootOu, $username)
    # #$LDAPGroupMemberFilterRecursive = "&(member:1.2.840.113556.1.4.1941:={0})(objectClass=user)(sAMAccountName={1})"
    $LDAPGroupMemberFilterRecursive = "(member:1.2.840.113556.1.4.1941:={0})"
    # $user = Get-User -rootOu $rootOu -userName $username
    # $container = $user.GetDirectoryEntry().distinguishedName.ToString()
    # $foundName = $user.GetDirectoryEntry().name.ToString()
    # Using-Object($Searcher = New-Object DirectoryServices.DirectorySearcher) {
      #$Searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($rootOu)")
      $Searcher.Filter = $LDAPGroupMemberFilterRecursive -f $distinguishedName#, $foundName
      $Searcher.PropertiesToLoad.Clear()
      $Searcher.SearchScope = [DirectoryServices.SearchScope]::Subtree
      return $searcher.FindAll()
    # }
  }

  function Get-User() {
    param($rootOu, $userName)

    $filter = "(&(objectClass=user)(samAccountName=*$userName*))"
    $Searcher.Filter = $filter
    $Searcher.PropertiesToLoad.Clear()
    $Searcher.PropertiesToLoad.Add("memberOf") | out-null
    $Searcher.PropertiesToLoad.Add("*") | out-null
    return $searcher.FindAll()
  }

  function Get-Group() {
    param($Searcher, $groupName)

    $filter = "(&(objectClass=group)(name=*$groupName*))"
    $Searcher.Filter = $filter
    $Searcher.PropertiesToLoad.Clear()  | out-null
    $Searcher.PropertiesToLoad.Add("member") | out-null
    $Searcher.PropertiesToLoad.Add("*") | out-null
    return $searcher.FindAll()
  }

  function display-properties(){
    param($level, $key, $property)
    $indent = "  " * $level
    if($property -is [System.DirectoryServices.ResultPropertyValueCollection] ) {
      $val = "$indent$key = ["

      $val += ($property | sort) -join ","
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
    $Searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($rootOu)")
    $Searcher.PageSize = 1001  # This should enable us to get all objects
    if($group) {
      $results = Get-Group $Searcher $name
      if($PassThrough) {
        $results | foreach {[void]$returnValue.Add($_)}
      }
      else {
        $results | ForEach-Object {
          $result = $_
          log "Found group"
          [void]$returnValue.Add($result)
          $properties = $result.Properties

          log "Members:"
          $properties["member"] | foreach {log "  " $_}
          log "Properties"
          $properties.keys | foreach {display-properties -level 1 -key $_ -property $properties[$_]}
        }
      }
    }
    else {
      $results = Get-User $Searcher $name
      if($PassThrough) {
        $results | foreach {[void]$returnValue.Add($_)}
      }
      else {
        $results | foreach {
          $result = $_
          log "Found user:" $result.path

          [void]$returnValue.Add($result)

          $properties = $result.Properties

          $groups = $properties["memberOf"]  | sort-object 
          log "Member of $($groups.count) groups explicitly:"
          $groups| foreach {log "  " $_}

          $distinguishedName=$properties["distinguishedName"]

          $ugResult = Get-UserGroups -Searcher $Searcher -distinguishedName $distinguishedName[0]
          if($ugResult) {
            $ugGroups = $ugResult | foreach {$_.Properties["Distinguishedname"]} | where {$groups -notcontains $_} | sort-Object
          log "Member of $($ugGroups.count) groups implicitly:"
            $ugGroups | foreach {log "  " $_}
          }

          log "Properties"
          $properties.keys | foreach {display-properties -level 1 -key $_ -property $properties[$_]}
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
