# Automated code review assistance script for Windows
# Provides automated feedback and suggestions for code changes

param(
    [string]$BaseBranch = "origin/main"
)

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue
$DefaultColor = [System.Console]::ForegroundColor

function Write-Status {
    param(
        [string]$Status,
        [string]$Message
    )
    
    switch ($Status) {
        "INFO" {
            [System.Console]::ForegroundColor = $Blue
            Write-Host "ℹ $Message"
        }
        "SUGGESTION" {
            [System.Console]::ForegroundColor = $Yellow
            Write-Host "💡 $Message"
        }
        "ISSUE" {
            [System.Console]::ForegroundColor = $Red
            Write-Host "⚠ $Message"
        }
        "GOOD" {
            [System.Console]::ForegroundColor = $Green
            Write-Host "✓ $Message"
        }
    }
    [System.Console]::ForegroundColor = $DefaultColor
}

Write-Host "🤖 Running automated code review assistance..." -ForegroundColor Cyan

# Check if we're in a git repository
try {
    git rev-parse --git-dir | Out-Null
}
catch {
    Write-Status "ISSUE" "Not in a git repository"
    exit 1
}

# Get changed files
$changedFiles = git diff --name-only "$BaseBranch...HEAD"
if (-not $changedFiles) {
    Write-Status "INFO" "No files changed"
    exit 0
}

Write-Host "📁 Analyzing $($changedFiles.Count) changed files..." -ForegroundColor Cyan

# 1. Analyze code complexity
Write-Host ""
Write-Host "🧮 Code Complexity Analysis:" -ForegroundColor Cyan

foreach ($file in $changedFiles) {
    if ($file -match "\.(rs|ts|tsx|js|jsx|py|go)$" -and (Test-Path $file)) {
        # Count lines of code
        $loc = (Get-Content $file).Count
        
        # Count functions/methods
        $content = Get-Content $file -Raw
        $functions = 0
        
        switch -Regex ($file) {
            "\.rs$" {
                $functions = ([regex]::Matches($content, "fn ")).Count
            }
            "\.(ts|tsx|js|jsx)$" {
                $functions = ([regex]::Matches($content, "(function|=>|\bclass\b)")).Count
            }
            "\.py$" {
                $functions = ([regex]::Matches($content, "def ")).Count
            }
            "\.go$" {
                $functions = ([regex]::Matches($content, "func ")).Count
            }
        }
        
        # Analyze complexity
        if ($loc -gt 500) {
            Write-Status "ISSUE" "$file`: Large file ($loc lines) - consider splitting"
        } elseif ($loc -gt 200) {
            Write-Status "SUGGESTION" "$file`: Consider breaking down large file ($loc lines)"
        }
        
        if ($functions -gt 20) {
            Write-Status "SUGGESTION" "$file`: Many functions ($functions) - consider organizing into modules"
        }
    }
}

# 2. Security analysis
Write-Host ""
Write-Host "🔒 Security Analysis:" -ForegroundColor Cyan

$securityPatterns = @(
    "password.*=.*[`"'].*[`"']",
    "api[_-]?key.*=.*[`"'].*[`"']",
    "secret.*=.*[`"'].*[`"']",
    "token.*=.*[`"'].*[`"']",
    "unsafe",
    "eval\(",
    "innerHTML",
    "dangerouslySetInnerHTML"
)

foreach ($file in $changedFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        
        foreach ($pattern in $securityPatterns) {
            if ($content -match $pattern) {
                Write-Status "ISSUE" "$file`: Potential security issue - review pattern: $pattern"
            }
        }
        
        # Check for TODO/FIXME comments
        if ($content -match "(TODO|FIXME|XXX|HACK)") {
            Write-Status "SUGGESTION" "$file`: Contains TODO/FIXME comments - consider addressing"
        }
    }
}

# 3. Performance analysis
Write-Host ""
Write-Host "⚡ Performance Analysis:" -ForegroundColor Cyan

foreach ($file in $changedFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        
        switch -Regex ($file) {
            "\.rs$" {
                if ($content -match "clone\(\)") {
                    Write-Status "SUGGESTION" "$file`: Consider if all clone() calls are necessary"
                }
                if ($content -match "unwrap\(\)") {
                    Write-Status "SUGGESTION" "$file`: Consider proper error handling instead of unwrap()"
                }
            }
            "\.(ts|tsx|js|jsx)$" {
                if ($content -match "for.*in.*") {
                    Write-Status "SUGGESTION" "$file`: Consider using for...of or array methods for better performance"
                }
                if ($content -match "(document\.getElementById|document\.querySelector)") {
                    Write-Status "SUGGESTION" "$file`: Consider caching DOM queries"
                }
            }
            "\.py$" {
                if ($content -match "for.*in.*range\(len\(") {
                    Write-Status "SUGGESTION" "$file`: Consider using enumerate() instead of range(len())"
                }
            }
        }
    }
}

