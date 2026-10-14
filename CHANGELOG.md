# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionierung an [Semantic Versioning](https://semver.org/lang/de/).

## [0.3.2] - 2026-10-14

Audit-Release (Sicherheit, Performance, Funktionen, Verweise, GUI, Befehle). Details zu allen Befunden: [AUDIT.md](AUDIT.md).

### Sicherheit
- LDAP-Filter-Injection in der OU-Prüfung (`-Filter "DistinguishedName -eq '$OUPath'"`) entfernt; Duplikatprüfung nutzt LDAP-Escaping nach RFC 4515.
- E-Mail-Adressen werden mit `System.Net.Mail.MailAddress` validiert (keine Header-Injection über Zeilenumbrüche).
- Keine SMTP-Passwörter mehr in der Konfiguration; Anmeldung mit dem aktuellen Windows-Konto.
- Vorlagennamen werden auf sichere Dateinamen beschränkt; Überschreiben nur nach Bestätigung.
- Footer-Link öffnet nur `http`/`https`-URLs.
- `$PSDefaultParameterValues` wird nur im Script-Scope gesetzt (keine Veränderung der aufrufenden Sitzung).
- Log-Datei mit internen UNC-Pfaden/IP-Adressen aus dem Repository entfernt; `logs/`, `templates/`, `*.log` und die lokale `easyADGroups.ini` werden per `.gitignore` ausgeschlossen.
- Beispielkonfiguration warnt vor festen Mitgliedern wie "Domänen-Benutzer"; feste Mitglieder sind standardmäßig deaktiviert.

### Behoben
- Script startete unter PowerShell 7 nicht korrekt (`Get-WmiObject` existiert dort nicht); Anforderungen auf Windows PowerShell 5.1+/PowerShell 7+ vereinheitlicht und STA-Prüfung ergänzt.
- Undefinierte Variable `$iniPath`; die in der README beschriebene `easyADGroups.ini` wird jetzt tatsächlich geladen.
- Checkbox "Names" (Namensvalidierung) und "Auto-Naming" hatten keine Funktion; `NamingTemplate` wird jetzt angewendet.
- `ADServer`, `LogActive`, `LogLevel`, `DefaultGroupType`, `DefaultGroupScope`, `DefaultDryRun`, `AutoCreateOUEnabled` und die GUI-Farben aus der Konfiguration wurden ignoriert.
- Nummernbereich: Off-by-one bei `MaxGroupsPerBatch`, negative Zahlen, Absturz bei ungültigen Zahlen in der Duplikatprüfung.
- Gekürzte sAMAccountNames (20 Zeichen) konnten innerhalb eines Vorgangs kollidieren und wurden still übersprungen – Kollisionen werden jetzt vorab erkannt und in der Vorschau angezeigt.
- Duplikatprüfung verglich den vollständigen Namen statt des (gekürzten) sAMAccountName.
- Zähler/Fortschritt waren bei übersprungenen Gruppen falsch; Ergebnis zeigt jetzt erstellt/übersprungen/Fehler.
- Testlauf-Gruppen erschienen im Bericht als "erstellt" – jetzt mit `[TESTLAUF]` gekennzeichnet.
- CSV-Import: keine Validierung, Fehler beim Hinzufügen von Mitgliedern wurden verschluckt, Testlauf protokollierte "erstellt", leere Zeilen verfälschten den Fortschritt.
- OUs mit dem Namen "Users" oder "Computers" wurden fälschlich ausgeblendet; gleichnamige OUs waren nicht unterscheidbar (jetzt Pfadanzeige).
- OU-Auto-Erstellung zerlegte DNs mit maskierten Kommas falsch und legte keine fehlenden übergeordneten OUs an.
- Benutzerauswahl ging beim Filtern verloren.
- E-Mail-"Versand" war nur eine Simulation mit irreführender Meldung "E-Mail gesendet"; SMTP-Versand ist jetzt umsetzbar, Simulation ist klar gekennzeichnet.
- Footer-Hyperlink und HELP-Schaltfläche hatten keine Funktion.
- Tippfehler "Seperator" in der GUI.
- Ungültige Code-Signatur entfernt (die Signatur passte nach Änderungen nicht mehr zum Inhalt).

