# easyADgroup - Modern AD Group Manager

**Aktuelle Version: 0.3.3** (2026-10-14)

Ein PowerShell-Tool mit Windows 11-inspirierter WPF-GUI für die einfache Erstellung von Active Directory-Gruppen.

> Änderungen pro Version: siehe [CHANGELOG.md](CHANGELOG.md) · Sicherheitsrichtlinie: [SECURITY.md](SECURITY.md) · Audit-Bericht: [docs/AUDIT.md](docs/AUDIT.md)

## 🚀 Funktionen

### 🎨 Modernes Windows 11 Design
- **Fluent Design**: Abgerundete Ecken, moderne Farben (#0078D4, #F3F3F3)
- **Responsive Layout**: Anpassbare Fenstergröße, scrollbare Konfigurationsspalte
- **OU-Pfadanzeige**: OUs werden mit vollständigem Pfad angezeigt (gleichnamige OUs sind unterscheidbar)
- **Hilfe-Button**: Kurzanleitung direkt in der Anwendung

### 📋 Vorlagen-Management
- **Konfigurationen speichern**: Häufig verwendete Einstellungen als Vorlagen (JSON) speichern
- **Schnelles Laden**: Auswahl gespeicherter Vorlagen aus einer Liste
- **Automatische Verwaltung**: Vorlagen-Verzeichnis `templates` wird automatisch erstellt

### 🔍 Benutzersuche
- **Live-Suche**: Verzögerte Echtzeit-Filterung der Benutzerliste (konfigurierbar, Standard 500 ms)
- **AD-Suche**: Ist die Liste durch `MaxUsersToLoad` gekürzt, wird direkt im AD gesucht – auch nicht geladene Benutzer werden gefunden
- **Platzhalter**: `*` und `?` werden unterstützt
- **Mehrfachauswahl**: Strg/Umschalt+Klick, Alle/Keine – die Auswahl bleibt beim Filtern erhalten
- **Aktualisierung**: Manuelle Aktualisierung der Benutzerliste

### 📊 CSV Import/Export
- **Vorlagen-Download**: CSV-Vorlage mit Beispieldaten
- **Bulk-Import**: Massenimport von Gruppen via CSV-Datei
- **Validierung**: Dateigröße, Zeilenanzahl, Gruppenname, Typ, Bereich, OU und sAMAccountName-Kollisionen
- **Vorschau**: Anzeige der zu importierenden Gruppen vor der Erstellung

### ✅ Validierung
- **Duplikat-Prüfung**: Gebündelte LDAP-Abfrage auf bereits vorhandene sAMAccountNames
- **Namens-Validierung**: Ungültige Zeichen, maximale Länge (AD-Limit 64 Zeichen)
- **sAMAccountName-Kollisionen**: Erkennung gleicher Namen nach dem Kürzen
- **OU-Existenz**: Überprüfung der Ziel-OU vor der Gruppenerstellung
- **Batch-Limits**: Schutz vor zu großen Vorgängen (Standard max. 1000)

### 🔧 Erweiterte Optionen
- **Testlauf-Modus**: Simulation ohne tatsächliche Änderungen
- **OU Auto-Erstellung**: Automatische Erstellung fehlender OUs (inkl. übergeordneter OUs)
- **Auto-Naming**: Konfigurierbares Namens-Template (z. B. `GRP_{NAME}_{SUFFIX}`)
- **Fortschrittsanzeige**: Fortschrittsbalken und Statuszeile während der Erstellung

### 📧 E-Mail-Benachrichtigungen
- **Benachrichtigung**: E-Mail nach der Gruppenerstellung
- **Test-Funktion**: E-Mail-Konfiguration testen
- **SMTP**: Versand über den in der INI konfigurierten SMTP-Server (ohne SMTPServer: Simulation, es wird nichts versendet)

### 📈 Berichtswesen
- **Berichte**: Übersicht der in der Sitzung erstellten Gruppen (Testlauf-Einträge sind gekennzeichnet)
- **Export**: Berichte als Textdatei speichern, automatisches Öffnen in Notepad
- **Logging**: Log-Dateien im Unterordner `logs` mit konfigurierbarem Log-Level und automatischer Bereinigung (`LogRetentionDays`)

## 📋 Systemanforderungen

- **Windows 10/11** oder **Windows Server 2016+**
- **Windows PowerShell 5.1** oder **PowerShell 7+** (Windows, STA-Modus)
- **Active Directory PowerShell-Modul** (RSAT bei Windows Client)
- **AD-Berechtigungen** zum Erstellen von Gruppen (und ggf. OUs) in den Ziel-OUs – lokale Administratorrechte sind nicht erforderlich
- Schreibrechte im Script-Verzeichnis für `logs` und `templates` (sonst Logging nur in der Konsole)

## 🛠️ Installation

1. **Repository klonen oder herunterladen**
```powershell
git clone https://github.com/PS-PhinIT/PhinIT.PowerShell_ADGroups.git
```

2. **Abhängigkeiten installieren**
```powershell
# RSAT AD-Tools installieren (Windows 10/11)
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Active Directory Modul importieren
Import-Module ActiveDirectory
```

3. **Konfiguration anpassen (optional)**
- `src\easyADGroups.ini.example` nach `src\easyADGroups.ini` kopieren und nach Bedarf bearbeiten
- Ohne INI-Datei werden die im Script eingebetteten Standardwerte verwendet

4. **Script ausführen**
```powershell
cd .\PhinIT.PowerShell_ADGroups\src
.\easyADGroup.ps1
```

> **Hinweis Dateiname:** Der Dateiname enthält keine Versionsnummer. Die Version steht in dieser README, im [CHANGELOG](CHANGELOG.md), im Fenstertitel und im Footer der Anwendung.

> **Hinweis Code-Signatur:** Das Script ist nicht signiert. Wenn Ihre Execution Policy signierte Scripts verlangt (`AllSigned`, bzw. `RemoteSigned` bei heruntergeladenen Dateien), das Script vor der Verwendung mit `Set-AuthenticodeSignature` neu signieren.

## ⚙️ Konfiguration

Die Konfiguration erfolgt über die optionale Datei `easyADGroups.ini` im Script-Verzeichnis (`src/`). Alle Schlüssel sind optional; eine vollständige, kommentierte Vorlage ist [`src/easyADGroups.ini.example`](src/easyADGroups.ini.example).

| Abschnitt | Schlüssel | Beschreibung |
|-----------|-----------|--------------|
| `[General]` | `WebsiteURL`, `WebsiteURLText`, `Debug` | Footer-Link, Debug-Modus (0/1) |
| `[LOGGING]` | `LogFileName`, `LogActive`, `LogLevel`, `LogRetentionDays` | Log-Datei, ein/aus, Mindest-Level (DEBUG/INFO/WARNING/ERROR), Aufbewahrung in Tagen (0 = unbegrenzt) |
| `[GUI]` | `AppName`, `AppNameFontSize`, `AppNameFontColor`, `AppFont`, `HeaderBackColor`, `FooterBackColor`, `FooterFontColor`, `AppInfoText` | Darstellung |
| `[AD]` | `ADServer`, `MaxUsersToLoad`, `DefaultGroupOU` | Domain Controller (leer = automatisch), max. Benutzer, Fallback-OU für CSV |
| `[ADGROUPS]` | `GroupDescription`, `AdditionalSuffixes`, `GroupMembersAddActive`, `GroupMembersAdd`, `DefaultGroupType`, `DefaultGroupScope`, `AutoNamingEnabled`, `NamingTemplate` | Gruppen-Standardwerte |
| `[VALIDATION]` | `ValidateGroupNames`, `CheckDuplicates`, `MaxGroupNameLength`, `MaxSamAccountNameLength`, `InvalidCharacters`, `MaxGroupsPerBatch` | Validierung |
| `[ADVANCED]` | `AutoCreateOUEnabled`, `DefaultDryRun`, `SearchDelayMs` | Erweiterte Optionen |
| `[EMAIL]` | `SMTPServer`, `SMTPPort`, `SMTPUseSsl`, `FromEmail`, `EmailSubjectPrefix` | E-Mail (keine Passwörter – Anmeldung mit dem Windows-Konto) |
| `[CSV]` | `CSVDelimiter`, `MaxCSVFileSizeMB` | CSV-Import/Export |

`ScriptVersion` und `LastUpdate` können nicht über die INI überschrieben werden.

## 🎯 Verwendung

### Einzelne Gruppe erstellen
1. **OU auswählen** aus der Dropdown-Liste
2. **Gruppenname** eingeben (Start/Ende leer lassen)
3. **Gruppentyp** und **Geltungsbereich** wählen
4. Optional: **Benutzer** aus der Liste auswählen
5. **Preview** anzeigen, dann **Create**

### Mehrere Gruppen (Nummernbereich)
1. **Basis-Gruppenname** eingeben
2. **Separator** definieren (z. B. "-")
3. **Start-** und **Endnummer** eingeben
4. Weitere Schritte wie bei Einzelgruppe

### JIRA/Confluence Gruppensets
1. **Basis-Gruppenname** eingeben
2. **JIRA/Confluence Mode** aktivieren
3. Suffixe werden aus `AdditionalSuffixes` geladen (Standard: RW, R, ADM)

### Auto-Naming
Bei aktivierter Checkbox **Auto-Naming** wird der Name über `NamingTemplate` gebildet (`{NAME}` = Basisname, `{SUFFIX}` = Nummer bzw. Suffix; ohne Suffix wird der Platzhalter samt Trennzeichen entfernt).

### CSV-Import
1. **Template** (CSV-Vorlage) herunterladen
2. Datei mit Gruppendaten befüllen (Spalten: `GroupName, Description, GroupType, GroupScope, OU, Members`; Mitglieder mit `;` trennen)
3. **Import** wählen, Validierung und Vorschau prüfen
4. Import bestätigen

### Vorlagen verwenden
1. **Konfiguration** nach Wunsch einstellen
2. **Save** – Vorlage unter einem Namen speichern
3. **Templates** – Vorlage aus der Liste laden

## 🔍 Sicherheit und Logging

- **Testlauf-Modus**: Simulation ohne Änderungen
- **Eingabevalidierung**: Ungültige Zeichen, Längen, Kollisionen, Duplikate
- **LDAP-Escaping**: Benutzereingaben werden in LDAP-Filtern maskiert
- **Logging**: Alle Aktionen werden im Ordner `logs` protokolliert (nicht versioniert, siehe `.gitignore`)
- Details: [SECURITY.md](SECURITY.md) und [docs/AUDIT.md](docs/AUDIT.md)

## 🚀 Mögliche Erweiterungen

1. **Azure AD / Entra ID Integration** – Hybrid-Umgebungen und Cloud-Gruppen
2. **Multi-Domain Support** – Mehrere AD-Domänen verwalten
3. **Erweiterte Berichtsfunktionen** – Export nach Excel/PDF
4. **Erweiterte GUI-Features** – Drag & Drop, Kontextmenüs, Keyboard-Shortcuts
5. **Backup/Restore** – Gruppen-Konfigurationen sichern, Rollback

## 📁 Repository-Struktur

```text
PhinIT.PowerShell_ADGroups/
├── src/
│   ├── easyADGroup.ps1            # Script (GUI/XAML eingebettet)
│   └── easyADGroups.ini.example   # Kommentierte Beispielkonfiguration
├── docs/
│   ├── AUDIT.md                   # Audit-Berichte
│   └── screenshots/               # Ablage für Screenshots
├── .github/
│   ├── ISSUE_TEMPLATE/            # Vorlagen für Bug-Reports und Feature-Wünsche
│   └── PULL_REQUEST_TEMPLATE.md   # Vorlage für Pull Requests
├── CHANGELOG.md                   # Änderungsprotokoll
├── CODE_OF_CONDUCT.md             # Verhaltenskodex
├── CONTRIBUTING.md                # Hinweise für Beiträge
├── LICENSE                        # MIT-Lizenz
├── README.md
└── SECURITY.md                    # Sicherheitsrichtlinie
```

Zur Laufzeit legt das Script neben sich die Ordner `logs/` und `templates/` an (nicht versioniert, siehe `.gitignore`). Ältere Versionen sind über die [Git-Historie](https://github.com/PS-PhinIT/PhinIT.PowerShell_ADGroups/commits/main) bzw. die Links im [CHANGELOG](CHANGELOG.md) erreichbar.

## 🤝 Beitragen

Beiträge sind willkommen! Details siehe [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.

## 👨‍💻 Autor

**Andreas Hepp**
- Website: [https://phinit.de](https://phinit.de)
- GitHub: [@PS-PhinIT](https://github.com/PS-PhinIT)

## 📞 Support

1. **GitHub Issues** für Bug-Reports und Feature-Requests
2. **Website** [https://phinit.de](https://phinit.de) für weitere Tools
3. Sicherheitslücken bitte gemäß [SECURITY.md](SECURITY.md) melden

---

**⭐ Wenn Ihnen dieses Tool gefällt, geben Sie ihm einen Stern auf GitHub!**
