<#
.SYNOPSIS
    Remux MKV files with their tracks in a consistent order and consistent flags.

.DESCRIPTION
    Each file's tracks are read with 'mkvmerge -J', so every file gets its own
    --track-order no matter how its tracks are arranged. The output order is:

      1. Video
      2. Audio, in -AudioOrder language order (default Japanese, then English)
      3. Any other audio
      4. Commentary audio
      5. Full subtitles (subtitles that aren't signs or commentary)
      6. Signs subtitles (track name matches -SignsPattern; if no name matches,
         a subtitle already flagged forced)
      7. Commentary subtitles
      8. Anything else

    Commentary tracks are those whose name matches -CommentaryPattern, or that
    already have the commentary flag.

    Tracks keep their original relative order within each group. Attachments
    (fonts), chapters and tags are copied unchanged.

    Flags and names are also set:

      * Default: the first video, the first non-commentary audio in the first
        -AudioOrder language (Japanese), and the first English full subtitle.
        All other tracks are set to not default.
      * Forced: the signs subtitle track(s) only. All other tracks are cleared.
      * Commentary: commentary tracks only. All other tracks are cleared.
      * Names: the file title and every track name are removed, except signs
        tracks, which are named -SignsSubName ('Titles & Signs').
      * Language: audio and subtitle tracks with no language set (und) get one
        from their track name, using -LanguageWords (e.g. 'Japanese', 'JPN',
        'JP' -> jpn; 'English', 'ENG', 'EN' -> eng). This happens before the
        order is worked out, and the language is written to the output file.
        A signs track still without a language is set to -SignsLanguage (eng).

    While remuxing, a progress bar shows the current file and its percentage.

.PARAMETER Path
    MKV files or folders to process. Default: *.mkv in the current folder.

.PARAMETER Destination
    Folder for the remuxed files. Must not be the folder the source is in.

.PARAMETER AudioOrder
    Audio languages in the order wanted. Matches either the ISO 639-2 code
    (jpn, eng) or the IETF tag (ja, en) mkvmerge reports for each track.

.PARAMETER SignsPattern
    Regular expression (case-insensitive) matched against subtitle track names
    to pick out signs/songs tracks. Default: 'sign|song|title'.

.PARAMETER CommentaryPattern
    Regular expression (case-insensitive) matched against audio and subtitle
    track names to pick out commentary tracks. Default: 'commentary'.

.PARAMETER SignsSubName
    Name given to the signs subtitle track(s). Default: 'Titles & Signs'.

.PARAMETER SignsLanguage
    Language given to a signs track that has none (und) and none in its name.
    Default: 'eng'.

.PARAMETER DefaultSubLanguage
    Language of the full subtitle track to mark as default. Default: 'eng'.

.PARAMETER LanguageWords
    Words to look for in the name of a track with no language, as a hashtable of
    ISO 639-2 code -> regular expression alternatives. Words only match whole,
    so 'en' matches 'Subs [EN]' but not 'Opening'.
    Default: @{ jpn = 'japanese|jpn|jap|jp|ja'; eng = 'english|eng|en' }

.PARAMETER MkvMerge
    Path to mkvmerge.exe.

.EXAMPLE
    .\mkv-reorder.ps1 -Path V:\bdrips -Destination X:\import -WhatIf
    Show the track order and flags that would be used for each file, without remuxing.

.EXAMPLE
    .\mkv-reorder.ps1 -Path V:\bdrips -Destination X:\import
    Reorder, set flags and clean up names.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]] $Path = @('.'),

    [Parameter(Mandatory)]
    [string] $Destination,

    [string[]] $AudioOrder = @('jpn', 'eng'),

    [string] $SignsPattern = 'sign|song|title',

    [string] $CommentaryPattern = 'commentary',

    [string] $SignsSubName = 'Titles & Signs',

    [string] $SignsLanguage = 'eng',

    [string] $DefaultSubLanguage = 'eng',

    [hashtable] $LanguageWords = @{ jpn = 'japanese|jpn|jap|jp|ja'; eng = 'english|eng|en' },

    [string] $MkvMerge = 'C:\Program Files\MKVToolNix\mkvmerge.exe'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $MkvMerge)) {
    throw "mkvmerge not found at '$MkvMerge'. Pass -MkvMerge with the right path."
}

# True if a track's language matches a code like 'jpn' or 'ja'
function Test-Language($Track, [string] $Code) {
    $props = $Track.properties
    if ($props.language -eq $Code) { return $true }
    $ietf = [string] $props.language_ietf
    return ($ietf -eq $Code -or $ietf -like "$Code-*")
}

# IETF tags for the guessable languages, so -AudioOrder 'ja'/'en' still matches
$ietfTags = @{ jpn = 'ja'; eng = 'en' }