### Geändert
- Script umbenannt in `easyADGroup_V0.3.2.ps1`; Header enthält nur noch tatsächlich vorhandene Funktionen (keine Angaben zu REST-API, Azure-AD-Sync, PowerBI usw.).
- Funktionen auf genehmigte PowerShell-Verben umbenannt (z. B. `Create-OUIfNotExists` → `Initialize-OrganizationalUnit`, `Generate-Report` → `New-GroupReport`, `Load-Template` → `Import-GroupTemplate`, `Write-Log` → `Write-LogEntry`).
- Vorlagen werden über eine Auswahlliste statt über ein Texteingabefeld geladen.
- Linke Konfigurationsspalte ist scrollbar, Mindestgröße des Fensters reduziert (1100×700).
- Standard für `MaxGroupNameLength` auf das AD-Limit von 64 Zeichen gesetzt; `InvalidCharacters` auf die in sAMAccountName unzulässigen Zeichen.
- Datei mit UTF-8-BOM gespeichert (korrekte Umlaute unter Windows PowerShell 5.1).
- `ADGroupsGUI.xaml` mit der eingebetteten GUI-Definition synchronisiert.
- README überarbeitet (korrekte Repository-/GitHub-Links, Konfigurationsreferenz, Code-Signatur-Hinweis).

### Performance
- Alle AD-Aufrufe laufen gegen einen festen Domain Controller; die 500-ms-Pause pro Gruppe entfällt (1000 Gruppen: ca. 8 Minuten weniger).
- Duplikatprüfung gebündelt (50 Namen pro LDAP-Abfrage statt einer Abfrage pro Gruppe).
- Benutzer werden serverseitig mit `-ResultSetSize` begrenzt statt alle Benutzer zu laden und clientseitig zu kürzen.
- Langsame RSAT-Prüfung über `Get-WindowsCapability -Online` beim Start entfernt (die Modulprüfung genügt).
- Ein einziger Such-Timer statt eines neuen Timers pro Tastendruck; UI-Virtualisierung der Benutzerliste; Status/Fortschritt werden während langer Vorgänge aktualisiert, Aktionsschaltflächen sind währenddessen deaktiviert.
- Doppelten Code (Benutzerabfrage, Variableninitialisierung) zusammengeführt.

### Hinzugefügt
- `easyADGroups.ini.example` mit allen unterstützten Schlüsseln.
- `CHANGELOG.md`, `AUDIT.md`, `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`.
- Hilfe-Dialog, Footer mit Version und angemeldetem Benutzer, Anzeige des sAMAccountName in der Vorschau.

## [0.3.1] - 2025-05-26

### Hinzugefügt
- Modernes Windows 11 Design
- Vorlagen-Management (JSON)
- Erweiterte Benutzersuche mit Live-Filter
- CSV Import/Export
- Erweiterte Validierung und Duplikat-Prüfung
- E-Mail-Benachrichtigungen (Simulation)
- Berichtswesen
- Testlauf-Modus und OU Auto-Erstellung

## [0.2.8]

### Hinzugefügt
- Basis-Funktionalität für die AD-Gruppenerstellung
- Einfache WPF-GUI
- JIRA/Confluence Spezial-Modus
- Grundlegende Validierung

## [0.1.17]

### Hinzugefügt
- Archivierte Version (siehe `# Versions/easyADGroup_V0.1.17.ps1`)

[0.3.2]: https://github.com/PS-PhinIT/PhinIT.PowerShell_ADGroups/blob/main/easyADGroup_V0.3.2.ps1
[0.3.1]: https://github.com/PS-PhinIT/PhinIT.PowerShell_ADGroups/blob/main/%23%20Versions/easyADGroup_V0.3.1.ps1
[0.2.8]: https://github.com/PS-PhinIT/PhinIT.PowerShell_ADGroups/blob/main/%23%20Versions/easyADGroup_V0.2.8.ps1
[0.1.17]: https://github.com/PS-PhinIT/PhinIT.PowerShell_ADGroups/blob/main/%23%20Versions/easyADGroup_V0.1.17.ps1
