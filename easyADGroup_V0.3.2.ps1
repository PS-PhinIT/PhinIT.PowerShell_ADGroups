<#
  ####################################################################################################
  # easyADgroup - PowerShell GUI for Active Directory Group Management
  # Author:         Andreas Hepp
  # Website:        https://phinit.de/easyit-tools/
  # GitHub:         https://github.com/PS-PhinIT/PhinIT.PowerShell_ADGroups
  # Version:        0.3.2 (Build: 2026-10-14)
  ####################################################################################################

  WPF-based GUI for creating Active Directory groups.

  Features:
  - Single group, number range and JIRA/Confluence group sets (suffixes)
  - Optional naming template (Auto-Naming)
  - Group members from user list and/or fixed members from configuration
  - Validation (invalid characters, length, SAM collisions, duplicates, OU existence)
  - Test run (dry run) mode
  - CSV template export and CSV bulk import
  - JSON templates (save/load form configuration)
  - Optional e-mail notification via SMTP
  - Text report and log files

  Requirements:
  - Windows PowerShell 5.1 or PowerShell 7+ (Windows, STA mode)
  - ActiveDirectory PowerShell module (RSAT)
  - Administrator privileges and AD permissions to create groups

  Configuration:
  - Embedded defaults (section 4.0), optionally overridden by "easyADGroups.ini"
    in the script directory (see "easyADGroups.ini.example").

  NOTE: This file is not digitally signed. Re-sign it (Set-AuthenticodeSignature)
        if your execution policy requires signed scripts.
  ####################################################################################################
#>

#Requires -Version 5.1
#Requires -Modules ActiveDirectory
#Requires -RunAsAdministrator

# [1.0 | SCRIPT PATH DETECTION]
#region Script Path Detection
if ($MyInvocation.MyCommand.Definition -match '\.exe$') {
    $scriptDir = [System.IO.Path]::GetDirectoryName([System.Reflection.Assembly]::GetEntryAssembly().Location)
} elseif ($PSScriptRoot) {
    $scriptDir = $PSScriptRoot
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
#endregion

# [2.0 | DEPENDENCY VERIFICATION]
#region Dependency Verification
# [2.1 | WPF REQUIRES STA]
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    Write-Error "Die WPF-Oberfläche benötigt den STA-Modus. Bitte mit 'powershell.exe -STA -File <Script>' starten."
    exit 1
}

# [2.2 | ACTIVE DIRECTORY MODULE]
# Version, admin rights and module availability are enforced by the #Requires statements above.
if (-not (Get-Module -Name ActiveDirectory)) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Host "ActiveDirectory-Modul erfolgreich importiert" -ForegroundColor Green
    }
    catch {
        Write-Error "Fehler beim Importieren des ActiveDirectory-Moduls: $($_.Exception.Message)"
        exit 1
    }
}
#endregion

# [3.0 | TYPE IMPORTS AND ASSEMBLIES]
#region Type Imports
# WPF-spezifische Assemblies laden
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic
#endregion

# [3.1 | GLOBAL VARIABLES INITIALIZATION]
$script:createdGroups = New-Object System.Collections.ArrayList
$script:selectedUsers = @()
$script:allUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
$script:filteredUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
$script:templates = @{}
$script:searchTimer = $null

# [4.0 | EMBEDDED CONFIGURATION]
#region Embedded Configuration

# [4.1 | CONFIGURATION DEFINITION]
# [ENGLISH - Embedded defaults. Values can be overridden by easyADGroups.ini (same section/key names)]
# [GERMAN - Eingebettete Standardwerte. Können über easyADGroups.ini überschrieben werden (gleiche Abschnitte/Schlüssel)]
$generalConfig = @{
    ScriptVersion = "0.3.2"
    LastUpdate = "14.10.2026"
    Author = "Andreas Hepp"
    WebsiteURL = "https://phinit.de/easyit-tools"
    WebsiteURLText = "www.phinit.de"
    Debug = "0"
}

$loggingConfig = @{
    LogFileName = "easyADGroups.log"
    LogActive = "1"
    LogLevel = "INFO"
}

$guiConfig = @{
    HeaderBackColor = "#0078D4"
    FooterBackColor = "#F8F8F8"
    FooterFontColor = "#605E5C"
    AppName = "easyADgroup"
    AppNameFontSize = "20"
    AppNameFontColor = "White"
    AppFont = "Segoe UI"
    AppInfoText = "ScriptVersion | LastUpdate | Author | WebsiteURLText"
}

$adConfig = @{
    # Leer = Domain Controller automatisch ermitteln
    ADServer = ""
    MaxUsersToLoad = "500"
    # Fallback-OU für CSV-Zeilen ohne OU (leer = aktuell ausgewählte OU)
    DefaultGroupOU = ""
}

$adgroupsConfig = @{
    GroupDescription = "Created with easyADgroup"
    AdditionalSuffixes = "RW,R,ADM"
    GroupMembersAddActive = "0"
    GroupMembersAdd = ""
    DefaultGroupType = "Security"
    DefaultGroupScope = "Global"
    AutoNamingEnabled = "0"
    NamingTemplate = "GRP_{NAME}_{SUFFIX}"
}

$validationConfig = @{
    ValidateGroupNames = "1"
    CheckDuplicates = "1"
    # AD-Limit für den Namen (cn) einer Gruppe: 64 Zeichen
    MaxGroupNameLength = "64"
    MaxSamAccountNameLength = "20"
    # In sAMAccountName nicht erlaubte Zeichen
    InvalidCharacters = '"/\[]:;|=,+*?<>@'
    MaxGroupsPerBatch = "1000"
}

$advancedConfig = @{
    AutoCreateOUEnabled = "1"
    DefaultDryRun = "0"
    SearchDelayMs = "500"
}

$emailConfig = @{
    # Leer = Simulation (nur Log, keine E-Mail)
    SMTPServer = ""
    SMTPPort = "25"
    SMTPUseSsl = "0"
    FromEmail = ""
    EmailSubjectPrefix = "[easyADgroup]"
}

$csvConfig = @{
    CSVDelimiter = ","
    MaxCSVFileSizeMB = "10"
}

# [4.2 | OPTIONAL INI OVERRIDES]
# [ENGLISH - Load optional easyADGroups.ini from the script directory and override embedded defaults]
# [GERMAN - Lädt optionale easyADGroups.ini aus dem Skriptverzeichnis und überschreibt die Standardwerte]
$iniPath = Join-Path $scriptDir "easyADGroups.ini"
$script:iniMessages = New-Object System.Collections.Generic.List[string]

function Import-IniConfiguration {
    param(
        [string]$Path
    )

    $sectionMap = @{
        'GENERAL'    = $generalConfig
        'LOGGING'    = $loggingConfig
        'GUI'        = $guiConfig
        'AD'         = $adConfig
        'ADGROUPS'   = $adgroupsConfig
        'VALIDATION' = $validationConfig
        'ADVANCED'   = $advancedConfig
        'EMAIL'      = $emailConfig
        'CSV'        = $csvConfig
    }
    # Script-Metadaten dürfen nicht über die INI überschrieben werden
    $protectedKeys = @('ScriptVersion', 'LastUpdate')

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $script:iniMessages.Add("Keine INI-Datei gefunden ($Path) - eingebettete Standardwerte werden verwendet")
        return
    }

    $currentSection = $null
    foreach ($rawLine in (Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop)) {
        $line = $rawLine.Trim()
        if ($line -eq '' -or $line.StartsWith(';') -or $line.StartsWith('#')) { continue }

        if ($line -match '^\[(.+)\]$') {
            $currentSection = $Matches[1].Trim().ToUpperInvariant()
            continue
        }

        $separatorIndex = $line.IndexOf('=')
        if ($separatorIndex -lt 1 -or -not $currentSection -or -not $sectionMap.ContainsKey($currentSection)) { continue }

        $key = $line.Substring(0, $separatorIndex).Trim()
        $value = $line.Substring($separatorIndex + 1).Trim()
        $target = $sectionMap[$currentSection]

        if ($key -in $protectedKeys) { continue }
        if ($target.ContainsKey($key)) {
            $target[$key] = $value
        } else {
            $script:iniMessages.Add("Unbekannter INI-Schlüssel ignoriert: [$currentSection] $key")
        }
    }
    $script:iniMessages.Add("INI-Datei geladen: $Path")
}

