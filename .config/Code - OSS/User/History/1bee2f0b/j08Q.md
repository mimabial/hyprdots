# Hallo! 👋 Delphin hier

[![en](https://img.shields.io/badge/lang-en-red.svg)](../../Hyprdots-to-DENv.md)
[![中文](https://img.shields.io/badge/lang-中文-orange.svg)](./Hyprdots-to-DENv.zh.md)
[![es](https://img.shields.io/badge/lang-es-yellow.svg)](./Hyprdots-to-DENv.es.md)

## Dieser Fork wird prasanthrangan/hyprdots im Laufe der Zeit verbessern und korrigieren

### Warum?

- Tittu (der ursprüngliche Schöpfer) ist im Moment AFK, und ich bin der einzige verbliebene Mitarbeiter. ⁉️
- Meine Rechte sind begrenzt, so dass ich nur PRs zusammenführen kann. Wenn etwas kaputt geht, muss ich auf Hilfe warten. 😭
- Ich werde aus Respekt nicht alles in seinen Dotfiles ändern.
- Dieses Repo wird die Dotfiles von $USER nicht **überschreiben**.

**Dieser Fork ist temporär und überbrückt die alte Struktur mit einer neueren [die bald kommt...].**

### Wer sind die $USER?

> **HINWEIS**: Wenn Sie verwirrt sind, warum jedes `install.sh -r` Ihre Konfigurationen überschreibt, sollten Sie [DENv](https://github.com/DENv-Project/DENv) forken, die Datei `*.lst` bearbeiten und das Skript ausführen. Das ist der beabsichtigte Weg.
> Wer sind die $USER?
> ✅ Ich möchte keinen Fork pflegen
> ✅ Sie wollen mit diesem großartigen Dotfile auf dem Laufenden bleiben
> ✅ Ich weiß nicht, wie das Repo funktioniert
> ✅ Keine Zeit haben, eigene Dotfiles zu erstellen, sondern diese als Inspiration nutzen
> ✅ Sie wollen eine saubere `~/.config`, in der alles wie in einem echten Linux-Paket strukturiert ist
> ✅ Erfordert eine DE-ähnliche Erfahrung

### ROADMAP 🛣️📍

- [ ] **Portabel**

  - [ ] DENv-spezifische Dateien sollten in $USER importiert werden, nicht andersherum
  - [x] Es minimal halten
  - [ ] Mach es paketierbar
  - [x] XDG-Spezifikationen befolgen
  - [ ] Makefile hinzufügen

- [ ] **Erweiterbar**

  - [ ] DENv-Erweiterungssystem hinzufügen
  - [ ] Vorhersagbare Installation

- [ ] **Leistung**

  - [ ] Skripte für Geschwindigkeit und Effizienz optimieren
  - Ein einziges CLI, um alle Kernskripte zu verwalten

- [ ] **Verwaltbar**

  - [ ] Skripte korrigieren (shellcheck-kompatibel)
  - [x] Skripte nach `./lib/denv` verschieben
  - [x] Skripte `wallbash*.sh` monolithisch machen, um wallbash-Probleme zu beheben

- [ ] **Bessere Abstraktion**

  - [ ] Waybar
  - [x] Hyprlock
  - [x] Animationen
  - [ ] ...

- [ ] Aufräumen
- [ ] **...**

---

So können wir DENv-spezifische Hyprland-Einstellungen aktualisieren, ohne die Benutzereinstellungen zu ändern. Wir brauchen die „userprefs“-Datei nicht. Stattdessen können wir DENvs `hyprland.conf` auslesen und $USER bevorzugte Änderungen direkt in der Konfiguration vornehmen. Mit diesem Ansatz wird DENv nicht kaputt gehen und DENv wird Ihre eigenen Punkte nicht kaputt machen.
![Hyprland-Struktur](https://github.com/user-attachments/assets/91b35c2e-0003-458f-ab58-18fc29541268)

# Warum der Name DENv?

Als letzter Mitwirkender weiß ich nicht, was der ursprüngliche Schöpfer beabsichtigte. Aber ich denke, es ist ein guter Name. Ich weiß nur nicht, wofür er steht. 🤷‍♂️
Hier sind einige meiner Spekulationen:

- **Hy**prdots **D**otfiles **E**nhanced - Verbesserte Version von hyprdots, als @prasanthrangan wallbash als unsere Haupt-Engine für die Themenverwaltung einführte.
- **Hy**prland **D**otfiles **E**xtended - Erweiterbare Dotfiles für Hyprland.
- Aber am meisten Sinn macht - **Hy**prland **D**esktop **E**nvironment - da Hyprland normalerweise als WM für Wayland betrachtet wird, nicht als vollwertiges D.E. und diese
  Dotfile macht es irgendwie zu einem vollwertigen D.E.

Du kannst gerne deine eigene Bedeutung von DENv vorschlagen. 🤔