# For audio/subtitle tracks with no language, set one from words in the track
# name. Updates the tracks in place and returns the ones that were changed.
function Set-LanguageFromName($Tracks) {
    foreach ($track in $Tracks) {
        if ($track.type -notin 'audio', 'subtitles') { continue }
        $language = [string] $track.properties.language
        if ($language -and $language -ne 'und') { continue }

        $name = [string] $track.properties.track_name
        $found = @($LanguageWords.Keys | Where-Object {
            $name -match "(?<![a-z0-9])(?:$($LanguageWords[$_]))(?![a-z0-9])"
        })

        if ($found.Count -eq 1) {
            $code = $found[0]
            $track.properties | Add-Member -Force NoteProperty language $code
            $track.properties | Add-Member -Force NoteProperty language_ietf $ietfTags[$code]
            $track
        } elseif ($found.Count -gt 1) {
            Write-Warning "Track $($track.id) '$name' names more than one language ($($found -join ', ')); left as und."
        }
    }
}

# Short description of a track for the console, e.g. "2 audio jpn 'Commentary'"
function Format-Track($Track) {
    $name = if ($Track.properties.track_name) { " '$($Track.properties.track_name)'" } else { '' }
    "$($Track.id) $($Track.type) $($Track.properties.language)$name"
}

# True if a track is named like a commentary track or already flagged as one
function Test-Commentary($Track) {
    $Track.properties.track_name -match $CommentaryPattern -or $Track.properties.flag_commentary
}

# Build the ordered list of tracks for one file, tagging subtitle tracks as
# Full, Signs or Commentary and picking the default tracks
function Get-TrackOrder($Tracks) {
    $video = @($Tracks | Where-Object type -eq 'video')
    $other = @($Tracks | Where-Object { $_.type -notin 'video', 'audio', 'subtitles' })

    # Commentary audio and subtitles are split off and go last within their type
    $allAudio = @($Tracks | Where-Object type -eq 'audio')
    $allSubs  = @($Tracks | Where-Object type -eq 'subtitles')
    $commentaryAudio = @($allAudio | Where-Object { Test-Commentary $_ })
    $commentarySubs  = @($allSubs | Where-Object { Test-Commentary $_ })
    $audio     = @($allAudio | Where-Object { $_ -notin $commentaryAudio })
    $subtitles = @($allSubs | Where-Object { $_ -notin $commentarySubs })

    # Audio: wanted languages first, in -AudioOrder order, then the rest
    $orderedAudio = [System.Collections.Generic.List[object]]::new()
    foreach ($code in $AudioOrder) {
        foreach ($track in $audio) {
            if (-not $orderedAudio.Contains($track) -and (Test-Language $track $code)) {
                $orderedAudio.Add($track)
            }
        }
    }
    foreach ($track in $audio) {
        if (-not $orderedAudio.Contains($track)) { $orderedAudio.Add($track) }
    }

    # Subtitles: a signs track is one named like one. Source flags are often
    # wrong, so the forced flag is only used when no track name matches.
    $signs = @($subtitles | Where-Object { $_.properties.track_name -match $SignsPattern })
    if (-not $signs.Count -and $subtitles.Count -gt 1) {
        $signs = @($subtitles | Where-Object { $_.properties.forced_track })
    }
    $full = @($subtitles | Where-Object { $_ -notin $signs })

    # Default tracks: first video, first audio in the preferred language, first
    # full subtitle in -DefaultSubLanguage (falling back to the first of each)
    $defaultAudio = $orderedAudio | Where-Object { Test-Language $_ $AudioOrder[0] } | Select-Object -First 1
    if (-not $defaultAudio) { $defaultAudio = $orderedAudio | Select-Object -First 1 }
    $defaultSub = $full | Where-Object { Test-Language $_ $DefaultSubLanguage } | Select-Object -First 1
    if (-not $defaultSub) { $defaultSub = $full | Select-Object -First 1 }
    $defaults = @(($video | Select-Object -First 1), $defaultAudio, $defaultSub) | Where-Object { $_ }

    [pscustomobject] @{
        Order      = @($video) + $orderedAudio + $commentaryAudio + $full + $signs + $commentarySubs + $other
        Full       = $full
        Signs      = $signs
        Commentary = $commentaryAudio + $commentarySubs
        Audio      = $orderedAudio
        Defaults   = @($defaults)
    }
}

# Windows PowerShell (and PowerShell 7 in Legacy mode) drops empty string
# arguments to programs, so an empty value has to be passed as a literal ""
$emptyArg = if ((Get-Variable PSNativeCommandArgumentPassing -ValueOnly -ErrorAction Ignore) -in 'Standard', 'Windows') { '' } else { '""' }

