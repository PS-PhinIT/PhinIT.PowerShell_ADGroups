# Beitragen zu easyADgroup

Vielen Dank für Ihr Interesse! Beiträge in Form von Bug-Reports, Feature-Vorschlägen und Pull Requests sind willkommen.

## Bugs und Feature-Wünsche

- Nutzen Sie die GitHub Issues und beschreiben Sie Version, PowerShell-Version (`$PSVersionTable`), Schritte zur Reproduktion und erwartetes Verhalten.
- Entfernen Sie interne Daten (Domänen, Server, IP-Adressen, Benutzernamen) aus Logs und Screenshots.
- Sicherheitslücken bitte **nicht** öffentlich melden, sondern gemäß [SECURITY.md](SECURITY.md).

## Pull Requests

1. Repository forken und einen Feature-Branch erstellen (`git checkout -b feature/MeinFeature`).
2. Änderungen vornehmen und committen (`git commit -m "Beschreibung der Änderung"`).
3. Branch pushen und einen Pull Request erstellen.

### Richtlinien

- **Kompatibilität:** Windows PowerShell 5.1 und PowerShell 7+ (Windows) unterstützen; keine Cmdlets verwenden, die in PowerShell 7 fehlen (z. B. `Get-WmiObject` → `Get-CimInstance`).
- **Kodierung:** Script-Dateien als UTF-8 **mit BOM** speichern (sonst fehlerhafte Umlaute unter Windows PowerShell 5.1).
- **Funktionsnamen:** Nur genehmigte Verben verwenden (`Get-Verb`).
- **Sicherheit:** Benutzereingaben in LDAP-Filtern immer maskieren (`ConvertTo-LdapFilterValue`), keine Passwörter oder internen Daten committen.
- **Lint:** Vor dem PR `Invoke-ScriptAnalyzer -Path .\easyADGroup_V0.3.2.ps1` ausführen und neue Warnungen beheben.
- **GUI:** Änderungen am eingebetteten XAML auch in `ADGroupsGUI.xaml` (Referenzkopie) übernehmen.
- **Test:** Änderungen mit aktiviertem **Test Run** und in einer Testumgebung prüfen.
- **Dokumentation:** README, `easyADGroups.ini.example` und [CHANGELOG.md](CHANGELOG.md) aktualisieren. Jeder Eintrag im Changelog erhält eine Versionsnummer und ein Datum.
- **Versionierung:** Neue Versionen erhalten eine neue Script-Datei `easyADGroup_V<Version>.ps1`; ältere Versionen werden im Ordner `# Versions` archiviert. Version auch in `$generalConfig.ScriptVersion` und im Script-Header anpassen.
- **Code-Signatur:** Die Signatur wird vom Maintainer nach dem Merge neu erstellt.

## Verhaltenskodex

Bitte beachten Sie den [Verhaltenskodex](CODE_OF_CONDUCT.md).
