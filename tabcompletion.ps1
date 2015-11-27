$global:DockerCompletion = @{}

$script:flagRegex = "^  (-[^, =]+),? ?(--[^= ]+)?"

function script:Get-Containers($filter)
{
    if ($filter -eq $null)
    {
       docker ps -a --no-trunc --format "{{.Names}}"
    } else {
       docker ps -a --no-trunc --format "{{.Names}}" --filter $filter
    }
}

function script:Get-AutoCompleteResult
{
    param([Parameter(ValueFromPipeline=$true)] $value)
    
    Process
    {
        New-Object System.Management.Automation.CompletionResult $value
    }
}

filter script:MatchingCommand($commandName)
{
    if ($_.StartsWith($commandName))
    {
        $_
    }
}

$completion_Docker = {
    param($commandName, $commandAst, $cursorPosition)

    $command = $null
    $commandParameters = @{}
    $state = "Unknown"
    $wordToComplete = $commandAst.CommandElements | Where-Object { $_.ToString() -eq $commandName } | Foreach-Object { $commandAst.CommandElements.IndexOf($_) }

    for ($i=1; $i -lt $commandAst.CommandElements.Count; $i++)
    {
        $p = $commandAst.CommandElements[$i].ToString()

        if ($p.StartsWith("-"))
        {
            if ($state -eq "Unknown" -or $state -eq "Options")
            {
                $commandParameters[$i] = "Option"
                $state = "Options"
            }
            else
            {
                $commandParameters[$i] = "CommandOption"
                $state = "CommandOptions"
            }
        } 
        else 
        {
            if ($state -ne "CommandOptions")
            {
                $commandParameters[$i] = "Command"
                $command = $p
                $state = "CommandOptions"
            } 
            else 
            {
                $commandParameters[$i] = "CommandOther"
            }
        }
    }

    if ($global:DockerCompletion.Count -eq 0)
    {
        $global:DockerCompletion["commands"] = @{}
        $global:DockerCompletion["options"] = @()
        
        docker --help | ForEach-Object {
            Write-Output $_
            if ($_ -match "^    (\w+)\s+(.+)")
            {
                $global:DockerCompletion["commands"][$Matches[1]] = @{}
                
                $currentCommand = $global:DockerCompletion["commands"][$Matches[1]]
                $currentCommand["options"] = @()
            }
            elseif ($_ -match $flagRegex)
            {
                $global:DockerCompletion["options"] += $Matches[1]
                if ($Matches[2] -ne $null)
                {
                    $global:DockerCompletion["options"] += $Matches[2]
                 }
        }

    }
    
    if ($wordToComplete -eq $null)
    {
        $commandToComplete = "Command"
        if ($commandParameters.Count -gt 0)
        {
            if ($commandParameters[$commandParameters.Count] -eq "Command")
            {
                $commandToComplete = "CommandOther"
            }
        } 
    } else {
        $commandToComplete = $commandParameters[$wordToComplete]
    }

    switch ($commandToComplete)
    {
        "Command" { $global:DockerCompletion["commands"].Keys | MatchingCommand -Command $commandName | Sort-Object | Get-AutoCompleteResult }
        "Option" { $global:DockerCompletion["options"] | MatchingCommand -Command $commandName | Sort-Object | Get-AutoCompleteResult }
        "CommandOption" { 
            $options = $global:DockerCompletion["commands"][$command]["options"]
            if ($options.Count -eq 0)
            {
                docker $command --help | % {
                if ($_ -match $flagRegex)
                    {
                        $options += $Matches[1]
                        if ($Matches[2] -ne $null)
                        {
                            $options += $Matches[2]
                        }
                    }
                }
            }

            $global:DockerCompletion["commands"][$command]["options"] = $options
            $options | MatchingCommand -Command $commandName | Sort-Object | Get-AutoCompleteResult
        }
        "CommandOther" {
            $filter = $null 
            switch ($command)
            {
                "start" { $filter = "status=exited" }
                "stop" { $filter = "status=running" }
            }
            Get-Containers $filter | MatchingCommand -Command $commandName | Sort-Object | Get-AutoCompleteResult
        }
        default { $global:DockerCompletion["commands"].Keys | MatchingCommand -Command $commandName }
    }
}

# Register the TabExpension2 function
if (-not $global:options) { $global:options = @{CustomArgumentCompleters = @{};NativeArgumentCompleters = @{}}}
$global:options['NativeArgumentCompleters']['docker'] = $Completion_Docker

$function:tabexpansion2 = $function:tabexpansion2 -replace 'End\r\n{','End { if ($null -ne $options) { $options += $global:options} else {$options = $global:options}'