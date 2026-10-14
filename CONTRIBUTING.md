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
- **Lint:** Vor dem PR `Invoke-ScriptAnalyzer -Path .\src\easyADGroup.ps1` ausführen und neue Warnungen beheben.
- **GUI:** Die GUI ist ausschließlich als XAML im Script eingebettet (`$xamlContent`); es gibt keine separate XAML-Datei.
- **Struktur:** Script und Beispielkonfiguration liegen in `src/`, Dokumentation in `docs/`, Screenshots in `docs/screenshots/` (ohne interne Daten).
- **Test:** Änderungen mit aktiviertem **Test Run** und in einer Testumgebung prüfen.
- **Dokumentation:** README, `src/easyADGroups.ini.example` und [CHANGELOG.md](CHANGELOG.md) aktualisieren. Jeder Eintrag im Changelog erhält eine Versionsnummer und ein Datum – einen Abschnitt "Unreleased" gibt es nicht.
- **Versionierung:** Der Dateiname `src/easyADGroup.ps1` enthält **keine** Versionsnummer. Bei einer neuen Version die Nummer in README (Abschnitt "Aktuelle Version"), CHANGELOG, `$generalConfig.ScriptVersion`/`LastUpdate` und im Script-Header anpassen. Alte Versionen werden nicht als Kopie archiviert, sondern sind über die Git-Historie erreichbar (optional Git-Tag `V<Version>` setzen).
- **Code-Signatur:** Die Signatur wird vom Maintainer nach dem Merge neu erstellt.

## Verhaltenskodex

Bitte beachten Sie den [Verhaltenskodex](CODE_OF_CONDUCT.md).