# 4. Code style and best practices
Write-Host ""
Write-Host "🎨 Code Style Analysis:" -ForegroundColor Cyan

foreach ($file in $changedFiles) {
    if (Test-Path $file) {
        $lines = Get-Content $file
        $longLines = $lines | Where-Object { $_.Length -gt 120 }
        
        if ($longLines) {
            Write-Status "SUGGESTION" "$file`: Some lines exceed 120 characters"
        }
        
        $content = Get-Content $file -Raw
        
        switch -Regex ($file) {
            "\.rs$" {
                if ($content -match "fn [a-z]*[A-Z]") {
                    Write-Status "SUGGESTION" "$file`: Use snake_case for function names in Rust"
                }
            }
            "\.(ts|tsx|js|jsx)$" {
                if ($content -match "function [a-z]*_[a-z]") {
                    Write-Status "SUGGESTION" "$file`: Use camelCase for function names in TypeScript/JavaScript"
                }
            }
        }
    }
}

# 5. Test coverage analysis
Write-Host ""
Write-Host "🧪 Test Coverage Analysis:" -ForegroundColor Cyan

$testFiles = $changedFiles | Where-Object { $_ -match "(test|spec)" }
$sourceFiles = $changedFiles | Where-Object { $_ -notmatch "(test|spec)" -and $_ -match "\.(rs|ts|tsx|js|jsx|py|go)$" }

if ($sourceFiles) {
    $sourceCount = $sourceFiles.Count
    $testCount = if ($testFiles) { $testFiles.Count } else { 0 }
    
    if (-not $testFiles) {
        Write-Status "ISSUE" "No test files found for $sourceCount changed source files"
    } elseif ($testCount -lt [math]::Floor($sourceCount / 2)) {
        Write-Status "SUGGESTION" "Consider adding more tests (found $testCount test files for $sourceCount source files)"
    } else {
        Write-Status "GOOD" "Good test coverage ratio ($testCount test files for $sourceCount source files)"
    }
}

# 6. Documentation analysis
Write-Host ""
Write-Host "📚 Documentation Analysis:" -ForegroundColor Cyan

$docFiles = $changedFiles | Where-Object { $_ -match "\.md$" }
if ($sourceFiles -and -not $docFiles) {
    Write-Status "SUGGESTION" "Consider updating documentation for code changes"
}

# Check for API changes that might need documentation
$apiChanges = (git diff "$BaseBranch...HEAD" | Select-String "^[+].*pub |^[+].*export ").Count
if ($apiChanges -gt 0) {
    Write-Status "SUGGESTION" "API changes detected ($apiChanges) - ensure documentation is updated"
}

# 7. Dependency analysis
Write-Host ""
Write-Host "📦 Dependency Analysis:" -ForegroundColor Cyan

$depFiles = $changedFiles | Where-Object { $_ -match "(Cargo\.toml|package\.json|requirements\.txt|go\.mod)" }
if ($depFiles) {
    Write-Status "INFO" "Dependency files changed - ensure security scanning is run"
    
    # Check for version pinning
    foreach ($depFile in $depFiles) {
        if ($depFile -eq "package.json" -and (Test-Path $depFile)) {
            $content = Get-Content $depFile -Raw
            $unpinned = ([regex]::Matches($content, '"[^"]*": "\^|~')).Count
            if ($unpinned -gt 0) {
                Write-Status "SUGGESTION" "$depFile`: Consider pinning dependency versions for reproducible builds"
            }
        }
    }
}

# 8. Generate summary
Write-Host ""
Write-Host "📋 Code Review Summary:" -ForegroundColor Cyan

Write-Host "  Files analyzed: $($changedFiles.Count)"
Write-Host "  Source files: $(if ($sourceFiles) { $sourceFiles.Count } else { 0 })"
Write-Host "  Test files: $(if ($testFiles) { $testFiles.Count } else { 0 })"

Write-Status "INFO" "Automated review complete. Please address any issues and consider suggestions."
Write-Status "INFO" "Remember: This is automated analysis. Human review is still essential!"

Write-Host ""
Write-Host "🔗 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Address any security issues immediately"
Write-Host "  2. Consider refactoring suggestions for maintainability"
Write-Host "  3. Ensure adequate test coverage"
Write-Host "  4. Update documentation as needed"
Write-Host "  5. Run full quality gates before merging"