try {
    Import-IniConfiguration -Path $iniPath
}
catch {
    Write-Host "WARNING: INI-Datei konnte nicht gelesen werden: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Configuration loaded successfully" -ForegroundColor Green
#endregion

# [4.5 | DEBUG MODE CHECK]
# [ENGLISH - Output debug mode status]
# [GERMAN - Debug-Modus Status ausgeben]
if ($generalConfig.Debug -eq "1") {
    Write-Host "DEBUG-MODUS AKTIVIERT" -ForegroundColor Cyan
}

# [4.6 | PLACEHOLDER REPLACEMENT]
# [ENGLISH - Function to replace placeholders in text]
# [GERMAN - Funktion zum Ersetzen von Platzhaltern in Texten]
function Format-InfoText {
    param(
        [string]$Text
    )

    # Literale Ersetzung (keine Regex), damit Sonderzeichen in Werten nicht interpretiert werden
    $placeholders = [ordered]@{
        'WebsiteURLText' = $generalConfig.WebsiteURLText
        'ScriptVersion'  = $generalConfig.ScriptVersion
        'LastUpdate'     = $generalConfig.LastUpdate
        'Author'         = $generalConfig.Author
    }

    $parts = foreach ($part in ($Text -split '\|')) {
        $token = $part.Trim()
        if ($placeholders.Contains($token)) { $placeholders[$token] } else { $token }
    }

    return (($parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' | ')
}

# [4.7 | LOG DIRECTORY SETUP]
# [ENGLISH - Setup log directory in a subfolder of the script directory]
# [GERMAN - Richtet das Log-Verzeichnis in einem Unterordner des Skriptverzeichnisses ein]
$script:config = @{
    LogPath = $null
}

if ($loggingConfig.LogActive -eq "1") {
    try {
        $logDir = Join-Path $scriptDir "logs"
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -Path $logDir -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Log directory created: $logDir" -ForegroundColor Yellow
        }

        # Eindeutiger Log-Dateiname mit Zeitstempel; ungültige Dateinamenzeichen aus der INI entfernen
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $safeLogName = $loggingConfig.LogFileName -replace '[\\/:*?"<>|]', '_'
        $script:config.LogPath = Join-Path $logDir "LOG_easyADGroups-$timestamp-$safeLogName"

        "Log file initialized at $(Get-Date)" | Out-File -FilePath $script:config.LogPath -Encoding UTF8 -ErrorAction Stop
        Write-Host "Log file created: $($script:config.LogPath)" -ForegroundColor Gray
    }
    catch {
        Write-Host "WARNING: Cannot create log file: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Logging will be done to console only." -ForegroundColor Yellow
        $script:config.LogPath = $null
    }
}

# [4.8 | TEMPLATES DIRECTORY SETUP]
# [ENGLISH - Setup templates directory for saving/loading configurations]
# [GERMAN - Richtet das Vorlagen-Verzeichnis zum Speichern/Laden von Konfigurationen ein]
$templatesDir = Join-Path $scriptDir "templates"
if (-not (Test-Path -LiteralPath $templatesDir)) {
    try {
        New-Item -Path $templatesDir -ItemType Directory -ErrorAction Stop | Out-Null
        Write-Host "Vorlagen-Verzeichnis erstellt: $templatesDir" -ForegroundColor Yellow
    }
    catch {
        Write-Host "WARNING: Vorlagen-Verzeichnis konnte nicht erstellt werden: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# [5.0 | LOGGING FUNCTIONS]
# [ENGLISH - Defines logging capabilities for different message levels]
# [GERMAN - Definiert Protokollierungsfunktionen für verschiedene Nachrichtenebenen]
#region Logging Message Functions
$script:logLevelOrder = @{ 'DEBUG' = 0; 'INFO' = 1; 'WARNING' = 2; 'ERROR' = 3 }

function Write-LogMessage {
    # [5.1 | PRIMARY LOGGING WRAPPER]
    param(
        [string]$message,
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$logLevel = "INFO"
    )
    Write-LogEntry -Message $message -Level $logLevel

    # [5.1.1 | CONSOLE OUTPUT]
    if ($logLevel -eq "DEBUG" -and $generalConfig.Debug -eq "1") {
        Write-Host "[DEBUG] $message" -ForegroundColor Cyan
    }
    # [5.1.2 | ERROR DISPLAY]
    elseif ($logLevel -eq "ERROR") {
        Write-Host "[ERROR] $message" -ForegroundColor Red
    }
    # [5.1.3 | WARNING DISPLAY]
    elseif ($logLevel -eq "WARNING") {
        Write-Host "[WARN] $message" -ForegroundColor Yellow
    }
}

function Write-DebugMessage {
    # [5.2 | DEBUG LOGGING]
    param(
        [string]$Message
    )
    if ($generalConfig.Debug -eq "1") {
        Write-LogMessage -message $Message -logLevel "DEBUG"
    }
}

function Update-UI {
    # [5.3 | UI REFRESH]
    # [ENGLISH - Processes pending dispatcher work so that status/progress changes are rendered during long operations]
    # [GERMAN - Verarbeitet ausstehende Dispatcher-Aufgaben, damit Status/Fortschritt während langer Vorgänge sichtbar wird]
    if ($script:window -and $script:window.IsLoaded) {
        $script:window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    }
}

function Update-StatusLabel {
    # [5.4 | STATUS UPDATE]
    param(
        [string]$Status
    )
    if ($script:statusLabel) {
        $script:statusLabel.Text = $Status
        Update-UI
    }
}
#endregion

# [6.0 | LOGGING FUNCTIONALITY]
#region Logging Implementation
function Write-LogEntry {
    # [6.1 | LOG ENTRY CREATION]
    # [ENGLISH - Available log levels: "DEBUG", "INFO" (default), "WARNING", "ERROR"; LogLevel in config is the minimum level]
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )

    # Mindest-Log-Level aus der Konfiguration (Debug-Modus schreibt immer DEBUG-Einträge)
    $minLevel = if ($generalConfig.Debug -eq "1") { 'DEBUG' } else { "$($loggingConfig.LogLevel)".ToUpperInvariant() }
    if (-not $script:logLevelOrder.ContainsKey($minLevel)) { $minLevel = 'INFO' }
    if ($script:logLevelOrder[$Level] -lt $script:logLevelOrder[$minLevel]) { return }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry  = "$timestamp [$Level] - $Message"

    $success = $false
    if ($script:config.LogPath) {
        for ($attempt = 1; $attempt -le 3 -and -not $success; $attempt++) {
            try {
                [System.IO.File]::AppendAllText($script:config.LogPath, $logEntry + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
                $success = $true
            }
            catch {
                # Datei evtl. kurzzeitig gesperrt - kurz warten und erneut versuchen
                Start-Sleep -Milliseconds 100
            }
        }
    }

    # Falls kein Log-Pfad verfügbar ist oder alle Versuche fehlschlagen: Konsolen-Output
    if (-not $success -and $Level -eq 'INFO') {
        Write-Host "[$Level] $Message"
    }
}

# [6.2 | INITIAL LOG ENTRIES]
Write-LogMessage "Script gestartet - Version $($generalConfig.ScriptVersion)" -logLevel "INFO"
Write-DebugMessage "Debug-Modus aktiv - Detaillierte Ausgaben werden angezeigt"
Write-DebugMessage "Script-Verzeichnis: $scriptDir"
Write-DebugMessage "INI-Datei: $iniPath"
foreach ($iniMessage in $script:iniMessages) {
    Write-LogMessage $iniMessage -logLevel "INFO"
}
Write-DebugMessage "Log-Datei: $($script:config.LogPath)"
Write-DebugMessage "Vorlagen-Verzeichnis: $templatesDir"
#endregion

# [7.0 | TEMPLATE MANAGEMENT]
#region Template Management
function Get-SelectedGroupType {
    if ($radioSecurity.IsChecked) { "Security" } else { "Distribution" }
}

function Get-SelectedGroupScope {
    if ($radioGlobal.IsChecked) { "Global" } elseif ($radioUniversal.IsChecked) { "Universal" } else { "DomainLocal" }
}

function Set-GroupTypeAndScope {
    param(
        [string]$GroupType,
        [string]$GroupScope
    )
    if ($GroupType -eq "Distribution") { $radioDistribution.IsChecked = $true } else { $radioSecurity.IsChecked = $true }
    switch ($GroupScope) {
        "Universal"   { $radioUniversal.IsChecked = $true }
        "DomainLocal" { $radioDomainLocal.IsChecked = $true }
        default       { $radioGlobal.IsChecked = $true }
    }
}

function Show-SelectionDialog {
    # [7.0.1 | LIST SELECTION DIALOG]
    # [ENGLISH - Small modal WPF dialog to pick one entry from a list]
    # [GERMAN - Kleiner modaler WPF-Dialog zur Auswahl eines Eintrags aus einer Liste]
    param(
        [string]$Title,
        [string]$Prompt,
        [string[]]$Items
    )

    $dialog = New-Object System.Windows.Window
    $dialog.Title = $Title
    $dialog.Width = 360
    $dialog.Height = 360
    $dialog.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $dialog.ResizeMode = [System.Windows.ResizeMode]::NoResize
    if ($script:window) { $dialog.Owner = $script:window }

    $panel = New-Object System.Windows.Controls.DockPanel
    $panel.Margin = [System.Windows.Thickness]::new(12)

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Prompt
    $label.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    [System.Windows.Controls.DockPanel]::SetDock($label, [System.Windows.Controls.Dock]::Top)
    [void]$panel.Children.Add($label)

    $buttons = New-Object System.Windows.Controls.StackPanel
    $buttons.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $buttons.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $buttons.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
    [System.Windows.Controls.DockPanel]::SetDock($buttons, [System.Windows.Controls.Dock]::Bottom)

    $okButton = New-Object System.Windows.Controls.Button
    $okButton.Content = "OK"
    $okButton.Width = 80
    $okButton.IsDefault = $true
    $okButton.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $cancelButton = New-Object System.Windows.Controls.Button
    $cancelButton.Content = "Abbrechen"
    $cancelButton.Width = 80
    $cancelButton.IsCancel = $true
    [void]$buttons.Children.Add($okButton)
    [void]$buttons.Children.Add($cancelButton)
    [void]$panel.Children.Add($buttons)

    $list = New-Object System.Windows.Controls.ListBox
    foreach ($item in $Items) { [void]$list.Items.Add($item) }
    if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }
    [void]$panel.Children.Add($list)

    $okButton.Add_Click({ $dialog.DialogResult = $true })
    $list.Add_MouseDoubleClick({ if ($list.SelectedItem) { $dialog.DialogResult = $true } })

    $dialog.Content = $panel
    if ($dialog.ShowDialog() -eq $true -and $list.SelectedItem) {
        return [string]$list.SelectedItem
    }
    return $null
}

function Save-GroupTemplate {
    param(
        [string]$TemplateName
    )

    try {
        $template = [ordered]@{
            GroupName = $textBoxPrefix.Text
            Separator = $textBoxSeparator.Text
            StartNumber = $textBoxStart.Text
            EndNumber = $textBoxEnd.Text
            Description = $textBoxDescription.Text
            GroupType = Get-SelectedGroupType
            GroupScope = Get-SelectedGroupScope
            SpecialMode = [bool]$chkSpecial.IsChecked
            AutoNaming = [bool]$chkAutoNaming.IsChecked
            CreateOUIfNotExists = [bool]$chkCreateOUIfNotExists.IsChecked
            ValidateNames = [bool]$chkValidateNames.IsChecked
            CheckDuplicates = [bool]$chkCheckDuplicates.IsChecked
            EmailNotification = [bool]$chkEmailNotification.IsChecked
            NotificationEmail = $textBoxNotificationEmail.Text
            SelectedOU = $comboBoxOU.SelectedValue
        }

        $templatePath = Join-Path $templatesDir "$TemplateName.json"
        if (Test-Path -LiteralPath $templatePath) {
            $overwrite = [System.Windows.MessageBox]::Show("Die Vorlage '$TemplateName' existiert bereits. Überschreiben?", "Vorlage speichern", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
            if ($overwrite -ne [System.Windows.MessageBoxResult]::Yes) { return }
        }

        $template | ConvertTo-Json | Set-Content -LiteralPath $templatePath -Encoding UTF8 -ErrorAction Stop

        Write-LogMessage "Vorlage '$TemplateName' erfolgreich gespeichert" -logLevel "INFO"
        [System.Windows.MessageBox]::Show("Vorlage '$TemplateName' wurde erfolgreich gespeichert.", "Vorlage gespeichert") | Out-Null

        # Aktualisiere Vorlagen-Liste
        Update-TemplateList
    }
    catch {
        Write-LogMessage "Fehler beim Speichern der Vorlage '$TemplateName': $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Speichern der Vorlage: $($_.Exception.Message)", "Fehler") | Out-Null
    }
}

function Import-GroupTemplate {
    param(
        [string]$TemplateName
    )

    try {
        if (-not $script:templates.ContainsKey($TemplateName)) {
            [System.Windows.MessageBox]::Show("Vorlage '$TemplateName' nicht gefunden.", "Fehler") | Out-Null
            return
        }

        $template = Get-Content -LiteralPath $script:templates[$TemplateName] -Raw -Encoding UTF8 | ConvertFrom-Json

        # Lade Werte in die GUI
        $textBoxPrefix.Text = [string]$template.GroupName
        $textBoxSeparator.Text = [string]$template.Separator
        $textBoxStart.Text = [string]$template.StartNumber
        $textBoxEnd.Text = [string]$template.EndNumber
        $textBoxDescription.Text = [string]$template.Description
        $textBoxNotificationEmail.Text = [string]$template.NotificationEmail

        Set-GroupTypeAndScope -GroupType $template.GroupType -GroupScope $template.GroupScope

        # Setze CheckBoxes
        $chkSpecial.IsChecked = [bool]$template.SpecialMode
        $chkAutoNaming.IsChecked = [bool]$template.AutoNaming
        $chkCreateOUIfNotExists.IsChecked = [bool]$template.CreateOUIfNotExists -and $chkCreateOUIfNotExists.IsEnabled
        $chkValidateNames.IsChecked = [bool]$template.ValidateNames
        $chkCheckDuplicates.IsChecked = [bool]$template.CheckDuplicates
        $chkEmailNotification.IsChecked = [bool]$template.EmailNotification

        # Setze OU-Auswahl
        if ($template.SelectedOU) {
            $comboBoxOU.SelectedValue = [string]$template.SelectedOU
        }

        Write-LogMessage "Vorlage '$TemplateName' erfolgreich geladen" -logLevel "INFO"
        Update-StatusLabel "Vorlage '$TemplateName' geladen"
    }
    catch {
        Write-LogMessage "Fehler beim Laden der Vorlage '$TemplateName': $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Laden der Vorlage: $($_.Exception.Message)", "Fehler") | Out-Null
    }
}

function Update-TemplateList {
    $script:templates = @{}
    $templateFiles = Get-ChildItem -LiteralPath $templatesDir -Filter "*.json" -File -ErrorAction SilentlyContinue

    foreach ($file in $templateFiles) {
        $templateName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $script:templates[$templateName] = $file.FullName
    }

    Write-DebugMessage "Available templates loaded: $($script:templates.Keys -join ', ')"
}

function Set-FormDefault {
    # [7.1 | FORM DEFAULTS]
    # [ENGLISH - Sets all form fields to the configured default values]
    # [GERMAN - Setzt alle Formularfelder auf die konfigurierten Standardwerte]
    $textBoxPrefix.Text = ""
    $textBoxSeparator.Text = "-"
    $textBoxStart.Text = ""
    $textBoxEnd.Text = ""
    $textBoxDescription.Text = $adgroupsConfig.GroupDescription
    $textBoxNotificationEmail.Text = ""
    $textBoxUserSearch.Text = ""

    Set-GroupTypeAndScope -GroupType $adgroupsConfig.DefaultGroupType -GroupScope $adgroupsConfig.DefaultGroupScope

    $chkSpecial.IsChecked = $false
    $chkAutoNaming.IsChecked = ($adgroupsConfig.AutoNamingEnabled -eq "1")
    $chkCreateOUIfNotExists.IsChecked = $false
    $chkCreateOUIfNotExists.IsEnabled = ($advancedConfig.AutoCreateOUEnabled -eq "1")
    $chkValidateNames.IsChecked = ($validationConfig.ValidateGroupNames -ne "0")
    $chkCheckDuplicates.IsChecked = ($validationConfig.CheckDuplicates -ne "0")
    $chkDryRun.IsChecked = ($advancedConfig.DefaultDryRun -eq "1")
    $chkEmailNotification.IsChecked = $false

    $comboBoxOU.SelectedIndex = -1
    $listBoxUsers.SelectedItems.Clear()
    $script:selectedUserSet.Clear()
}

function Reset-Form {
    Set-FormDefault
    Update-StatusLabel "Felder zurückgesetzt"
    Write-LogMessage "Formularfelder wurden zurückgesetzt" -logLevel "INFO"
}
#endregion

# [8.0 | CSV IMPORT/EXPORT FUNCTIONS]
#region CSV Functions
function Export-CSVTemplate {
    # [8.1 | CSV TEMPLATE EXPORT]
    # [ENGLISH - Exports a CSV template for bulk group creation]
    # [GERMAN - Exportiert eine CSV-Vorlage für die Massen-Gruppenerstellung]
    try {
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
        $saveDialog.Title = "CSV-Vorlage speichern"
        $saveDialog.FileName = "ADGroups_Template.csv"

        if ($saveDialog.ShowDialog() -eq $true) {
            $exampleOU = if ($comboBoxOU.SelectedValue) { [string]$comboBoxOU.SelectedValue } else { "OU=Groups,DC=domain,DC=com" }
            $rows = @(
                [PSCustomObject]@{ GroupName = "Beispiel-Gruppe-1"; Description = "Beispiel Beschreibung"; GroupType = "Security"; GroupScope = "Global"; OU = $exampleOU; Members = "user1;user2" }
                [PSCustomObject]@{ GroupName = "Beispiel-Gruppe-2"; Description = "Weitere Beschreibung"; GroupType = "Distribution"; GroupScope = "Universal"; OU = $exampleOU; Members = "user3;user4" }
            )
            $rows | Export-Csv -LiteralPath $saveDialog.FileName -Delimiter $csvConfig.CSVDelimiter -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
            Write-LogMessage "CSV-Vorlage exportiert nach: $($saveDialog.FileName)" -logLevel "INFO"
            [System.Windows.MessageBox]::Show("CSV-Vorlage wurde erfolgreich exportiert.", "Export erfolgreich") | Out-Null
        }
    }
    catch {
        Write-LogMessage "Fehler beim Exportieren der CSV-Vorlage: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Exportieren der CSV-Vorlage: $($_.Exception.Message)", "Fehler") | Out-Null
    }
}

