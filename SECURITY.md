# Sicherheitsrichtlinie (Security Policy)

## Unterstützte Versionen

| Version | Unterstützt |
|---------|-------------|
| 0.3.2   | ✅ |
| < 0.3.2 | ❌ (Archiv im Ordner `# Versions`) |

## Sicherheitslücken melden

Bitte melden Sie Sicherheitslücken **nicht** über öffentliche Issues.

1. Nutzen Sie die private Meldung über GitHub: **Security → Report a vulnerability** im Repository
   ([direkter Link](https://github.com/PS-PhinIT/PhinIT.PowerShell_ADGroups/security/advisories/new)).
2. Alternativ Kontakt über [https://phinit.de](https://phinit.de).

Bitte geben Sie an: betroffene Version, Schritte zur Reproduktion, erwartetes und tatsächliches Verhalten sowie mögliche Auswirkungen. Entfernen Sie dabei interne Daten (Domänennamen, Server, IP-Adressen, Benutzernamen) aus Logs und Screenshots.

## Hinweise für den sicheren Betrieb

- **Least Privilege:** Das Script benötigt lokale Administratorrechte; im AD sollte das ausführende Konto nur die delegierten Rechte zum Erstellen von Gruppen (und ggf. OUs) in den benötigten OUs besitzen – kein Domain Admin.
- **Testlauf zuerst:** Neue Vorlagen, CSV-Dateien und Namens-Templates zuerst mit **Test Run** prüfen.
- **Feste Mitglieder:** `GroupMembersAdd` nur mit gezielt ausgewählten Konten/Gruppen verwenden. Breite Gruppen wie "Domänen-Benutzer" geben allen Benutzern die Berechtigungen der neuen Gruppe.
- **Keine Geheimnisse in der Konfiguration:** Die INI-Datei enthält keine Passwörter; der SMTP-Versand nutzt das aktuelle Windows-Konto. Für TLS `SMTPUseSsl=1` setzen.
- **Logs und Vorlagen:** Die Ordner `logs` und `templates` sowie die lokale `easyADGroups.ini` können interne Informationen enthalten und werden per `.gitignore` nicht versioniert. Zugriff auf das Script-Verzeichnis entsprechend einschränken.
- **Code-Signatur:** Das Script wird unsigniert ausgeliefert. In Umgebungen mit `AllSigned` das Script nach Prüfung mit einem eigenen Code-Signing-Zertifikat signieren (`Set-AuthenticodeSignature`). Nach jeder Änderung muss neu signiert werden.
