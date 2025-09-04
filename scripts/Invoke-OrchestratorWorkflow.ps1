#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Trigger EasyPIM Orchestrator workflow via GitHub CLI

.DESCRIPTION
    This script provides an easy way to trigger the EasyPIM Orchestrator workflow
    with various parameters using GitHub CLI.

.PARAMETER WhatIf
    Preview mode - show what would be done without making changes (default: true)

.PARAMETER Mode
    Orchestrator execution mode: 'delta' (incremental) or 'initial' (destructive cleanup)

.PARAMETER SkipPolicies
    Skip policy operations (assignments only)

.PARAMETER SkipAssignments
    Skip assignment operations (policies only)

.PARAMETER Force
    Force execution (bypass confirmations)

.PARAMETER Verbose
    Enable verbose output

.PARAMETER ExportWouldRemove
    Export list of items that would be removed (audit purposes)

.PARAMETER Repository
    GitHub repository in format 'owner/repo' (default: 'kayasax/EasyPIM-CICD-test')

.EXAMPLE
    # Test run (WhatIf mode)
    .\Invoke-OrchestratorWorkflow.ps1 -WhatIf $true -Verbose $true

.EXAMPLE
    # Production run
    .\Invoke-OrchestratorWorkflow.ps1 -WhatIf $false -Mode delta -Force $true

.EXAMPLE
    # Policies only
    .\Invoke-OrchestratorWorkflow.ps1 -SkipAssignments $true -Verbose $true

.EXAMPLE
    # Different repository
    .\Invoke-OrchestratorWorkflow.ps1 -Repository "myorg/my-easypim-repo" -WhatIf $true
#>

param(
    [bool]$WhatIf = $true,

    [ValidateSet("delta", "initial")]
    [string]$Mode = "delta",

    [bool]$SkipPolicies = $false,

    [bool]$SkipAssignments = $false,

    [bool]$Force = $false,

    [bool]$Verbose = $false,

    [bool]$ExportWouldRemove = $false,

    [string]$Repository = "kayasax/EasyPIM-CICD-test"
)

# Check if GitHub CLI is installed
try {
    $ghVersion = gh --version
    Write-Host "✅ GitHub CLI found: $($ghVersion[0])" -ForegroundColor Green
} catch {
    Write-Error "❌ GitHub CLI not found. Please install it first: winget install --id GitHub.cli"
    exit 1
}

# Check authentication
try {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ GitHub CLI not authenticated. Please run: gh auth login"
        exit 1
    }
    Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green
} catch {
    Write-Error "❌ GitHub CLI authentication check failed. Please run: gh auth login"
    exit 1
}

# Display configuration
Write-Host "`n🚀 EasyPIM Orchestrator Workflow Trigger" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host "Repository: $Repository" -ForegroundColor White
Write-Host "Parameters:" -ForegroundColor Yellow
Write-Host "  WhatIf: $WhatIf" -ForegroundColor White
Write-Host "  Mode: $Mode" -ForegroundColor White
Write-Host "  SkipPolicies: $SkipPolicies" -ForegroundColor White
Write-Host "  SkipAssignments: $SkipAssignments" -ForegroundColor White
Write-Host "  Force: $Force" -ForegroundColor White
Write-Host "  Verbose: $Verbose" -ForegroundColor White
Write-Host "  ExportWouldRemove: $ExportWouldRemove" -ForegroundColor White

if ($WhatIf) {
    Write-Host "`n🔍 Running in WhatIf mode (preview only)" -ForegroundColor Yellow
} else {
    Write-Host "`n⚡ Running in APPLY mode (changes will be made)" -ForegroundColor Red
}

if ($Mode -eq "initial") {
    Write-Host "⚠️  DESTRUCTIVE MODE: Will remove assignments not in config" -ForegroundColor Red
}

# Confirm execution
$confirm = Read-Host "`nDo you want to trigger the workflow? (y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "❌ Operation cancelled by user" -ForegroundColor Yellow
    exit 0
}

# Trigger workflow
Write-Host "`n🔄 Triggering workflow..." -ForegroundColor Cyan

try {
    $result = gh workflow run "02-orchestrator-test.yml" `
        --repo $Repository `
        -f WhatIf=$WhatIf `
        -f Mode=$Mode `
        -f SkipPolicies=$SkipPolicies `
        -f SkipAssignments=$SkipAssignments `
        -f Force=$Force `
        -f Verbose=$Verbose `
        -f ExportWouldRemove=$ExportWouldRemove

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Workflow triggered successfully!" -ForegroundColor Green

        # Wait a moment for the workflow to start
        Start-Sleep -Seconds 3

        # Get the latest run
        Write-Host "`n📊 Getting workflow status..." -ForegroundColor Cyan
        $runs = gh run list --repo $Repository --workflow "02-orchestrator-test.yml" --limit 1 --json databaseId,status,conclusion,url,createdAt

        if ($runs) {
            $run = $runs | ConvertFrom-Json | Select-Object -First 1
            Write-Host "🔗 Workflow URL: $($run.url)" -ForegroundColor Cyan
            Write-Host "📅 Started: $($run.createdAt)" -ForegroundColor White
            Write-Host "📊 Status: $($run.status)" -ForegroundColor White

            # Ask if user wants to watch the workflow
            $watch = Read-Host "`nWatch workflow progress? (y/N)"
            if ($watch -match '^[Yy]') {
                Write-Host "👀 Watching workflow (press Ctrl+C to stop watching)..." -ForegroundColor Cyan
                gh run watch $run.databaseId --repo $Repository
            }
        }
    } else {
        Write-Error "❌ Failed to trigger workflow"
        exit 1
    }
} catch {
    Write-Error "❌ Error triggering workflow: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n🎉 Workflow trigger completed!" -ForegroundColor Green
Write-Host "📝 Check the Actions tab in your repository for execution details" -ForegroundColor Cyan
Write-Host "🔗 https://github.com/$Repository/actions" -ForegroundColor Cyan