function Import-CSVGroup {
    # [8.2 | CSV IMPORT]
    # [ENGLISH - Imports and validates group configurations from CSV file]
    # [GERMAN - Importiert und validiert Gruppenkonfigurationen aus CSV-Datei]
    try {
        $openDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
        $openDialog.Title = "CSV-Datei für Import auswählen"

        if ($openDialog.ShowDialog() -ne $true) { return }

        # Dateigröße prüfen
        $maxBytes = [int]$csvConfig.MaxCSVFileSizeMB * 1MB
        $fileInfo = Get-Item -LiteralPath $openDialog.FileName -ErrorAction Stop
        if ($fileInfo.Length -gt $maxBytes) {
            [System.Windows.MessageBox]::Show("Die CSV-Datei ist größer als $($csvConfig.MaxCSVFileSizeMB) MB.", "CSV-Import") | Out-Null
            return
        }

        $csvData = @(Import-Csv -LiteralPath $openDialog.FileName -Delimiter $csvConfig.CSVDelimiter -Encoding UTF8 -ErrorAction Stop)
        if ($csvData.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Die CSV-Datei enthält keine Datenzeilen.", "CSV-Import") | Out-Null
            return
        }
        if ($csvData.Count -gt [int]$validationConfig.MaxGroupsPerBatch) {
            [System.Windows.MessageBox]::Show("Die CSV-Datei enthält $($csvData.Count) Zeilen (max. $($validationConfig.MaxGroupsPerBatch) pro Vorgang).", "CSV-Import") | Out-Null
            return
        }
        if (-not ($csvData[0].PSObject.Properties.Name -contains 'GroupName')) {
            [System.Windows.MessageBox]::Show("Die Spalte 'GroupName' fehlt. Bitte die CSV-Vorlage verwenden.", "CSV-Import") | Out-Null
            return
        }

        $fallbackOU = if ($adConfig.DefaultGroupOU) { $adConfig.DefaultGroupOU } else { [string]$comboBoxOU.SelectedValue }

        $groupsToCreate = New-Object System.Collections.Generic.List[object]
        $validationErrors = New-Object System.Collections.Generic.List[string]
        $rowNumber = 1
        foreach ($row in $csvData) {
            $rowNumber++
            $name = "$($row.GroupName)".Trim()
            $groupType = if ([string]::IsNullOrWhiteSpace($row.GroupType)) { $adgroupsConfig.DefaultGroupType } else { "$($row.GroupType)".Trim() }
            $groupScope = if ([string]::IsNullOrWhiteSpace($row.GroupScope)) { $adgroupsConfig.DefaultGroupScope } else { "$($row.GroupScope)".Trim() }
            $ou = if ([string]::IsNullOrWhiteSpace($row.OU)) { $fallbackOU } else { "$($row.OU)".Trim() }

            $rowErrors = @(Test-GroupName -Name $name)
            if ($groupType -notin @('Security', 'Distribution')) { $rowErrors += "Ungültiger GroupType '$groupType' (Security/Distribution)" }
            if ($groupScope -notin @('Global', 'Universal', 'DomainLocal')) { $rowErrors += "Ungültiger GroupScope '$groupScope' (Global/Universal/DomainLocal)" }
            if ([string]::IsNullOrWhiteSpace($ou)) { $rowErrors += "Keine OU angegeben und keine OU ausgewählt" }

            if ($rowErrors.Count -gt 0) {
                $validationErrors.Add("Zeile ${rowNumber}: " + ($rowErrors -join '; '))
                continue
            }

            $groupsToCreate.Add([PSCustomObject]@{
                Name = $name
                SamAccountName = Get-GroupSamAccountName -GroupName $name
                Description = if ([string]::IsNullOrWhiteSpace($row.Description)) { $adgroupsConfig.GroupDescription } else { "$($row.Description)".Trim() }
                GroupType = $groupType
                GroupScope = $groupScope
                OU = $ou
                Members = @("$($row.Members)".Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            })
        }

        # SAM-Kollisionen innerhalb der Datei erkennen
        $duplicateSams = $groupsToCreate | Group-Object -Property SamAccountName | Where-Object { $_.Count -gt 1 }
        foreach ($dup in $duplicateSams) {
            $validationErrors.Add("Mehrfacher sAMAccountName '$($dup.Name)': $(($dup.Group.Name) -join ', ')")
        }

        if ($validationErrors.Count -gt 0) {
            Write-LogMessage "CSV-Validierung fehlgeschlagen: $($validationErrors -join ' | ')" -logLevel "WARNING"
            [System.Windows.MessageBox]::Show("Die CSV-Datei enthält Fehler:`n`n" + (($validationErrors | Select-Object -First 20) -join "`n"), "CSV-Validierung") | Out-Null
            return
        }

        # Zeige Vorschau (begrenzt, damit die MessageBox bedienbar bleibt)
        $previewText = "Folgende $($groupsToCreate.Count) Gruppen werden aus der CSV-Datei erstellt:`n`n"
        foreach ($group in ($groupsToCreate | Select-Object -First 30)) {
            $previewText += "• $($group.Name) ($($group.GroupType), $($group.GroupScope))`n"
        }
        if ($groupsToCreate.Count -gt 30) { $previewText += "… und $($groupsToCreate.Count - 30) weitere`n" }
        if ($chkDryRun.IsChecked) { $previewText += "`nTESTLAUF AKTIVIERT - Es werden keine Änderungen vorgenommen`n" }

        $result = [System.Windows.MessageBox]::Show($previewText + "`nMöchten Sie fortfahren?", "CSV-Import Vorschau", [System.Windows.MessageBoxButton]::YesNo)

        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            New-GroupFromCSV -Groups $groupsToCreate.ToArray()
        }
    }
    catch {
        Write-LogMessage "Fehler beim CSV-Import: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim CSV-Import: $($_.Exception.Message)", "Fehler") | Out-Null
    }
}

function New-GroupFromCSV {
    param(
        [object[]]$Groups
    )

    $total = $Groups.Count
    $processed = 0
    $created = 0
    $skipped = 0
    $errors = New-Object System.Collections.Generic.List[string]
    $dryRun = [bool]$chkDryRun.IsChecked

    Set-BusyState -Busy $true
    try {
        $existing = if ($chkCheckDuplicates.IsChecked) { Get-ExistingGroupSam -SamAccountNames ($Groups | ForEach-Object { $_.SamAccountName }) } else { @() }

        foreach ($group in $Groups) {
            try {
                if ($existing -contains $group.SamAccountName) {
                    $skipped++
                    Write-LogMessage "CSV-Gruppe '$($group.Name)' existiert bereits - wird übersprungen" -logLevel "WARNING"
                }
                elseif ($dryRun) {
                    Write-LogMessage "TESTLAUF: CSV-Gruppe $($group.Name) würde in '$($group.OU)' erstellt werden" -logLevel "INFO"
                    [void]$script:createdGroups.Add("[TESTLAUF] $($group.Name)")
                }
                else {
                    if ($chkCreateOUIfNotExists.IsChecked -eq $true -and -not (Initialize-OrganizationalUnit -OUPath $group.OU)) {
                        throw "OU '$($group.OU)' konnte nicht erstellt werden"
                    }

                    $params = @{
                        Name = $group.Name
                        SamAccountName = $group.SamAccountName
                        DisplayName = $group.Name
                        Description = $group.Description
                        GroupCategory = $group.GroupType
                        GroupScope = $group.GroupScope
                        Path = $group.OU
                    }
                    $newGroup = New-ADGroup @params -PassThru -ErrorAction Stop
                    [void]$script:createdGroups.Add($group.Name)
                    $created++
                    Write-LogMessage "CSV-Gruppe erstellt: $($group.Name)" -logLevel "INFO"

                    if ($group.Members.Count -gt 0) {
                        try {
                            Add-ADGroupMember -Identity $newGroup -Members $group.Members -ErrorAction Stop
                            Write-LogMessage "Mitglieder zu $($group.Name) hinzugefügt: $($group.Members -join ', ')" -logLevel "INFO"
                        }
                        catch {
                            $errors.Add("Mitglieder für '$($group.Name)' konnten nicht hinzugefügt werden: $($_.Exception.Message)")
                            Write-LogMessage "Fehler beim Hinzufügen von Mitgliedern zu $($group.Name): $($_.Exception.Message)" -logLevel "WARNING"
                        }
                    }
                }
            }
            catch {
                $errorMsg = "Fehler bei Gruppe '$($group.Name)': $($_.Exception.Message)"
                $errors.Add($errorMsg)
                Write-LogMessage $errorMsg -logLevel "ERROR"
            }

            $processed++
            $progressBarMain.Value = ($processed / $total) * 100
            Update-StatusLabel "CSV-Import: $processed/$total"
        }
    }
    finally {
        Set-BusyState -Busy $false
    }

    $resultMsg = if ($dryRun) { "CSV-TESTLAUF abgeschlossen." } else { "CSV-Import abgeschlossen." }
    $resultMsg += "`n$processed von $total Zeilen verarbeitet, $created erstellt, $skipped übersprungen."
    if ($errors.Count -gt 0) {
        $resultMsg += "`n`nFehler ($($errors.Count)):`n" + (($errors | Select-Object -First 20) -join "`n")
    }

    [System.Windows.MessageBox]::Show($resultMsg, "CSV-Import Ergebnis") | Out-Null
    Update-StatusLabel "CSV-Import abgeschlossen"
    Write-LogMessage "CSV-Import abgeschlossen: $created/$total Gruppen erstellt, $skipped übersprungen, $($errors.Count) Fehler (Testlauf: $dryRun)" -logLevel "INFO"
}
#endregion

# [9.0 | USER SEARCH AND MANAGEMENT]
#region User Management
$script:selectedUserSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$script:suppressSelectionSync = $false

function Sync-UserSelection {
    # [9.0.1 | SELECTION TRACKING]
    # [ENGLISH - Keeps the user selection when the list is filtered]
    # [GERMAN - Erhält die Benutzerauswahl, wenn die Liste gefiltert wird]
    param($SelectionArgs)
    if ($script:suppressSelectionSync) { return }
    foreach ($item in $SelectionArgs.RemovedItems) { if ($item.SamAccountName) { [void]$script:selectedUserSet.Remove($item.SamAccountName) } }
    foreach ($item in $SelectionArgs.AddedItems) { if ($item.SamAccountName) { [void]$script:selectedUserSet.Add($item.SamAccountName) } }
}

function Set-UserListSource {
    param(
        [System.Collections.IEnumerable]$Items
    )
    $script:suppressSelectionSync = $true
    try {
        $script:filteredUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        foreach ($item in $Items) { $script:filteredUsers.Add($item) }
        $listBoxUsers.ItemsSource = $script:filteredUsers

        # Vorherige Auswahl wiederherstellen
        foreach ($item in $script:filteredUsers) {
            if ($item.SamAccountName -and $script:selectedUserSet.Contains($item.SamAccountName)) {
                [void]$listBoxUsers.SelectedItems.Add($item)
            }
        }
    }
    finally {
        $script:suppressSelectionSync = $false
    }
}

function Search-User {
    param(
        [string]$SearchTerm
    )

    try {
        $term = "$SearchTerm".Trim()
        if ([string]::IsNullOrWhiteSpace($term)) {
            $matchingUsers = $script:allUsers
        }
        elseif ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($term)) {
            # Platzhalter (* ?) werden unterstützt
            $pattern = New-Object System.Management.Automation.WildcardPattern ("*$term*"), ([System.Management.Automation.WildcardOptions]::IgnoreCase)
            $matchingUsers = @($script:allUsers | Where-Object { $pattern.IsMatch($_.DisplayText) -or $pattern.IsMatch($_.SamAccountName) })
        }
        else {
            $matchingUsers = @($script:allUsers | Where-Object {
                $_.DisplayText.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                $_.SamAccountName.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            })
        }

        Set-UserListSource -Items $matchingUsers

        Update-StatusLabel "Suche abgeschlossen: $($script:filteredUsers.Count) Benutzer gefunden, $($script:selectedUserSet.Count) ausgewählt"
        Write-DebugMessage "User search for '$term': $($script:filteredUsers.Count) results"
    }
    catch {
        Write-LogMessage "Fehler bei Benutzersuche: $($_.Exception.Message)" -logLevel "ERROR"
        Update-StatusLabel "Fehler bei Benutzersuche"
    }
}

function Select-AllUser {
    try {
        $listBoxUsers.SelectAll()
        Update-StatusLabel "Alle angezeigten Benutzer ausgewählt ($($script:selectedUserSet.Count))"
        Write-DebugMessage "All visible users have been selected"
    }
    catch {
        Write-LogMessage "Fehler beim Auswählen aller Benutzer: $($_.Exception.Message)" -logLevel "ERROR"
    }
}