# Resolve without requiring the folder to exist, so -WhatIf works before it is created
$destinationDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination).TrimEnd('\')
if (-not (Test-Path -LiteralPath $destinationDir)) {
    New-Item -ItemType Directory -Path $destinationDir | Out-Null
}

$files = @(foreach ($item in $Path) {
    if (Test-Path -LiteralPath $item -PathType Container) {
        Get-ChildItem -LiteralPath $item -Filter '*.mkv' -File
    } else {
        Get-Item -LiteralPath $item
    }
})

$failed = 0
$index = 0
foreach ($file in $files) {
    $index++
    if ($file.DirectoryName -eq $destinationDir) {
        Write-Warning "Skipping '$($file.Name)': destination is its own folder."
        continue
    }

    Write-Host "`n$($file.Name)" -ForegroundColor Cyan

    $info = & $MkvMerge -J $file.FullName | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $info.container.recognized) {
        Write-Warning "Could not read tracks from '$($file.Name)'."
        $failed++
        continue
    }

    $guessed = @(Set-LanguageFromName $info.tracks)
    $plan = Get-TrackOrder $info.tracks

    # A signs track with no language anywhere gets -SignsLanguage
    $defaulted = @(foreach ($track in $plan.Signs) {
        $language = [string] $track.properties.language
        if (-not $language -or $language -eq 'und') {
            $track.properties | Add-Member -Force NoteProperty language $SignsLanguage
            $track.properties | Add-Member -Force NoteProperty language_ietf $ietfTags[$SignsLanguage]
            $track
        }
    })

    foreach ($track in $plan.Order) {
        $tags = @()
        if ($guessed -contains $track) { $tags += 'language from name' }
        if ($defaulted -contains $track) { $tags += 'language defaulted' }
        if ($plan.Full -contains $track) { $tags += 'full' }
        if ($plan.Signs -contains $track) { $tags += 'signs', 'forced' }
        if ($plan.Commentary -contains $track) { $tags += 'commentary' }
        if ($plan.Defaults -contains $track) { $tags += 'default' }
        $tag = if ($tags) { "  [$($tags -join ', ')]" } else { '' }
        Write-Host "  $(Format-Track $track)$tag"
    }

    # Point out anything the order could not be sure about
    if (@($plan.Audio | Where-Object { $t = $_; -not ($AudioOrder | Where-Object { Test-Language $t $_ }) }).Count) {
        Write-Warning "Some audio tracks are not in -AudioOrder and were placed after the others."
    }
    if ($plan.Full.Count -gt 1 -or $plan.Signs.Count -gt 1) {
        Write-Warning "More than one full or signs subtitle track; check the order above."
    }

    if (-not $plan.Signs.Count) {
        Write-Warning "No signs subtitle track found; no track will be forced."
    }

    # --gui-mode makes mkvmerge print progress as '#GUI#progress N%' lines
    $arguments = @('--ui-language', 'en', '--priority', 'lower', '--gui-mode', '--output', (Join-Path $destinationDir $file.Name))
    $arguments += '--title', $emptyArg

    # Per-track options must come before the input file they apply to
    foreach ($track in $plan.Order) {
        $id = $track.id
        $isSigns = $plan.Signs -contains $track

        # Clear every track name except the signs track's
        $name = if ($isSigns) { $SignsSubName } else { '' }
        $arguments += '--track-name', "${id}:$name"

        if ($guessed -contains $track -or $defaulted -contains $track) {
            $arguments += '--language', "${id}:$($track.properties.language)"
        }

        if ($track.type -in 'video', 'audio', 'subtitles') {
            $arguments += '--default-track-flag', "${id}:$(if ($plan.Defaults -contains $track) { 1 } else { 0 })"
            $arguments += '--forced-display-flag', "${id}:$(if ($isSigns) { 1 } else { 0 })"
            $arguments += '--commentary-flag', "${id}:$(if ($plan.Commentary -contains $track) { 1 } else { 0 })"
        }
    }
    $arguments += $file.FullName
    $arguments += '--track-order', (($plan.Order | ForEach-Object { "0:$($_.id)" }) -join ',')

    if ($PSCmdlet.ShouldProcess($file.Name, "Remux to $destinationDir")) {
        $activity = "Remuxing file $index of $($files.Count)"
        Write-Progress -Id 1 -Activity $activity -Status "$($file.Name): 0%" -PercentComplete 0

        # Show progress as a bar; pass warnings, errors and the timing line through
        & $MkvMerge @arguments | ForEach-Object {
            if ($_ -match '^#GUI#progress (\d+)%') {
                $percent = [int] $Matches[1]
                Write-Progress -Id 1 -Activity $activity -Status "$($file.Name): $percent%" -PercentComplete $percent
            } elseif ($_ -match '^(?:#GUI#)?(warning|error)\b:?\s*(.*)') {
                Write-Host "  $($Matches[1].ToUpper()): $($Matches[2])" -ForegroundColor Yellow
            } elseif ($_ -match '^Multiplexing took') {
                Write-Host "  $_"
            }
        }
        Write-Progress -Id 1 -Activity $activity -Completed

        # mkvmerge: 0 = success, 1 = success with warnings, 2 = error
        if ($LASTEXITCODE -ge 2) {
            Write-Warning "mkvmerge failed on '$($file.Name)'."
            $failed++
        }
    }
}

if ($failed) {
    Write-Warning "$failed file(s) failed."
    exit 1
}
