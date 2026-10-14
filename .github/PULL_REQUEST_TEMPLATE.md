## Beschreibung

<!-- Was wird geändert und warum? Verweis auf Issue (z. B. "Fixes #123"). -->

## Art der Änderung

- [ ] Fehlerbehebung
- [ ] Neue Funktion
- [ ] Sicherheit
- [ ] Performance
- [ ] Dokumentation

## Checkliste

- [ ] `Invoke-ScriptAnalyzer -Path .\src\easyADGroup.ps1` ohne neue Warnungen
- [ ] Mit **Test Run** und in einer AD-Testumgebung geprüft
- [ ] Windows PowerShell 5.1 und PowerShell 7+ berücksichtigt, Datei als UTF-8 mit BOM gespeichert
- [ ] [CHANGELOG.md](../CHANGELOG.md) mit Versionsnummer und Datum ergänzt (kein Abschnitt "Unreleased")
- [ ] Version in README, `$generalConfig.ScriptVersion` und Script-Header angepasst (Dateiname bleibt ohne Version)
- [ ] README / `src/easyADGroups.ini.example` aktualisiert (falls Konfiguration betroffen)
- [ ] Keine internen Daten (Domänen, Server, IP-Adressen, Benutzernamen, Passwörter) enthalten