function Clear-UserSelection {
    try {
        $listBoxUsers.SelectedItems.Clear()
        $script:selectedUserSet.Clear()
        Update-StatusLabel "Benutzerauswahl aufgehoben"
        Write-DebugMessage "User selection has been cleared"
    }
    catch {
        Write-LogMessage "Fehler beim Aufheben der Benutzerauswahl: $($_.Exception.Message)" -logLevel "ERROR"
    }
}

function Get-ADUserList {
    # [9.1 | USER RETRIEVAL]
    # [ENGLISH - Loads at most MaxUsersToLoad users from AD (server-side limit) and prepares display objects]
    # [GERMAN - Lädt höchstens MaxUsersToLoad Benutzer aus AD (serverseitig begrenzt) und bereitet Anzeigeobjekte vor]
    $params = @{
        Filter = '*'
        Properties = 'DisplayName'
        ErrorAction = 'Stop'
    }
    $maxUsers = 0
    if ([int]::TryParse("$($adConfig.MaxUsersToLoad)", [ref]$maxUsers) -and $maxUsers -gt 0) {
        $params.ResultSetSize = $maxUsers
    }

    Get-ADUser @params |
        ForEach-Object {
            [PSCustomObject]@{
                DisplayText = if ([string]::IsNullOrEmpty($_.DisplayName)) { "$($_.SamAccountName)" } else { "$($_.DisplayName) ($($_.SamAccountName))" }
                SamAccountName = $_.SamAccountName
            }
        } |
        Sort-Object DisplayText
}

function Update-UserList {
    Update-StatusLabel "Aktualisiere Benutzerliste..."

    try {
        $script:allUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        foreach ($user in (Get-ADUserList)) { $script:allUsers.Add($user) }

        # Gefilterte Liste neu aufbauen (Auswahl bleibt erhalten)
        Search-User -SearchTerm $textBoxUserSearch.Text

        Update-StatusLabel "Benutzerliste aktualisiert: $($script:allUsers.Count) Benutzer geladen"
        Write-LogMessage "Benutzerliste aktualisiert: $($script:allUsers.Count) Benutzer geladen" -logLevel "INFO"
    }
    catch {
        Write-LogMessage "Fehler beim Aktualisieren der Benutzerliste: $($_.Exception.Message)" -logLevel "ERROR"
        Update-StatusLabel "Fehler beim Aktualisieren der Benutzerliste"
    }
}
#endregion

# [10.0 | ACTIVE DIRECTORY OPERATIONS]
#region AD Operations
function Initialize-ADConnection {
    # [10.0.1 | DOMAIN CONTROLLER SELECTION]
    # [ENGLISH - Pins all AD cmdlets to one domain controller (configured or discovered) to avoid replication delays]
    # [GERMAN - Bindet alle AD-Cmdlets an einen Domain Controller (konfiguriert oder ermittelt), um Replikationsverzögerungen zu vermeiden]
    $server = "$($adConfig.ADServer)".Trim()
    if ([string]::IsNullOrWhiteSpace($server) -or $server -eq 'localhost') {
        try {
            $server = [string](@((Get-ADDomainController -Discover -ErrorAction Stop).HostName)[0])
        }
        catch {
            Write-LogMessage "Domain Controller konnte nicht ermittelt werden: $($_.Exception.Message)" -logLevel "WARNING"
            $server = $null
        }
    }

    if ($server) {
        # Script-Scope: wirkt nur innerhalb dieses Scripts, nicht in der aufrufenden Sitzung
        $script:PSDefaultParameterValues = @{ '*-AD*:Server' = $server }
        $script:adServer = $server
        Write-LogMessage "AD-Server: $server" -logLevel "INFO"
    }
}

function Get-ADData {
    # [10.1 | AD DATA RETRIEVAL]
    # [ENGLISH - Retrieve and process Active Directory data]
    # [GERMAN - Active Directory-Daten abrufen und verarbeiten]
    Write-LogMessage "AD-Daten werden abgerufen..." -logLevel "INFO"
    Update-StatusLabel "Lade AD-Daten..."

    try {
        # [10.1.1 | OU RETRIEVAL]
        # [ENGLISH - Retrieve all organizational units (except Domain Controllers) with their path]
        # [GERMAN - Ruft alle OUs (außer Domain Controllers) inkl. Pfad ab]
        Write-DebugMessage "Rufe alle OUs aus AD ab..."
        $script:allOUs = @(Get-ADOrganizationalUnit -Filter * -Properties CanonicalName -ErrorAction Stop |
            Where-Object { $_.DistinguishedName -notmatch '^OU=Domain Controllers,DC=' } |
            ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    # Pfad-Anzeige, damit gleichnamige OUs unterscheidbar sind
                    Path = if ($_.CanonicalName) { $_.CanonicalName } else { $_.DistinguishedName }
                    DN   = $_.DistinguishedName
                }
            } | Sort-Object Path)
        Write-DebugMessage "Anzahl gefundener OUs nach Filterung: $($script:allOUs.Count)"

        # [10.1.2 | USER RETRIEVAL]
        Write-DebugMessage "Rufe Benutzer aus AD ab..."
        $script:allUsers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        try {
            foreach ($user in (Get-ADUserList)) { $script:allUsers.Add($user) }
            Write-DebugMessage "Benutzerabfrage erfolgreich: $($script:allUsers.Count) Benutzer geladen"
        }
        catch {
            Write-LogMessage "Warnung bei Benutzerabfrage: $($_.Exception.Message)" -logLevel "WARNING"
        }

        # [10.1.3 | UI UPDATES]
        $comboBoxOU.ItemsSource = $script:allOUs
        $listBoxUsers.DisplayMemberPath = "DisplayText"
        $listBoxUsers.SelectedValuePath = "SamAccountName"
        Set-UserListSource -Items $script:allUsers

        Update-StatusLabel "AD-Daten geladen: $($script:allOUs.Count) OUs, $($script:allUsers.Count) Benutzer"
        Write-LogMessage "AD-Daten erfolgreich geladen" -logLevel "INFO"
    }
    catch {
        # [10.1.4 | ERROR HANDLING]
        Write-LogMessage "Fehler beim Abrufen von AD-Daten: $($_.Exception.Message)" -logLevel "ERROR"
        Update-StatusLabel "Fehler beim Laden der AD-Daten"
        [System.Windows.MessageBox]::Show("AD-Verbindungsfehler: $($_.Exception.Message)", "Fehler") | Out-Null
        exit 1
    }
}

function Initialize-OrganizationalUnit {
    # [10.2 | OU AUTO-CREATION]
    # [ENGLISH - Ensures that an OU (and missing parent OUs) exists]
    # [GERMAN - Stellt sicher, dass eine OU (inkl. fehlender übergeordneter OUs) existiert]
    param(
        [string]$OUPath
    )

    try {
        Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        if ($_.Exception.GetType().Name -ne 'ADIdentityNotFoundException') {
            Write-LogMessage "Fehler beim Prüfen der OU '$OUPath': $($_.Exception.Message)" -logLevel "ERROR"
            return $false
        }
    }

    try {
        # DN an der ersten nicht maskierten Komma-Stelle trennen
        $parts = $OUPath -split '(?<!\\),', 2
        if ($parts.Count -lt 2 -or $parts[0] -notmatch '^\s*OU=(.+)$') {
            Write-LogMessage "Ungültiger OU-Pfad: '$OUPath'" -logLevel "ERROR"
            return $false
        }
        $ouName = $Matches[1] -replace '\\(.)', '$1'
        $parentPath = $parts[1].Trim()

        if ($parentPath -match '^OU=' -and -not (Initialize-OrganizationalUnit -OUPath $parentPath)) {
            return $false
        }

        New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
        Write-LogMessage "OU erstellt: $OUPath" -logLevel "INFO"
        return $true
    }
    catch {
        Write-LogMessage "Fehler beim Erstellen der OU '$OUPath': $($_.Exception.Message)" -logLevel "ERROR"
        return $false
    }
}

function ConvertTo-LdapFilterValue {
    # [10.3 | LDAP ESCAPING (RFC 4515)]
    param(
        [string]$Value
    )
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Value.ToCharArray()) {
        switch ($char) {
            '\' { [void]$builder.Append('\5c') }
            '*' { [void]$builder.Append('\2a') }
            '(' { [void]$builder.Append('\28') }
            ')' { [void]$builder.Append('\29') }
            ([char]0) { [void]$builder.Append('\00') }
            default { [void]$builder.Append($char) }
        }
    }
    return $builder.ToString()
}

function Get-ExistingGroupSam {
    # [10.4 | BULK DUPLICATE CHECK]
    # [ENGLISH - Returns the sAMAccountNames that already exist in AD (batched LDAP queries instead of one query per group)]
    # [GERMAN - Gibt bereits vorhandene sAMAccountNames zurück (gebündelte LDAP-Abfragen statt einer Abfrage pro Gruppe)]
    param(
        [string[]]$SamAccountNames
    )

    $names = @($SamAccountNames | Where-Object { $_ } | Select-Object -Unique)
    $existing = New-Object System.Collections.Generic.List[string]
    $chunkSize = 50

    for ($i = 0; $i -lt $names.Count; $i += $chunkSize) {
        $chunk = $names[$i..([Math]::Min($i + $chunkSize, $names.Count) - 1)]
        $filter = '(|' + (($chunk | ForEach-Object { "(sAMAccountName=$(ConvertTo-LdapFilterValue -Value $_))" }) -join '') + ')'
        # sAMAccountName ist domänenweit eindeutig (Benutzer, Computer und Gruppen)
        Get-ADObject -LDAPFilter $filter -Properties sAMAccountName -ErrorAction Stop |
            ForEach-Object { $existing.Add([string]$_.sAMAccountName) }
    }

    return $existing.ToArray()
}

function Set-BusyState {
    # [10.5 | BUSY STATE]
    # [ENGLISH - Disables action buttons and shows the progress bar during long operations]
    # [GERMAN - Deaktiviert Aktions-Buttons und zeigt den Fortschrittsbalken während langer Vorgänge]
    param(
        [bool]$Busy
    )
    foreach ($control in @($buttonCreate, $buttonPreview, $buttonImportCSV, $buttonLoadTemplate, $buttonReset, $buttonRefreshUsers)) {
        if ($control) { $control.IsEnabled = -not $Busy }
    }
    $progressBarMain.Value = 0
    $progressBarMain.Visibility = if ($Busy) { "Visible" } else { "Collapsed" }
    $window.Cursor = if ($Busy) { [System.Windows.Input.Cursors]::Wait } else { $null }
    Update-UI
}
#endregion

# [11.0 | INPUT VALIDATION]
#region Input Validation
function Get-GroupSamAccountName {
    # [11.0.1 | SAM ACCOUNT NAME]
    param(
        [string]$GroupName
    )
    $maxSamLength = 0
    [void][int]::TryParse("$($validationConfig.MaxSamAccountNameLength)", [ref]$maxSamLength)
    if ($maxSamLength -gt 0 -and $GroupName.Length -gt $maxSamLength) {
        return $GroupName.Substring(0, $maxSamLength).TrimEnd()
    }
    return $GroupName
}

function Test-GroupName {
    # [11.0.2 | GROUP NAME VALIDATION]
    # [ENGLISH - Returns validation errors for a single group name]
    # [GERMAN - Gibt Validierungsfehler für einen einzelnen Gruppennamen zurück]
    param(
        [string]$Name
    )

    $nameErrors = @()
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return @("Gruppenname darf nicht leer sein")
    }

    if ($chkValidateNames.IsChecked -ne $false) {
        $invalidChars = @($validationConfig.InvalidCharacters.ToCharArray() | Where-Object { $Name.Contains([string]$_) } | Select-Object -Unique)
        if ($invalidChars.Count -gt 0) {
            $nameErrors += "'$Name' enthält ungültige Zeichen: $($invalidChars -join ' ')"
        }
        $maxLength = [int]$validationConfig.MaxGroupNameLength
        if ($maxLength -gt 0 -and $Name.Length -gt $maxLength) {
            $nameErrors += "'$Name' ist zu lang (max. $maxLength Zeichen)"
        }
        if ($Name -match '^[\s\.]+$' -or $Name -ne $Name.Trim()) {
            $nameErrors += "'$Name' darf nicht nur aus Punkten/Leerzeichen bestehen oder mit Leerzeichen beginnen/enden"
        }
    }
    return $nameErrors
}

