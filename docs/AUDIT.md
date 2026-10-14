# Audit-Berichte easyADgroup

Schweregrade: **Hoch** = Fehlfunktion/Risiko im Normalbetrieb · **Mittel** = Fehlfunktion in Teilbereichen · **Niedrig** = Qualität/Komfort.

Inhalt:
- [Audit 2 – Version 0.3.3](#audit-2--version-033)
- [Audit 1 – Version 0.3.2](#audit-1--version-032)

---

## Audit 2 – Version 0.3.3

| | |
|---|---|
| **Geprüfte Version** | `easyADGroup_V0.3.2.ps1` (0.3.2) |
| **Ergebnis-Version** | `src/easyADGroup.ps1` (0.3.3) |
| **Datum** | 2026-10-14 |
| **Umfang** | Sicherheit, Performance, Funktionen, Verweise/Dokumentation, GUI, Befehle/Code-Qualität, Repository-Struktur |
| **Werkzeuge** | Code-Review, PSScriptAnalyzer 1.25, PowerShell-Parser, XML-Prüfung des eingebetteten XAML, Funktionstests mit gemockten AD-Cmdlets |

Alle Befunde wurden in Version 0.3.3 behoben (Status ✅). Änderungen im Detail: [CHANGELOG.md](../CHANGELOG.md).

### 1. Sicherheit

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| S10 | `#Requires -RunAsAdministrator` erzwang lokale Administratorrechte, obwohl nur AD-Rechte benötigt werden (Least Privilege). | Mittel | Anforderung entfernt; Logging fällt bei fehlenden Schreibrechten auf die Konsole zurück. | ✅ |
| S11 | Während langer Vorgänge verarbeitet `Update-UI` auch Eingaben: Schließen, Bericht, Vorlage speichern, CSV-Template, Test-E-Mail usw. konnten parallel (reentrant) ausgelöst werden. | Mittel | Alle Aktionsschaltflächen gesperrt, Schließen des Fensters während eines Vorgangs blockiert, Such-Timer wartet. | ✅ |
| S12 | Vorlagennamen wie `CON`, `NUL`, `COM1` (reservierte Gerätenamen) und unbegrenzte Länge. | Niedrig | Reservierte Namen werden mit `_` präfixiert, max. 100 Zeichen. | ✅ |

### 2. Performance

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| P9 | CSV-Import prüfte/erstellte die OU für jede Zeile erneut. | Niedrig | Jede Ziel-OU wird einmal geprüft bzw. angelegt. | ✅ |
| P10 | OU-Auswahlliste ohne UI-Virtualisierung (`StackPanel`), langsam bei vielen OUs. | Niedrig | `VirtualizingStackPanel` mit Recycling. | ✅ |
| P11 | Pro Start eine neue Log-Datei ohne Bereinigung – der Log-Ordner wuchs unbegrenzt. | Niedrig | `LogRetentionDays` (Standard 30, 0 = unbegrenzt). | ✅ |

### 3. Funktionen

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| F17 | Benutzersuche filterte nur die geladenen `MaxUsersToLoad` (Standard 500) Benutzer – in größeren Domänen waren Benutzer nicht auffindbar. | Hoch | Bei gekürzter Liste serverseitige Suche (`sAMAccountName`/`displayName`, LDAP-maskiert, Platzhalter). | ✅ |
| F18 | CSV-Import: nicht vorhandene OUs führten zu einem Fehler pro Zeile; Testlauf mit "Auto-create OU" meldete fehlende OUs nicht. | Mittel | OU-Vorprüfung, verständliche Meldung, Testlauf protokolliert anzulegende OUs. | ✅ |
| F19 | Ungültige Zahlen in der INI (`MaxGroupsPerBatch`, `MaxGroupNameLength`, `MaxCSVFileSizeMB`, `SMTPPort`) führten zu Ausnahmen bei Validierung/Import/E-Mail. | Mittel | `Get-ConfigInt` mit Standardwert. | ✅ |
| F20 | Fehlende Spalte `GroupName` bei abweichendem CSV-Trennzeichen (z. B. `;` aus Excel) ohne Hinweis auf die Ursache. | Niedrig | Meldung nennt das konfigurierte Trennzeichen. | ✅ |

### 4. Verweise und Dokumentation

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| V7 | README, CONTRIBUTING und Audit verwiesen auf die gelöschte `ADGroupsGUI.xaml`. | Mittel | Verweise entfernt; GUI ist nur im Script eingebettet. | ✅ |
| V8 | Versionsnummer im Dateinamen (`easyADGroup_V0.3.2.ps1`) – jede Version brach Links und Aufrufe. | Mittel | `src/easyADGroup.ps1`; Version in README/CHANGELOG/Script. | ✅ |
| V9 | CHANGELOG: Version "0.1.17" war tatsächlich 0.2.7 (Git-Tag `V0.2.7`), fehlende Datumsangaben, Links auf Archivdateien. | Mittel | Anhand Git-Historie und Pull Requests korrigiert, Links auf Commits/Tags/PR. | ✅ |
| V10 | Archiv `# Versions/` mit alten, fehlerhaften Scripts, alte INI-Dateien und Screenshots im Repository. | Niedrig | Entfernt (über Git-Historie erreichbar); Ordnerstruktur `src/`, `docs/`, `docs/screenshots/`, `.github/`. | ✅ |
| V11 | Keine Vorlagen für Pull Requests und Issues. | Niedrig | `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/`. | ✅ |

### 5. GUI

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| G8 | Feste Höhen der Gruppenboxen ("Group Configuration", "Advanced Options", "Quick Guide") – Inhalte wurden bei anderer Schrift (`AppFont`) oder DPI abgeschnitten. | Mittel | Automatische Höhe. | ✅ |
| G9 | Fensterhöhe 1003 px größer als der Arbeitsbereich kleiner Displays. | Niedrig | Größe wird auf den Arbeitsbereich begrenzt. | ✅ |
| G10 | Vorlagen-Speichern über WinForms-`InputBox` (Microsoft.VisualBasic) – nicht dem Hauptfenster zugeordnet, konnte dahinter verschwinden. | Niedrig | WPF-Dialog mit Owner. | ✅ |
| G11 | Kurzanleitung bezeichnete den Gruppennamen als optional. | Niedrig | Text korrigiert. | ✅ |

### 6. Befehle und Code-Qualität

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| B6 | Abhängigkeit `Microsoft.VisualBasic` nur für ein Eingabefeld. | Niedrig | Entfernt. | ✅ |
| B7 | Mehrfach `[int]`-Casts auf Konfigurationswerte ohne Prüfung. | Niedrig | Zentrale Funktion `Get-ConfigInt`. | ✅ |

PSScriptAnalyzer nach der Behebung: keine Fehler; verbleibende Hinweise wie in Audit 1 (`PSAvoidUsingWriteHost`, `PSUseShouldProcessForStateChangingFunctions` für GUI-interne Hilfsfunktionen).

### 7. Offene Punkte / Empfehlungen

- **Code-Signatur:** Script nach Review mit dem eigenen Zertifikat signieren.
- **Git-Tags:** Releases künftig taggen (z. B. `V0.3.3`), damit Changelog-Links auf feste Stände zeigen.
- **Git-Historie:** Die in Audit 1 entfernte Log-Datei (interne Pfade/IP) ist weiterhin in der Historie vorhanden; bei Bedarf bereinigen (z. B. `git filter-repo`).
- **Test in einer AD-Testumgebung:** GUI und AD-Aufrufe konnten nicht gegen ein echtes Active Directory ausgeführt werden; Logik wurde mit gemockten AD-Cmdlets geprüft.

---

## Audit 1 – Version 0.3.2

| | |
|---|---|
| **Geprüfte Version** | `easyADGroup_V0.3.1.ps1` (Header: "0.4.0", `ScriptVersion` 0.3.1) |
| **Ergebnis-Version** | `easyADGroup_V0.3.2.ps1` |
| **Datum** | 2026-10-14 |
| **Umfang** | Sicherheit, Performance, Funktionen, Verweise/Dokumentation, GUI, Befehle/Code-Qualität, Repository |
| **Werkzeuge** | Code-Review, PSScriptAnalyzer 1.25, PowerShell-Parser, Funktionstests der Logik mit gemockten AD-Cmdlets |

Alle Befunde wurden in Version 0.3.2 behoben (Status ✅). Dateinamen und Pfade entsprechen dem damaligen Stand (seit 0.3.3: `src/easyADGroup.ps1`, Archiv `# Versions` und `ADGroupsGUI.xaml` entfernt).

### 1. Sicherheit

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| S1 | `Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OUPath'"` – Filter aus ungeprüfter Eingabe (Vorlage/CSV) zusammengesetzt (Injection, Abbruch bei `'` im DN). | Mittel | Prüfung per `-Identity`; Duplikatprüfung mit LDAP-Escaping nach RFC 4515 (`ConvertTo-LdapFilterValue`). | ✅ |
| S2 | E-Mail-Adresse nur per einfacher Regex geprüft (Zeilenumbrüche möglich). | Niedrig | Validierung über `System.Net.Mail.MailAddress`, Betreff ohne Zeilenumbrüche. | ✅ |
| S3 | INI-Vorlage sah `SMTPPassword` im Klartext vor. | Mittel | Kein Passwort mehr in der Konfiguration; SMTP mit Windows-Anmeldung. | ✅ |
| S4 | Beispielkonfiguration fügte jeder neuen Gruppe "Domänen-Admins" und "Domänen-Benutzer" hinzu (alle Benutzer erhalten die Gruppenrechte). | Mittel | Feste Mitglieder standardmäßig aus, Warnhinweis in `easyADGroups.ini.example` und `SECURITY.md`. | ✅ |
| S5 | Log-Datei mit internen UNC-Pfaden und IP-Adresse im Repository (`# Versions/logs/...log`). | Mittel | Datei entfernt, `logs/`, `templates/`, `*.log`, lokale INI in `.gitignore`. Hinweis: Die Datei ist weiterhin in der Git-Historie enthalten. | ✅ |
| S6 | Vorlagenname nur teilweise bereinigt; bestehende Vorlagen wurden ohne Rückfrage überschrieben. | Niedrig | Nur `[\w\-. ]` erlaubt, Überschreiben mit Bestätigung. | ✅ |
| S7 | Code-Signatur passte nicht mehr zum Inhalt bzw. wird durch jede Änderung ungültig. | Niedrig | Ungültige Signatur entfernt, Hinweis zum Neu-Signieren in README/SECURITY. | ✅ |
| S8 | Footer-Hyperlink ohne Handler; künftige Links ohne Schemaprüfung. | Niedrig | Handler öffnet ausschließlich `http`/`https`. | ✅ |
| S9 | Fehler beim Hinzufügen von Mitgliedern im CSV-Import mit `-ErrorAction SilentlyContinue` verschluckt (fehlende Berechtigungen unbemerkt). | Mittel | Fehler werden protokolliert und im Ergebnis angezeigt. | ✅ |

### 2. Performance

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| P1 | `Start-Sleep -Milliseconds 500` pro Gruppe "für die Replikation" (1000 Gruppen ≈ 8,3 min Wartezeit). | Hoch | Alle AD-Cmdlets per `$PSDefaultParameterValues` (Script-Scope) an einen DC gebunden; Mitglieder über das zurückgegebene Gruppenobjekt. | ✅ |
| P2 | Duplikatprüfung mit einer AD-Abfrage pro Gruppe – zusätzlich nochmals in der Erstellungsschleife. | Mittel | Gebündelte LDAP-Abfragen (50 Namen pro Abfrage), einmal vor der Schleife. | ✅ |
| P3 | `Get-ADUser -Filter *` lud alle Benutzer der Domäne, sortierte clientseitig und verwarf dann alles über `MaxUsersToLoad`. | Hoch (große Domänen) | Serverseitige Begrenzung per `-ResultSetSize`. | ✅ |
| P4 | `Get-WindowsCapability -Online` beim Start (mehrere Sekunden bis Minuten) zusätzlich zur Modulprüfung. | Mittel | Entfernt; `#Requires -Modules ActiveDirectory` genügt. | ✅ |
| P5 | Pro Tastendruck wurde ein neuer `DispatcherTimer` mit neuem Event-Handler erzeugt. | Niedrig | Ein einziger Timer. | ✅ |
| P6 | ListBox-Template mit `StackPanel` als Items-Host → keine UI-Virtualisierung. | Niedrig | `ItemsPresenter` + `VirtualizingStackPanel` (Recycling). | ✅ |
| P7 | Lange Vorgänge im UI-Thread ohne Aktualisierung → Fenster "friert ein", Fortschrittsbalken wurde nie sichtbar aktualisiert. | Mittel | Dispatcher-Flush nach Status-/Fortschrittsänderungen, Buttons während der Ausführung deaktiviert (auch gegen Doppelklick). | ✅ |
| P8 | OU-Auto-Erstellung wurde für jede Gruppe erneut geprüft. | Niedrig | Einmal vor der Schleife. | ✅ |

### 3. Funktionen

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| F1 | `#Requires -Version 7.0`, aber `Get-WmiObject` (in PowerShell 7 nicht vorhanden) – README nannte PowerShell 5.1. | Hoch | Unterstützung für 5.1 und 7+, `Get-WmiObject` entfernt, STA-Prüfung für WPF. | ✅ |
| F2 | Gekürzte sAMAccountNames (20 Zeichen) kollidierten bei Nummernbereichen; Folgegruppen wurden still übersprungen. | Hoch | Kollisionen werden vor der Erstellung erkannt; Vorschau zeigt den sAMAccountName. | ✅ |
| F3 | Duplikatprüfung nutzte den vollständigen Namen statt des gekürzten sAMAccountName. | Mittel | Prüfung auf den tatsächlich verwendeten sAMAccountName (domänenweit, inkl. Benutzer/Computer). | ✅ |
| F4 | Checkbox "Names" ohne Funktion; `InvalidCharacters` und `MaxGroupNameLength` (200 > AD-Limit 64) ignoriert; generierte Namen (inkl. Separator) wurden nicht validiert. | Mittel | Validierung jedes generierten Namens, Standardwerte an AD-Limits angepasst. | ✅ |
| F5 | Checkbox "Auto-Naming" und `NamingTemplate` ohne Funktion. | Mittel | Template wird angewendet (`{NAME}`, `{SUFFIX}`). | ✅ |
| F6 | Ungültige Start-/Endnummer führte in der Duplikatprüfung zu einer unbehandelten Ausnahme. | Mittel | Weitere Prüfungen nur bei gültigen Grunddaten. | ✅ |
| F7 | Batch-Limit mit Off-by-one (`end - start` statt `end - start + 1`), negative Zahlen erlaubt. | Niedrig | Korrigiert. | ✅ |
| F8 | `continue` in der Erstellungsschleife übersprang Zähler und Fortschritt; Ergebnis "x von y" war falsch. | Mittel | Getrennte Zähler für verarbeitet/erstellt/übersprungen/Fehler. | ✅ |
| F9 | Testlauf trug Gruppen als "erstellt" in den Bericht ein; CSV-Testlauf protokollierte "CSV-Gruppe erstellt". | Mittel | Testlauf-Einträge mit `[TESTLAUF]` gekennzeichnet. | ✅ |
| F10 | CSV-Import ohne Validierung (Typ, Bereich, OU, Größe, Batch-Limit, sAMAccountName), ohne Duplikatprüfung. | Mittel | Vollständige Validierung mit Zeilennummern, Fallback-OU (`DefaultGroupOU` bzw. ausgewählte OU). | ✅ |
| F11 | OUs namens "Users"/"Computers" wurden ausgeblendet (die Standardcontainer sind keine OUs); gleichnamige OUs nicht unterscheidbar. | Mittel | Nur "Domain Controllers" ausgeblendet, Anzeige des kanonischen Pfads. | ✅ |
| F12 | OU-Auto-Erstellung: falsche DN-Zerlegung bei maskierten Kommas, keine fehlenden Eltern-OUs. | Niedrig | DN-Zerlegung an nicht maskierten Kommas, rekursive Erstellung. | ✅ |
| F13 | Benutzerauswahl ging beim Filtern der Liste verloren. | Mittel | Auswahl wird unabhängig vom Filter geführt. | ✅ |
| F14 | E-Mail war nur eine Simulation mit der Meldung "E-Mail gesendet"; SMTP-Einstellungen wurden nicht verwendet. | Mittel | SMTP-Versand bei konfiguriertem `SMTPServer`, sonst klar gekennzeichnete Simulation. | ✅ |
| F15 | Konfigurationswerte ohne Wirkung: `ADServer`, `LogActive`, `LogLevel`, `DefaultGroupType/Scope`, `DefaultDryRun`, `AutoCreateOUEnabled`, GUI-Farben/Schrift. | Mittel | Alle unterstützten Werte werden angewendet; nicht genutzte Schlüssel entfernt. | ✅ |
| F16 | Platzhalterersetzung im Info-Text per Regex (Sonderzeichen wie `$1` in Werten wurden interpretiert). | Niedrig | Literale Ersetzung. | ✅ |

### 4. Verweise und Dokumentation

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| V1 | README verweist auf `easyADGroups.ini`, das Script lud keine INI; Variable `$iniPath` undefiniert. | Hoch | INI-Unterstützung implementiert, `easyADGroups.ini.example` ergänzt. | ✅ |
| V2 | Clone-URL `https://github.com/PS-easyIT/easyADGroups.git` und GitHub-Profil `@PS-easyIT` nicht erreichbar (404). | Mittel | Auf `PS-PhinIT/PhinIT.PowerShell_ADGroups` korrigiert. | ✅ |
| V3 | Script-Header beschrieb nicht vorhandene Funktionen (REST-API, RBAC, Azure-AD-Sync, PowerBI, Dark Theme, Multi-Domain, .NET 6) und Version 0.4.0; ungenutzte `$script:Config`-Struktur. | Mittel | Header auf tatsächlichen Funktionsumfang und 0.3.2 korrigiert, tote Struktur entfernt. | ✅ |
| V4 | Kein `CHANGELOG.md`, keine `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`. | Mittel | Ergänzt; Changelog ohne "Unreleased"-Abschnitt, jede Version mit Nummer. | ✅ |
| V5 | `ADGroupsGUI.xaml` wird vom Script nicht geladen und wich von der eingebetteten GUI ab. | Niedrig | Synchronisiert und in der README als Referenzkopie gekennzeichnet. | ✅ |
| V6 | Uneinheitliche Website-Angaben (`www.PSscripts.de`, GitHub-Link, `phinit.de`). | Niedrig | Einheitlich `phinit.de`, konfigurierbar. | ✅ |

### 5. GUI

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| G1 | "HELP"-Element war nur eine Grafik ohne Funktion. | Niedrig | Schaltfläche mit Kurzanleitung. | ✅ |
| G2 | Footer-Hyperlink ohne `RequestNavigate`-Handler (Klick ohne Wirkung); `footerInfo` blieb leer. | Niedrig | Handler ergänzt, Footer zeigt Version und Benutzer. | ✅ |
| G3 | Fensterhöhe 1003 px / Mindesthöhe 800 px ohne Scrollen – auf kleineren Displays abgeschnitten. | Mittel | Scrollbare linke Spalte, Mindestgröße 1100×700, Textumbruch in der Kurzanleitung. | ✅ |
| G4 | ComboBox-Template ohne Dropdown-Pfeil. | Niedrig | Pfeil ergänzt. | ✅ |
| G5 | Vorlagen laden über ein Texteingabefeld (Name musste abgetippt werden). | Niedrig | Auswahlliste (Doppelklick/OK). | ✅ |
| G6 | Tippfehler "Seperator". | Niedrig | "Separator". | ✅ |
| G7 | Große Vorschau-/Ergebnislisten sprengten die MessageBox. | Niedrig | Auf 30 bzw. 20 Einträge begrenzt mit Hinweis auf weitere. | ✅ |

### 6. Befehle und Code-Qualität

| # | Befund | Schwere | Behebung | Status |
|---|--------|---------|----------|--------|
| B1 | Nicht genehmigte Verben (`Create-`, `Load-`, `Generate-`, `Replace-`, `Refresh-`, `Deselect-`) und Plural-Nomen. | Niedrig | Umbenannt (z. B. `Initialize-OrganizationalUnit`, `New-GroupReport`, `Import-GroupTemplate`, `Update-UserList`, `Clear-UserSelection`). | ✅ |
| B2 | `Write-Log` überschreibt ein in PowerShell 7 vorhandenes Cmdlet. | Niedrig | `Write-LogEntry`. | ✅ |
| B3 | UTF-8 ohne BOM bei Umlauten → fehlerhafte Zeichen unter Windows PowerShell 5.1. | Mittel | UTF-8 mit BOM. | ✅ |
| B4 | Leere `catch`-Blöcke, doppelte Initialisierungen, doppelter Benutzerabfrage-Code, verwaiste `#endregion`, unnötige Assembly `System.Windows.Forms`. | Niedrig | Bereinigt. | ✅ |
| B5 | `exit` ohne Exit-Code bei Fehlern. | Niedrig | `exit 1`. | ✅ |

PSScriptAnalyzer nach der Behebung: keine Fehler; verbleibende Hinweise sind `PSAvoidUsingWriteHost` (gewollte Konsolenausgabe) und `PSUseShouldProcessForStateChangingFunctions` für GUI-interne Hilfsfunktionen (`Set-`/`Update-`/`Reset-` auf Formular-Elementen, keine Systemänderung).

### 7. Offene Punkte / Empfehlungen

- **Code-Signatur:** Script nach Review mit dem eigenen Zertifikat neu signieren.
- **Git-Historie:** Die entfernte Log-Datei (interne Pfade/IP) ist in der Historie weiterhin vorhanden. Bei Bedarf Historie bereinigen (z. B. `git filter-repo`).
- **Archiv `# Versions`:** Ältere Versionen wurden nicht geändert und enthalten die oben genannten Befunde; nicht produktiv verwenden. *(Erledigt in 0.3.3: Archiv entfernt.)*
- **Test in einer AD-Testumgebung:** Die GUI und AD-Aufrufe konnten im Audit nicht gegen ein echtes Active Directory ausgeführt werden; die Logik wurde mit gemockten AD-Cmdlets geprüft. Vor dem produktiven Einsatz einen Testlauf und eine Erstellung in einer Test-OU durchführen.