function Test-Input {
    # [11.1 | USER INPUT VALIDATION]
    # [ENGLISH - Validate form inputs before processing]
    # [GERMAN - Validiert Formulareingaben vor der Verarbeitung]
    Write-DebugMessage "Validiere Benutzereingaben..."
    $errors = @()

    # [11.1.1 | STANDARD MODE VALIDATION]
    if (-not ($chkSpecial.IsChecked -eq $true)) {
        $startText = $textBoxStart.Text.Trim()
        $endText = $textBoxEnd.Text.Trim()
        if (($startText -eq "") -and ($endText -eq "")) {
            Write-DebugMessage "Start/End fields are empty - single group creation"
        }
        elseif (($startText -eq "") -or ($endText -eq "")) {
            $errors += "Bitte Start- und Endnummer ausfüllen oder beide Felder leer lassen."
        }
        else {
            # [11.1.1.2 | NUMERIC VALUES CHECK]
            $startNum = 0
            $endNum = 0
            if (-not [int]::TryParse($startText, [ref]$startNum) -or $startNum -lt 0) {
                $errors += "Ungültige Startnummer (ganze Zahl >= 0 erwartet)"
            }
            if (-not [int]::TryParse($endText, [ref]$endNum) -or $endNum -lt 0) {
                $errors += "Ungültige Endnummer (ganze Zahl >= 0 erwartet)"
            }

            # [11.1.1.3 | RANGE CHECK]
            if (($errors.Count -eq 0) -and ($startNum -gt $endNum)) {
                $errors += "Die Startnummer muss kleiner oder gleich der Endnummer sein"
            }

            # [11.1.1.4 | RANGE SIZE CHECK]
            if (($errors.Count -eq 0) -and (($endNum - $startNum + 1) -gt [int]$validationConfig.MaxGroupsPerBatch)) {
                $errors += "Nummernbereich zu groß (max. $($validationConfig.MaxGroupsPerBatch) Gruppen pro Vorgang)"
            }
        }
    } else {
        # [11.1.2 | SPECIAL MODE VALIDATION]
        Write-DebugMessage "Spezial-Modus aktiviert: Validiere für JIRA/Confluence-Gruppen"
        if (@(Get-AdditionalSuffix).Count -eq 0) {
            $errors += "Keine Suffixe konfiguriert (ADGROUPS/AdditionalSuffixes)"
        }
    }

    # [11.1.3 | OU SELECTION CHECK]
    if ($comboBoxOU.SelectedIndex -eq -1 -or -not $comboBoxOU.SelectedValue) {
        $errors += "Keine OU ausgewählt"
    }
    elseif ($chkCreateOUIfNotExists.IsChecked -ne $true) {
        try {
            Get-ADOrganizationalUnit -Identity $comboBoxOU.SelectedValue -ErrorAction Stop | Out-Null
        }
        catch {
            $errors += "Die ausgewählte OU existiert nicht oder ist nicht erreichbar. Aktivieren Sie 'Auto-create OU' oder wählen Sie eine andere OU."
        }
    }

    # [11.1.4 | GROUP NAME VALIDATION]
    if ([string]::IsNullOrWhiteSpace($textBoxPrefix.Text)) {
        $errors += "Der Gruppenname darf nicht leer sein."
    }

    # Weitere Prüfungen nur, wenn die Grunddaten gültig sind (verhindert Folgefehler)
    if ($errors.Count -eq 0) {
        $groupsToValidate = @(Get-GroupsToCreate)

        $nameErrors = @($groupsToValidate | ForEach-Object { Test-GroupName -Name $_ })
        if ($nameErrors.Count -gt 0) {
            $errors += $nameErrors | Select-Object -First 10
            if ($nameErrors.Count -gt 10) { $errors += "... und $($nameErrors.Count - 10) weitere Namensfehler" }
        }

        # [11.1.5 | SAM ACCOUNT NAME COLLISIONS]
        # Durch Kürzen auf MaxSamAccountNameLength können innerhalb eines Vorgangs gleiche Namen entstehen
        $samGroups = $groupsToValidate | Group-Object -Property { Get-GroupSamAccountName -GroupName $_ } | Where-Object { $_.Count -gt 1 }
        foreach ($samGroup in ($samGroups | Select-Object -First 5)) {
            $errors += "sAMAccountName '$($samGroup.Name)' wäre mehrfach vergeben (gekürzt auf $($validationConfig.MaxSamAccountNameLength) Zeichen): $(($samGroup.Group | Select-Object -First 3) -join ', ')"
        }

        # [11.1.6 | DUPLICATE CHECK]
        if ($chkCheckDuplicates.IsChecked -eq $true -and $nameErrors.Count -eq 0) {
            try {
                $existing = @(Get-ExistingGroupSam -SamAccountNames ($groupsToValidate | ForEach-Object { Get-GroupSamAccountName -GroupName $_ }))
                if ($existing.Count -gt 0) {
                    $errors += "Bereits vorhanden ($($existing.Count)): $(($existing | Select-Object -First 10) -join ', ')"
                }
            }
            catch {
                $errors += "Fehler bei der Duplikat-Prüfung: $($_.Exception.Message)"
            }
        }
    }

    # [11.1.7 | EMAIL VALIDATION]
    if ($chkEmailNotification.IsChecked -eq $true) {
        if (-not (Test-EmailAddress -Address $textBoxNotificationEmail.Text)) {
            $errors += "Ungültige oder fehlende E-Mail-Adresse für die Benachrichtigung"
        }
    }

    # [11.1.8 | VALIDATION RESULT]
    if ($errors.Count -gt 0) {
        Write-DebugMessage "Validierung fehlgeschlagen mit $($errors.Count) Fehlern: $($errors -join ', ')"
        Update-StatusLabel "Validierungsfehler gefunden"
    } else {
        Write-DebugMessage "Validierung erfolgreich"
        Update-StatusLabel "Validierung erfolgreich"
    }

    return ,$errors
}

function Get-AdditionalSuffix {
    @("$($adgroupsConfig.AdditionalSuffixes)".Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Format-GroupName {
    # [11.2 | GROUP NAME FORMATTING]
    # [ENGLISH - Builds the group name; applies the naming template when Auto-Naming is enabled]
    # [GERMAN - Erzeugt den Gruppennamen; wendet bei aktivem Auto-Naming das Namens-Template an]
    param(
        [string]$BaseName,
        [string]$Suffix
    )

    if ($chkAutoNaming.IsChecked -eq $true -and -not [string]::IsNullOrWhiteSpace($adgroupsConfig.NamingTemplate)) {
        $name = $adgroupsConfig.NamingTemplate.Replace('{NAME}', $BaseName)
        if ([string]::IsNullOrEmpty($Suffix)) {
            $name = $name -replace '^\{SUFFIX\}[\s_\-\.]*', '' -replace '[\s_\-\.]*\{SUFFIX\}', ''
        } else {
            $name = $name.Replace('{SUFFIX}', $Suffix)
        }
        return $name.Trim()
    }

    if ([string]::IsNullOrEmpty($Suffix)) { return $BaseName }
    return "$BaseName$($textBoxSeparator.Text.Trim())$Suffix"
}

function Get-GroupsToCreate {
    # [11.3 | GET GROUPS TO CREATE]
    # [ENGLISH - Returns list of group names that would be created]
    # [GERMAN - Gibt Liste der Gruppennamen zurück, die erstellt würden]
    $groupsToCreate = New-Object System.Collections.Generic.List[string]
    $baseName = $textBoxPrefix.Text.Trim()

    if ($chkSpecial.IsChecked -eq $true) {
        foreach ($suffix in (Get-AdditionalSuffix)) {
            $groupsToCreate.Add((Format-GroupName -BaseName $baseName -Suffix $suffix))
        }
    }
    elseif (($textBoxStart.Text.Trim() -eq "") -and ($textBoxEnd.Text.Trim() -eq "")) {
        $groupsToCreate.Add((Format-GroupName -BaseName $baseName -Suffix ""))
    }
    else {
        $start = [int]$textBoxStart.Text.Trim()
        $end = [int]$textBoxEnd.Text.Trim()
        for ($i = $start; $i -le $end; $i++) {
            $groupsToCreate.Add((Format-GroupName -BaseName $baseName -Suffix ([string]$i)))
        }
    }

    return $groupsToCreate.ToArray()
}
#endregion

# [12.0 | NOTIFICATION FUNCTIONS]
#region Notification Functions
function Test-EmailAddress {
    param(
        [string]$Address
    )
    if ([string]::IsNullOrWhiteSpace($Address)) { return $false }
    try {
        $mailAddress = New-Object System.Net.Mail.MailAddress ($Address.Trim())
        return ($mailAddress.Address -eq $Address.Trim() -and $mailAddress.Host -match '\.')
    }
    catch {
        return $false
    }
}

function Send-EmailNotification {
    # [12.1 | E-MAIL NOTIFICATION]
    # [ENGLISH - Sends via SMTP if [EMAIL] SMTPServer is configured, otherwise simulation (log only)]
    # [GERMAN - Versand per SMTP, wenn [EMAIL] SMTPServer konfiguriert ist, sonst Simulation (nur Log)]
    param(
        [string]$EmailAddress,
        [string]$Subject,
        [string]$Body
    )

    if (-not (Test-EmailAddress -Address $EmailAddress)) {
        Write-LogMessage "Ungültige E-Mail-Adresse: '$EmailAddress'" -logLevel "ERROR"
        return $false
    }

    $fullSubject = "$($emailConfig.EmailSubjectPrefix) $Subject".Trim()

    if ([string]::IsNullOrWhiteSpace($emailConfig.SMTPServer)) {
        Write-LogMessage "E-Mail-Simulation (kein SMTPServer konfiguriert) an: $EmailAddress - Betreff: $fullSubject" -logLevel "INFO"
        [System.Windows.MessageBox]::Show("Kein SMTP-Server konfiguriert - E-Mail wurde NICHT versendet (Simulation).`n`nAn: $EmailAddress`nBetreff: $fullSubject`n`n$Body", "E-Mail (Simulation)") | Out-Null
        return $true
    }

    $smtpClient = $null
    $message = $null
    try {
        if (-not (Test-EmailAddress -Address $emailConfig.FromEmail)) {
            throw "Ungültige Absenderadresse in der Konfiguration ([EMAIL] FromEmail)"
        }

        $message = New-Object System.Net.Mail.MailMessage
        $message.From = New-Object System.Net.Mail.MailAddress ($emailConfig.FromEmail)
        $message.To.Add((New-Object System.Net.Mail.MailAddress ($EmailAddress.Trim())))
        $message.Subject = $fullSubject -replace '[\r\n]', ' '
        $message.Body = $Body
        $message.BodyEncoding = [System.Text.Encoding]::UTF8
        $message.SubjectEncoding = [System.Text.Encoding]::UTF8

        $smtpClient = New-Object System.Net.Mail.SmtpClient ($emailConfig.SMTPServer, [int]$emailConfig.SMTPPort)
        $smtpClient.EnableSsl = ($emailConfig.SMTPUseSsl -eq "1")
        # Keine Passwörter in der Konfiguration: Anmeldung mit dem aktuellen Windows-Konto (oder anonymes Relay)
        $smtpClient.UseDefaultCredentials = $true
        $smtpClient.Send($message)

        Write-LogMessage "E-Mail-Benachrichtigung gesendet an: $EmailAddress - Betreff: $fullSubject" -logLevel "INFO"
        return $true
    }
    catch {
        Write-LogMessage "Fehler beim Senden der E-Mail-Benachrichtigung: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Senden der E-Mail: $($_.Exception.Message)", "E-Mail-Fehler") | Out-Null
        return $false
    }
    finally {
        if ($message) { $message.Dispose() }
        if ($smtpClient) { $smtpClient.Dispose() }
    }
}

function Test-EmailConfiguration {
    if (-not (Test-EmailAddress -Address $textBoxNotificationEmail.Text)) {
        [System.Windows.MessageBox]::Show("Bitte geben Sie eine gültige E-Mail-Adresse ein.", "Fehler") | Out-Null
        return
    }

    $testSubject = "Test-Benachrichtigung"
    $testBody = "Dies ist eine Test-E-Mail von easyADgroup.`n`nZeitpunkt: $(Get-Date)`nBenutzer: $env:USERNAME`nComputer: $env:COMPUTERNAME"

    $success = Send-EmailNotification -EmailAddress $textBoxNotificationEmail.Text -Subject $testSubject -Body $testBody

    if ($success) {
        Update-StatusLabel "Test-E-Mail verarbeitet"
    } else {
        Update-StatusLabel "Fehler beim Senden der Test-E-Mail"
    }
}

function New-GroupReport {
    # [12.2 | GENERATE REPORT]
    # [ENGLISH - Generates a detailed report of created groups]
    # [GERMAN - Erstellt einen detaillierten Bericht der erstellten Gruppen]
    try {
        if ($script:createdGroups.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Keine Gruppen zum Berichten vorhanden. Erstellen Sie zuerst Gruppen.", "Kein Bericht verfügbar") | Out-Null
            return
        }

        $reportLines = New-Object System.Collections.Generic.List[string]
        $reportLines.Add("easyADgroup - Gruppenerstellungs-Bericht")
        $reportLines.Add("========================================")
        $reportLines.Add("")
        $reportLines.Add("Datum: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')")
        $reportLines.Add("Benutzer: $env:USERDOMAIN\$env:USERNAME")
        $reportLines.Add("Computer: $env:COMPUTERNAME")
        $reportLines.Add("AD-Server: $($script:adServer)")
        $reportLines.Add("Version: $($generalConfig.ScriptVersion)")
        $reportLines.Add("")
        $reportLines.Add("Erstellte Gruppen in dieser Sitzung ($($script:createdGroups.Count)):")
        foreach ($groupName in $script:createdGroups) {
            $reportLines.Add("• $groupName")
        }
        $reportLines.Add("")
        $reportLines.Add("Aktuelle Formular-Konfiguration:")
        $reportLines.Add("- OU: $($comboBoxOU.SelectedValue)")
        $reportLines.Add("- Gruppentyp: $(Get-SelectedGroupType)")
        $reportLines.Add("- Geltungsbereich: $(Get-SelectedGroupScope)")
        $reportLines.Add("- Spezial-Modus: $(if ($chkSpecial.IsChecked) { 'Ja' } else { 'Nein' })")
        $reportLines.Add("")
        $reportLines.Add("Log-Datei: $($script:config.LogPath)")

        # Speichere Bericht
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = "Text-Dateien (*.txt)|*.txt"
        $saveDialog.Title = "Bericht speichern"
        $saveDialog.FileName = "easyADgroup_Bericht_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"

        if ($saveDialog.ShowDialog() -eq $true) {
            Set-Content -LiteralPath $saveDialog.FileName -Value $reportLines -Encoding UTF8 -ErrorAction Stop
            Write-LogMessage "Bericht gespeichert: $($saveDialog.FileName)" -logLevel "INFO"
            [System.Windows.MessageBox]::Show("Bericht wurde erfolgreich gespeichert.", "Bericht erstellt") | Out-Null

            # Öffne Bericht
            Start-Process -FilePath "notepad.exe" -ArgumentList "`"$($saveDialog.FileName)`""
        }
    }
    catch {
        Write-LogMessage "Fehler beim Erstellen des Berichts: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Erstellen des Berichts: $($_.Exception.Message)", "Fehler") | Out-Null
    }
}
#endregion

# [13.0 | ACTION BUTTONS]
#region Action Buttons
function Show-Help {
    $helpText = @"
easyADgroup $($generalConfig.ScriptVersion) - Kurzanleitung

1. Ziel-OU auswählen.
2. Gruppennamen eingeben.
   - Start/Ende leer: eine Gruppe
   - Start/Ende gefüllt: Nummernbereich (Name + Separator + Nummer)
   - JIRA/Confluence Mode: Name + Separator + Suffix ($($adgroupsConfig.AdditionalSuffixes))
   - Auto-Naming: Namens-Template '$($adgroupsConfig.NamingTemplate)'
3. Typ (Security/Distribution) und Bereich (Global/Universal/Domain Local) wählen.
4. Optional Benutzer auswählen (Strg/Umschalt+Klick, Suche mit * und ? möglich).
5. 'Preview' prüfen, dann 'Create'. 'Test Run' simuliert ohne Änderungen.

CSV: 'Template' exportiert eine Vorlage, 'Import' erstellt Gruppen aus einer CSV-Datei.
Vorlagen: 'Save' speichert, 'Templates' lädt die Formular-Konfiguration.

Konfiguration: $iniPath
Log-Datei: $($script:config.LogPath)
"@
    [System.Windows.MessageBox]::Show($helpText, "Hilfe", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
}

function Open-Website {
    param(
        [string]$Url
    )
    # Nur http/https-URLs öffnen
    $uri = $null
    if ([System.Uri]::TryCreate($Url, [System.UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -in @('http', 'https')) {
        Start-Process -FilePath $uri.AbsoluteUri
    } else {
        Write-LogMessage "Ungültige oder nicht erlaubte URL: '$Url'" -logLevel "WARNING"
    }
}

function Invoke-GroupCreation {
    # [13.7 | GROUP CREATION]
    Write-LogMessage "Erstellungs-Button geklickt" -logLevel "INFO"
    Update-StatusLabel "Validiere Eingaben..."

    $errors = @(Test-Input)
    if ($errors.Count -gt 0) {
        Write-LogMessage "Validierungsfehler bei Gruppenerstellung: $($errors -join ', ')" -logLevel "WARNING"
        [System.Windows.MessageBox]::Show(($errors -join "`n"), "Validierungsfehler") | Out-Null
        Update-StatusLabel "Validierungsfehler"
        return
    }

    # Bestätigungsdialog
    $groupsToCreate = @(Get-GroupsToCreate)
    $dryRun = [bool]$chkDryRun.IsChecked
    $confirmText = "Möchten Sie $($groupsToCreate.Count) Gruppe(n) in`n$($comboBoxOU.SelectedValue)`nerstellen?"
    if ($dryRun) {
        $confirmText += "`n`nTESTLAUF AKTIVIERT - Es werden keine Änderungen vorgenommen"
    }

    $result = [System.Windows.MessageBox]::Show($confirmText, "Gruppenerstellung bestätigen", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusLabel "Gruppenerstellung abgebrochen"
        return
    }

    # Ausgewählte Benutzer (inkl. durch Filter ausgeblendeter Auswahl)
    $script:selectedUsers = @($script:selectedUserSet)
    Write-LogMessage "Es wurden $($script:selectedUsers.Count) Benutzer für die Gruppenmitgliedschaft ausgewählt" -logLevel "INFO"

    $fixedMembers = @()
    if ($adgroupsConfig.GroupMembersAddActive -eq "1") {
        $fixedMembers = @("$($adgroupsConfig.GroupMembersAdd)".Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    $ouPath = [string]$comboBoxOU.SelectedValue
    $groupScope = Get-SelectedGroupScope
    $groupCategory = Get-SelectedGroupType
    $description = if ([string]::IsNullOrWhiteSpace($textBoxDescription.Text)) { $adgroupsConfig.GroupDescription } else { $textBoxDescription.Text.Trim() }

    $total = $groupsToCreate.Count
    $processed = 0
    $created = 0
    $skipped = 0
    $errors = New-Object System.Collections.Generic.List[string]

    Set-BusyState -Busy $true
    try {
        Update-StatusLabel "Erstelle Gruppen..."

        # OU automatisch erstellen (einmalig vor der Schleife)
        if (-not $dryRun -and $chkCreateOUIfNotExists.IsChecked -eq $true) {
            if (-not (Initialize-OrganizationalUnit -OUPath $ouPath)) {
                throw "Die OU '$ouPath' konnte nicht erstellt werden"
            }
        }

        # Vorhandene Gruppen einmalig gebündelt ermitteln
        $existingSams = @(Get-ExistingGroupSam -SamAccountNames ($groupsToCreate | ForEach-Object { Get-GroupSamAccountName -GroupName $_ }))

        foreach ($groupName in $groupsToCreate) {
            try {
                $samAccountName = Get-GroupSamAccountName -GroupName $groupName
                if ($samAccountName -ne $groupName) {
                    Write-LogMessage "SAMAccountName für $groupName wurde auf $samAccountName gekürzt" -logLevel "WARNING"
                }

                if ($existingSams -contains $samAccountName) {
                    $skipped++
                    Write-LogMessage "Gruppe mit SAMAccountName $samAccountName existiert bereits - wird übersprungen" -logLevel "WARNING"
                }
                elseif ($dryRun) {
                    Write-LogMessage "TESTLAUF: Gruppe $groupName würde erstellt werden" -logLevel "INFO"
                    [void]$script:createdGroups.Add("[TESTLAUF] $groupName")
                }
                else {
                    $params = @{
                        Name = $groupName
                        SamAccountName = $samAccountName
                        Path = $ouPath
                        GroupScope = $groupScope
                        GroupCategory = $groupCategory
                        Description = $description
                        DisplayName = $groupName
                    }
                    Write-DebugMessage "Erstelle Gruppe: $groupName mit Parametern: $($params | ConvertTo-Json -Compress)"

                    # Alle AD-Cmdlets nutzen denselben DC (Initialize-ADConnection) - keine Wartezeit für Replikation nötig
                    $group = New-ADGroup @params -PassThru -ErrorAction Stop
                    [void]$script:createdGroups.Add($group.Name)
                    $created++
                    Write-LogMessage "Gruppe $groupName erfolgreich erstellt" -logLevel "INFO"

                    $members = @(@($script:selectedUsers) + @($fixedMembers) | Select-Object -Unique)
                    if ($members.Count -gt 0) {
                        try {
                            Add-ADGroupMember -Identity $group -Members $members -ErrorAction Stop
                            Write-LogMessage "Mitglieder zu $groupName hinzugefügt: $($members -join ', ')" -logLevel "INFO"
                        }
                        catch {
                            $errors.Add("Mitglieder für '$groupName' konnten nicht hinzugefügt werden: $($_.Exception.Message)")
                            Write-LogMessage "Fehler beim Hinzufügen von Mitgliedern zu ${groupName}: $($_.Exception.Message)" -logLevel "ERROR"
                        }
                    }
                }
            }
            catch {
                $errorMsg = "Fehler bei Gruppe '$groupName': $($_.Exception.Message)"
                $errors.Add($errorMsg)
                Write-LogMessage $errorMsg -logLevel "ERROR"
            }

            $processed++
            $progressBarMain.Value = ($processed / $total) * 100
            Update-StatusLabel "Fortschritt: $processed/$total Gruppen"
        }
    }
    catch {
        $errors.Add("Kritischer Fehler: $($_.Exception.Message)")
        Write-LogMessage "Kritischer Fehler bei Gruppenerstellung: $($_.Exception.Message)" -logLevel "ERROR"
    }
    finally {
        Set-BusyState -Busy $false
    }

    # Ergebnis anzeigen
    $resultMsg = if ($dryRun) { "TESTLAUF abgeschlossen" } else { "Gruppenerstellung abgeschlossen" }
    $resultMsg += "`n$processed von $total Gruppen verarbeitet, $created erstellt, $skipped übersprungen."
    if ($errors.Count -gt 0) {
        $resultMsg += "`n`nFehler ($($errors.Count)):`n" + (($errors | Select-Object -First 20) -join "`n")
    }

    [System.Windows.MessageBox]::Show($resultMsg, "Erstellung abgeschlossen") | Out-Null
    Update-StatusLabel "Erstellung abgeschlossen: $created erstellt, $skipped übersprungen, $($errors.Count) Fehler"

    # E-Mail-Benachrichtigung senden
    if ($chkEmailNotification.IsChecked -eq $true) {
        [void](Send-EmailNotification -EmailAddress $textBoxNotificationEmail.Text -Subject "Gruppenerstellung abgeschlossen" -Body $resultMsg)
    }

    Write-LogMessage "Gruppenerstellung abgeschlossen. $created/$total Gruppen erstellt, $skipped übersprungen, $($errors.Count) Fehler (Testlauf: $dryRun)" -logLevel "INFO"
}

function Add-ButtonEventHandler {
    # [13.1 | TEMPLATE BUTTONS]
    $buttonLoadTemplate.Add_Click({
        Write-DebugMessage "Vorlagen-Laden-Button geklickt"
        Update-TemplateList

        if ($script:templates.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Keine Vorlagen gefunden. Erstellen Sie zuerst eine Vorlage.", "Keine Vorlagen") | Out-Null
            return
        }

        $templateNames = @($script:templates.Keys | Sort-Object)
        $selectedTemplate = Show-SelectionDialog -Title "Vorlage laden" -Prompt "Vorlage auswählen:" -Items $templateNames

        if ($selectedTemplate) {
            Import-GroupTemplate -TemplateName $selectedTemplate
        }
    })

    $buttonSaveTemplate.Add_Click({
        Write-DebugMessage "Vorlagen-Speichern-Button geklickt"

        $templateName = [Microsoft.VisualBasic.Interaction]::InputBox("Geben Sie einen Namen für die Vorlage ein:", "Vorlage speichern", "Meine_Vorlage")

        # Nur sichere Dateinamen zulassen (keine Pfade, keine reservierten Zeichen)
        $templateName = ($templateName -replace '[^\w\-\. ]', '_').Trim(' ', '.')
        if (-not [string]::IsNullOrWhiteSpace($templateName)) {
            Save-GroupTemplate -TemplateName $templateName
        }
    })

    $buttonReset.Add_Click({
        Write-DebugMessage "Reset-Button geklickt"
        Reset-Form
    })

    # [13.2 | USER MANAGEMENT BUTTONS]
    $buttonSearchUsers.Add_Click({
        Write-DebugMessage "Benutzersuche-Button geklickt"
        if ($script:searchTimer) { $script:searchTimer.Stop() }
        Search-User -SearchTerm $textBoxUserSearch.Text
    })

    $buttonSelectAllUsers.Add_Click({
        Write-DebugMessage "Alle-Benutzer-auswählen-Button geklickt"
        Select-AllUser
    })

    $buttonDeselectAllUsers.Add_Click({
        Write-DebugMessage "Benutzerauswahl-aufheben-Button geklickt"
        Clear-UserSelection
    })

    $buttonRefreshUsers.Add_Click({
        Write-DebugMessage "Benutzerliste-aktualisieren-Button geklickt"
        Update-UserList
    })

    $listBoxUsers.Add_SelectionChanged({
        # $_ enthält die SelectionChangedEventArgs
        Sync-UserSelection -SelectionArgs $_
    })

    # [13.3 | CSV IMPORT/EXPORT BUTTONS]
    $buttonDownloadTemplate.Add_Click({
        Write-DebugMessage "CSV-Vorlage-herunterladen-Button geklickt"
        Export-CSVTemplate
    })

    $buttonImportCSV.Add_Click({
        Write-DebugMessage "CSV-Import-Button geklickt"
        Import-CSVGroup
    })

    # [13.4 | EMAIL NOTIFICATION BUTTONS]
    $buttonTestEmail.Add_Click({
        Write-DebugMessage "Test-E-Mail-Button geklickt"
        Test-EmailConfiguration
    })

    # [13.5 | SEARCH BOX EVENT]
    # Ein einziger Timer für die verzögerte Suche (statt eines neuen Timers pro Tastendruck)
    $searchDelay = 500
    [void][int]::TryParse("$($advancedConfig.SearchDelayMs)", [ref]$searchDelay)
    $script:searchTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:searchTimer.Interval = [TimeSpan]::FromMilliseconds([Math]::Max(0, $searchDelay))
    $script:searchTimer.Add_Tick({
        $script:searchTimer.Stop()
        Search-User -SearchTerm $textBoxUserSearch.Text
    })

    $textBoxUserSearch.Add_TextChanged({
        $script:searchTimer.Stop()
        $script:searchTimer.Start()
    })

    # [13.6 | PREVIEW BUTTON]
    $buttonPreview.Add_Click({
        Write-DebugMessage "Vorschau-Button geklickt"
        Update-StatusLabel "Erstelle Vorschau..."

        $errors = @(Test-Input)
        if ($errors.Count -gt 0) {
            Write-LogMessage "Validierungsfehler bei Vorschau: $($errors -join ', ')" -logLevel "WARNING"
            [System.Windows.MessageBox]::Show(($errors -join "`n"), "Validierungsfehler") | Out-Null
            Update-StatusLabel "Validierungsfehler"
            return
        }

        $groupsToCreate = @(Get-GroupsToCreate)
        $previewText = "Folgende Gruppen würden erstellt werden:`n`n"

        foreach ($groupName in ($groupsToCreate | Select-Object -First 30)) {
            $samAccountName = Get-GroupSamAccountName -GroupName $groupName
            $previewText += if ($samAccountName -ne $groupName) { "• $groupName  (sAMAccountName: $samAccountName)`n" } else { "• $groupName`n" }
        }
        if ($groupsToCreate.Count -gt 30) { $previewText += "… und $($groupsToCreate.Count - 30) weitere`n" }

        $previewText += "`nAnzahl: $($groupsToCreate.Count) Gruppen"
        $previewText += "`nOU: $($comboBoxOU.SelectedValue)"
        $previewText += "`nTyp: $(Get-SelectedGroupType)"
        $previewText += "`nBereich: $(Get-SelectedGroupScope)"
        $previewText += "`nMitglieder: $($script:selectedUserSet.Count) ausgewählte Benutzer"

        if ($chkDryRun.IsChecked) {
            $previewText += "`n`nTESTLAUF AKTIVIERT - Es werden keine Änderungen vorgenommen"
        }

        Write-LogMessage "Vorschau generiert für $($groupsToCreate.Count) Gruppen" -logLevel "INFO"
        Update-StatusLabel "Vorschau erstellt"
        [System.Windows.MessageBox]::Show($previewText, "Vorschau Gruppenerstellung") | Out-Null
    })

    # [13.7 | CREATE BUTTON]
    $buttonCreate.Add_Click({
        Invoke-GroupCreation
    })

    # [13.8 | REPORT BUTTON]
    $buttonReport.Add_Click({
        Write-DebugMessage "Bericht-Button geklickt"
        New-GroupReport
    })

    # [13.9 | HELP AND WEBSITE]
    $buttonHelp.Add_Click({
        Show-Help
    })

    $hyperlinkWebsite.Add_RequestNavigate({
        # $_ enthält die RequestNavigateEventArgs
        Open-Website -Url $_.Uri.AbsoluteUri
        $_.Handled = $true
    })

    # [13.10 | CLOSE BUTTON]
    $buttonClose.Add_Click({
        Write-LogMessage "Anwendung wird beendet" -logLevel "INFO"
        $window.Close()
    })

    $window.Add_Closed({
        if ($script:searchTimer) { $script:searchTimer.Stop() }
    })
}
#endregion

# [14.0 | MAIN EXECUTION]
function Initialize-MainApplication {
    # XAML direkt im Script definiert
    $xamlContent = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="easyADgroup - Modern AD Group Manager"
    Width="1400"
    Height="1003"
    WindowStartupLocation="CenterScreen"
    ResizeMode="CanResize"
    MinWidth="1100"
    MinHeight="700"
    Background="#F3F3F3"
    WindowStyle="SingleBorderWindow">

    <Window.Resources>
        <!-- Modern Windows 11 Style Resources -->
        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="4"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                BorderBrush="{TemplateBinding BorderBrush}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#106EBE"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#005A9E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="#F3F2F1"/>
            <Setter Property="Foreground" Value="#323130"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#D2D0CE"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#EDEBE9"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#E1DFDD"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="#D13438"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#B02E32"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#A02B2F"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="CompactGroupBox" TargetType="GroupBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="#E1DFDD"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Margin" Value="0,4,0,4"/>
            <Setter Property="Padding" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="GroupBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Border Grid.Row="0" Background="#F8F8F8" CornerRadius="6,6,0,0" Padding="12,8">
                                    <ContentPresenter ContentSource="Header" TextElement.FontWeight="SemiBold" TextElement.FontSize="14"/>
                                </Border>
                                <ContentPresenter Grid.Row="1" Margin="{TemplateBinding Padding}"/>
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="InfoGroupBox" TargetType="GroupBox" BasedOn="{StaticResource CompactGroupBox}">
            <Setter Property="Background" Value="#F0F8FF"/>
            <Setter Property="BorderBrush" Value="#B3D9FF"/>
        </Style>

        <Style x:Key="ModernTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="#323130"/>
            <Setter Property="BorderBrush" Value="#D2D0CE"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="CaretBrush" Value="#323130"/>
            <Setter Property="SelectionBrush" Value="#0078D4"/>
        </Style>

        <Style x:Key="ModernComboBox" TargetType="ComboBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="#D2D0CE"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="3">
                            <Grid>
                                <ToggleButton x:Name="ToggleButton" Background="Transparent" BorderThickness="0"
                                              IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}}"
                                              ClickMode="Press"/>
                                <Path x:Name="Arrow" Data="M 0 0 L 4 4 L 8 0 Z" Fill="#605E5C"
                                      HorizontalAlignment="Right" VerticalAlignment="Center"
                                      Margin="0,0,10,0" IsHitTestVisible="False"/>
                                <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False"
                                                  Content="{TemplateBinding SelectionBoxItem}"
                                                  ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                                  ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                                  Margin="{TemplateBinding Padding}"
                                                  VerticalAlignment="Center"
                                                  HorizontalAlignment="Left"/>
                                <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                       AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                    <Border Background="White" BorderBrush="#D2D0CE" BorderThickness="1" CornerRadius="3"
                                            MinWidth="{TemplateBinding ActualWidth}" MaxHeight="200">
                                        <ScrollViewer>
                                            <StackPanel IsItemsHost="True"/>
                                        </ScrollViewer>
                                    </Border>
                                </Popup>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="#0078D4"/>
                                <Setter Property="BorderThickness" Value="2"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernListBox" TargetType="ListBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="#D2D0CE"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="3">
                            <ScrollViewer Focusable="False" CanContentScroll="True">
                                <ItemsPresenter/>
                            </ScrollViewer>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="VirtualizingPanel.IsVirtualizing" Value="True"/>
            <Setter Property="VirtualizingPanel.VirtualizationMode" Value="Recycling"/>
        </Style>

        <Style x:Key="ModernRadioButton" TargetType="RadioButton">
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,2"/>
            <Setter Property="Padding" Value="6,0,0,0"/>
        </Style>

        <Style x:Key="ModernCheckBox" TargetType="CheckBox">
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,4"/>
            <Setter Property="Padding" Value="6,0,0,0"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="70" />
            <RowDefinition Height="*" />
            <RowDefinition Height="40" />
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" x:Name="headerBorder" Background="#0078D4" Height="70">
            <Grid Margin="20,12">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <TextBlock x:Name="labelAppName"
                               Text="easyADgroup"
                               FontSize="20"
                               FontWeight="Bold"
                               Foreground="White"/>
                    <TextBlock x:Name="labelInfo"
                               FontSize="11"
                               Foreground="#E1F5FE"
                               Margin="0,2,0,0"/>
                </StackPanel>

                <Button Grid.Column="1"
                        x:Name="buttonHelp"
                        Style="{StaticResource SecondaryButton}"
                        Height="34"
                        Width="90"
                        VerticalAlignment="Center"
                        ToolTip="Kurzanleitung anzeigen">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="?" FontSize="16" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,6,0"/>
                        <TextBlock Text="HELP"
                                   FontWeight="SemiBold"
                                   FontSize="13"
                                   VerticalAlignment="Center"
                                   Foreground="#323130"/>
                    </StackPanel>
                </Button>
            </Grid>
        </Border>

        <!-- Main Content -->
        <Grid Grid.Row="1" Margin="16,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="2*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="3*"/>
            </Grid.ColumnDefinitions>

            <!-- Left Column: Configuration -->
            <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <StackPanel>

                <!-- Quick Actions -->
                <GroupBox Header="Quick Actions" Style="{StaticResource CompactGroupBox}">
                    <UniformGrid Columns="3" Margin="0,4">
                        <Button Content="Templates" Style="{StaticResource SecondaryButton}"
                                x:Name="buttonLoadTemplate" Margin="0,0,4,0" Height="28"/>
                        <Button Content="Save" Style="{StaticResource SecondaryButton}"
                                x:Name="buttonSaveTemplate" Margin="2,0" Height="28"/>
                        <Button Content="Reset" Style="{StaticResource SecondaryButton}"
                                x:Name="buttonReset" Margin="4,0,0,0" Height="28"/>
                    </UniformGrid>
                </GroupBox>

                <!-- OU Selection -->
                <GroupBox Header="OU Selection" Style="{StaticResource CompactGroupBox}" Margin="0,8,0,8">
                    <StackPanel>
                        <TextBlock Text="Target OU for new groups:" Margin="0,0,0,4" FontSize="12"/>
                        <ComboBox x:Name="comboBoxOU"
                                  Style="{StaticResource ModernComboBox}"
                                  DisplayMemberPath="Path"
                                  SelectedValuePath="DN"
                                  Height="35"/>
                    </StackPanel>
                </GroupBox>

                <!-- Group Configuration -->
                <GroupBox Header="Group Configuration" Style="{StaticResource CompactGroupBox}" Height="365">
                    <Grid Height="320">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Group Name -->
                        <Grid Grid.Row="0" Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="Name:" VerticalAlignment="Center" FontWeight="SemiBold" FontSize="12"/>
                            <TextBox Grid.Column="1" x:Name="textBoxPrefix" Height="25"/>
                        </Grid>

                        <!-- Number Range -->
                        <Grid Grid.Row="1" Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="80"/>
                                <ColumnDefinition Width="80"/>
                            </Grid.ColumnDefinitions>

                            <TextBlock Grid.Column="0" Text="Range:" VerticalAlignment="Center" FontWeight="SemiBold" FontSize="12"/>

                            <StackPanel Grid.Column="1" Margin="0,0,4,0">
                                <TextBlock Text="Separator" FontSize="10" Margin="0,0,0,2"/>
                                <TextBox x:Name="textBoxSeparator" Text="-" Height="25"/>
                            </StackPanel>

                            <StackPanel Grid.Column="2" Margin="2,0">
                                <TextBlock Text="Start" FontSize="10" Margin="0,0,0,2"/>
                                <TextBox x:Name="textBoxStart" Height="25"/>
                            </StackPanel>

                            <StackPanel Grid.Column="3" Margin="4,0,0,0">
                                <TextBlock Text="End" FontSize="10" Margin="0,0,0,2"/>
                                <TextBox x:Name="textBoxEnd" Height="25"/>
                            </StackPanel>
                        </Grid>

                        <!-- Description -->
                        <Grid Grid.Row="2" Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="Description:" VerticalAlignment="Center" FontWeight="SemiBold" FontSize="12"/>
                            <TextBox Grid.Column="1" x:Name="textBoxDescription" Height="25"/>
                        </Grid>

                        <!-- Type and Scope -->
                        <Grid Grid.Row="3" Margin="0,10,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="4"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Border Grid.Column="0" Background="#F8F8F8" CornerRadius="4" Padding="8">
                                <StackPanel>
                                    <TextBlock Text="Type" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                    <RadioButton x:Name="radioSecurity" Content="Security"
                                                 IsChecked="True" Style="{StaticResource ModernRadioButton}"/>
                                    <RadioButton x:Name="radioDistribution" Content="Distribution"
                                                 Style="{StaticResource ModernRadioButton}"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="2" Background="#F8F8F8" CornerRadius="4" Padding="8">
                                <StackPanel>
                                    <TextBlock Text="Scope" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                    <RadioButton x:Name="radioGlobal" Content="Global"
                                                 IsChecked="True" Style="{StaticResource ModernRadioButton}"/>
                                    <RadioButton x:Name="radioUniversal" Content="Universal"
                                                 Style="{StaticResource ModernRadioButton}"/>
                                    <RadioButton x:Name="radioDomainLocal" Content="Domain Local"
                                                 Style="{StaticResource ModernRadioButton}"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- Options -->
                        <UniformGrid Grid.Row="4" Columns="3">
                            <CheckBox x:Name="chkSpecial"
                                      Content="JIRA/Confluence Mode"
                                      Style="{StaticResource ModernCheckBox}" Margin="0,10,2,0"/>
                            <CheckBox x:Name="chkAutoNaming"
                                      Content="Auto-Naming"
                                      Style="{StaticResource ModernCheckBox}" Margin="2,10,2,0"/>
                            <CheckBox x:Name="chkCreateOUIfNotExists"
                                      Content="Auto-create OU"
                                      Style="{StaticResource ModernCheckBox}" Margin="2,10,0,0"/>
                        </UniformGrid>
                    </Grid>
                </GroupBox>

                <!-- Advanced Options -->
                <GroupBox Header="Advanced Options" Style="{StaticResource CompactGroupBox}" Height="218" Margin="0,11,0,0">
                    <Grid Height="150">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- CSV Operations -->
                        <Border Grid.Row="0" Background="#FFF4E6" CornerRadius="4" Padding="8" Margin="0,0,0,8">
                            <StackPanel>
                                <TextBlock Text="CSV Import/Export" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                <UniformGrid Columns="2">
                                    <Button Content="Template" Style="{StaticResource SecondaryButton}"
                                            x:Name="buttonDownloadTemplate" Margin="0,0,2,0" Height="24"/>
                                    <Button Content="Import" Style="{StaticResource SecondaryButton}"
                                            x:Name="buttonImportCSV" Margin="2,0,0,0" Height="24"/>
                                </UniformGrid>
                            </StackPanel>
                        </Border>

                        <!-- Validation and Email in one row -->
                        <Grid Grid.Row="1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Validation -->
                            <Border Grid.Column="0" Background="#E8F5E8" CornerRadius="4" Padding="8">
                                <StackPanel>
                                    <TextBlock Text="Validation" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                    <UniformGrid Columns="3">
                                        <CheckBox x:Name="chkValidateNames" Content="Names"
                                                  IsChecked="True" Style="{StaticResource ModernCheckBox}" FontSize="11" Margin="0,0,2,0"/>
                                        <CheckBox x:Name="chkCheckDuplicates" Content="Duplicates"
                                                  IsChecked="True" Style="{StaticResource ModernCheckBox}" FontSize="11" Margin="2,0,2,0"/>
                                        <CheckBox x:Name="chkDryRun" Content="Test Run"
                                                  Style="{StaticResource ModernCheckBox}" FontSize="11" Margin="2,0,0,0"/>
                                    </UniformGrid>
                                </StackPanel>
                            </Border>

                            <!-- Email -->
                            <Border Grid.Column="2" Background="#F0F8FF" CornerRadius="4" Padding="8">
                                <StackPanel>
                                    <TextBlock Text="Email Notification" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,4"/>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <CheckBox Grid.Column="0" x:Name="chkEmailNotification" Content=""
                                                  Style="{StaticResource ModernCheckBox}" Margin="0,0,4,0"/>
                                        <TextBox Grid.Column="1" x:Name="textBoxNotificationEmail"
                                                 Margin="0,0,4,0" Height="25"/>
                                        <Button Grid.Column="2" Content="Test" Style="{StaticResource SecondaryButton}"
                                                x:Name="buttonTestEmail" Width="40" Height="24"/>
                                    </Grid>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </Grid>
                </GroupBox>
            </StackPanel>
            </ScrollViewer>

            <!-- Right Column: Users and Info -->
            <Grid Grid.Column="2">
                <Grid.RowDefinitions>
                    <RowDefinition Height="2*"/>
                    <RowDefinition Height="8"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="8"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <!-- Group Members -->
                <GroupBox Grid.Row="0" Header="Group Members" Style="{StaticResource CompactGroupBox}">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Search Field -->
                        <Grid Grid.Row="0" Margin="0,0,0,6">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox Grid.Column="0" x:Name="textBoxUserSearch"
                                     Margin="0,0,6,0" Height="32"
                                     ToolTip="Enter username or display name to search"
                                     Foreground="Black"
                                     Background="White"
                                     BorderBrush="#D2D0CE"
                                     BorderThickness="1"
                                     Padding="8,6"
                                     FontSize="13"/>
                            <Button Grid.Column="1" Content="Search"
                                    Style="{StaticResource SecondaryButton}"
                                    x:Name="buttonSearchUsers" Width="60" Height="28"/>
                        </Grid>

                        <TextBlock Grid.Row="1" Text="Select users (Ctrl+Click):"
                                   Margin="0,0,0,4" FontSize="12"/>

                        <ListBox Grid.Row="2" x:Name="listBoxUsers"
                                 Style="{StaticResource ModernListBox}"
                                 SelectionMode="Extended"/>

                        <!-- User Actions -->
                        <UniformGrid Grid.Row="3" Columns="3" Margin="0,6,0,0">
                            <Button Content="Select All" Style="{StaticResource SecondaryButton}"
                                    x:Name="buttonSelectAllUsers" Margin="0,0,2,0" Height="26"/>
                            <Button Content="Clear" Style="{StaticResource SecondaryButton}"
                                    x:Name="buttonDeselectAllUsers" Margin="1,0" Height="26"/>
                            <Button Content="Refresh" Style="{StaticResource SecondaryButton}"
                                    x:Name="buttonRefreshUsers" Margin="2,0,0,0" Height="26"/>
                        </UniformGrid>
                    </Grid>
                </GroupBox>

                <!-- Info Box -->
                <GroupBox Grid.Row="2" Header="Quick Guide" Style="{StaticResource InfoGroupBox}" Height="120">
                    <StackPanel>
                        <TextBlock Text="1. Select target OU for group creation   ->   2. Enter an optional group name prefix and number range / if left blank, only one group will be created." FontSize="11" Margin="0,2" TextWrapping="Wrap"/>
                        <TextBlock Text="3. Choose group type (Security/Distribution) and scope   ->   4. Select users to add to groups (optional)   ->   5. Use Preview to check and create group(s)" FontSize="11" Margin="0,2" FontWeight="SemiBold" TextWrapping="Wrap"/>
                    </StackPanel>
                </GroupBox>

                <!-- Action Buttons -->
                <Grid Grid.Row="4">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Progress Bar -->
                    <ProgressBar Grid.Row="0" x:Name="progressBarMain"
                                 Height="6"
                                 Visibility="Collapsed"
                                 Background="#F3F2F1"
                                 Foreground="#0078D4"
                                 Margin="0,0,0,8"/>

                    <!-- Buttons -->
                    <UniformGrid Grid.Row="1" Columns="4">
                        <Button Content="Preview"
                                Style="{StaticResource SecondaryButton}"
                                x:Name="buttonPreview"
                                Height="36"
                                Margin="0,0,4,0"/>

                        <Button Content="Create"
                                Style="{StaticResource ModernButton}"
                                x:Name="buttonCreate"
                                Height="36"
                                Margin="2,0"/>

                        <Button Content="Report"
                                Style="{StaticResource SecondaryButton}"
                                x:Name="buttonReport"
                                Height="36"
                                Margin="2,0"/>

                        <Button Content="Close"
                                Style="{StaticResource DangerButton}"
                                x:Name="buttonClose"
                                Height="36"
                                Margin="4,0,0,0"/>
                    </UniformGrid>
                </Grid>
            </Grid>
        </Grid>

        <!-- Footer -->
        <Border Grid.Row="2" x:Name="footerBorder" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Height="40">
            <Grid Margin="20,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="Web:" FontSize="12" VerticalAlignment="Center" Margin="0,0,6,0"/>
                    <TextBlock x:Name="linkLabel" VerticalAlignment="Center">
                        <Hyperlink x:Name="hyperlinkWebsite" NavigateUri="https://phinit.de/easyit-tools"
                                   TextDecorations="None" Foreground="#0078D4" FontSize="12">
                            <Run x:Name="hyperlinkWebsiteText" Text="www.phinit.de"/>
                        </Hyperlink>
                    </TextBlock>
                </StackPanel>

                <TextBlock Grid.Column="1" x:Name="statusLabel"
                           Text="Ready"
                           VerticalAlignment="Center"
                           FontSize="11"
                           Foreground="#605E5C"
                           Margin="0,0,12,0"/>

                <TextBlock Grid.Column="2" x:Name="footerInfo"
                           VerticalAlignment="Center"
                           FontSize="11"
                           Foreground="#605E5C"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

    try {
        # XAML laden und WPF-Objekte erstellen
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlContent)
        $script:window = [Windows.Markup.XamlReader]::Load($reader)

        Write-DebugMessage "XAML erfolgreich aus eingebettetem String geladen"

        # Elemente der GUI anhand von Namen abrufen (alle benannten Elemente als Script-Variablen)
        $controlNames = @(
            'comboBoxOU', 'listBoxUsers', 'textBoxPrefix', 'textBoxSeparator', 'textBoxStart', 'textBoxEnd',
            'textBoxDescription', 'radioSecurity', 'radioDistribution', 'radioGlobal', 'radioUniversal',
            'radioDomainLocal', 'chkSpecial', 'buttonPreview', 'buttonCreate', 'buttonClose',
            'textBoxUserSearch', 'textBoxNotificationEmail', 'chkAutoNaming', 'chkCreateOUIfNotExists',
            'chkValidateNames', 'chkCheckDuplicates', 'chkDryRun', 'chkEmailNotification',
            'buttonLoadTemplate', 'buttonSaveTemplate', 'buttonReset', 'buttonSearchUsers',
            'buttonSelectAllUsers', 'buttonDeselectAllUsers', 'buttonRefreshUsers', 'buttonDownloadTemplate',
            'buttonImportCSV', 'buttonTestEmail', 'buttonReport', 'buttonHelp', 'progressBarMain', 'statusLabel',
            'labelAppName', 'labelInfo', 'headerBorder', 'footerBorder', 'footerInfo',
            'hyperlinkWebsite', 'hyperlinkWebsiteText'
        )
        foreach ($controlName in $controlNames) {
            $control = $script:window.FindName($controlName)
            if (-not $control) { throw "GUI-Element '$controlName' wurde im XAML nicht gefunden" }
            Set-Variable -Name $controlName -Value $control -Scope Script
        }

        # [14.1 | APPLY CONFIGURATION TO GUI]
        $brushConverter = New-Object System.Windows.Media.BrushConverter
        $applyBrush = {
            param($Target, $Property, $Color)
            try { $Target.$Property = $brushConverter.ConvertFromString($Color) }
            catch { Write-LogMessage "Ungültige Farbe '$Color' für $Property ignoriert" -logLevel "WARNING" }
        }
        & $applyBrush $headerBorder 'Background' $guiConfig.HeaderBackColor
        & $applyBrush $footerBorder 'Background' $guiConfig.FooterBackColor
        & $applyBrush $labelAppName 'Foreground' $guiConfig.AppNameFontColor
        & $applyBrush $footerInfo 'Foreground' $guiConfig.FooterFontColor
        & $applyBrush $statusLabel 'Foreground' $guiConfig.FooterFontColor

        if ($guiConfig.AppFont) { $script:window.FontFamily = New-Object System.Windows.Media.FontFamily ($guiConfig.AppFont) }
        $appNameFontSize = 0
        if ([double]::TryParse("$($guiConfig.AppNameFontSize)", [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$appNameFontSize) -and $appNameFontSize -gt 0) {
            $labelAppName.FontSize = $appNameFontSize
        }

        $labelAppName.Text = $guiConfig.AppName
        $labelInfo.Text = Format-InfoText -Text $guiConfig.AppInfoText
        $script:window.Title = "$($guiConfig.AppName) $($generalConfig.ScriptVersion) - AD Group Manager"
        $footerInfo.Text = "v$($generalConfig.ScriptVersion) | $env:USERDOMAIN\$env:USERNAME"

        $websiteUri = $null
        if ([System.Uri]::TryCreate($generalConfig.WebsiteURL, [System.UriKind]::Absolute, [ref]$websiteUri) -and $websiteUri.Scheme -in @('http', 'https')) {
            $hyperlinkWebsite.NavigateUri = $websiteUri
            $hyperlinkWebsiteText.Text = if ($generalConfig.WebsiteURLText) { $generalConfig.WebsiteURLText } else { $websiteUri.Host }
        }
        Write-DebugMessage "GUI-Konfiguration angewendet: $($labelInfo.Text)"

        # Standardwerte setzen
        Set-FormDefault

        # Lade verfügbare Vorlagen
        Update-TemplateList

        # Event Handler hinzufügen
        Add-ButtonEventHandler

        # Daten aus AD laden
        Write-DebugMessage "Starte AD-Datenabfrage"
        Initialize-ADConnection
        Get-ADData

        Write-LogMessage "Anwendung gestartet und bereit" -logLevel "INFO"

        # GUI anzeigen
        [void]$script:window.ShowDialog()

    } catch {
        Write-LogMessage "Fehler beim Initialisieren der Anwendung: $($_.Exception.Message)" -logLevel "ERROR"
        [System.Windows.MessageBox]::Show("Fehler beim Initialisieren der Anwendung: $($_.Exception.Message)", "Fehler") | Out-Null
        exit 1
    }
}

# [15.0 | START]
try {
    Write-LogMessage "easyADGroups v$($generalConfig.ScriptVersion) wird gestartet..." -logLevel "INFO"
    Write-Host "easyADGroups v$($generalConfig.ScriptVersion) - Modern AD Group Management" -ForegroundColor Green
    Write-Host "Build: $($generalConfig.LastUpdate)" -ForegroundColor Gray

    Initialize-MainApplication
}
catch {
    Write-Error "Application startup failed: $($_.Exception.Message)"
    exit 1
}
