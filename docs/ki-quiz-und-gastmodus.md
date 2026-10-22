# KI-Quiz, Gastmodus und neue Startseite

Konzept und Umsetzungsplan. Stand: 21.10.2026, noch nichts umgesetzt.

## Ziel

Jemand landet auf der Startseite, versteht in Sekunden den Unterschied zu Kahoot,
klickt auf «Quiz erstellen» und hat – ohne Konto, mit der KI, die er oder sie
ohnehin nutzt (auch Gratis-ChatGPT/-Claude) – wenige Minuten später ein
spielbares Quiz. Wer es behalten will, registriert sich.

## Entscheidungen

| Thema | Entscheid |
|---|---|
| Weg zur KI | Kopieren/Einfügen. Die App schickt nichts an KI-Anbieter, die KI ruft die App nicht auf (Gratis-Versionen können keine Daten an fremde URLs senden). Kein Token im Prompt. |
| Format | Strukturierter Text (siehe unten), kein JSON. Die lesbare Fassung im Chat ist zugleich die Fassung zum Einfügen. |
| Sprache Format | Stichwörter nur Deutsch (v1). Inhalte der Fragen in beliebiger Sprache. |
| Themenwahl | Nicht in der App. Der Prompt weist die KI an, Thema, Zielgruppe, Anzahl usw. im Chat zu erfragen. |
| Registrierung | Offen für alle, vorerst ohne E-Mail-Bestätigung. |
| Gastmodus | Ja. Max. 3 Quizzes pro Gast, einfaches Rate-Limit, per Umgebungsvariable abschaltbar. |
| Ablauf Gast | 7 Tage ab Erstellung des Gastkontos. Danach werden Konto, Quizzes, Teilnahmen **und alle Medien in R2** gelöscht. Wird offen kommuniziert und ist der Grund zu registrieren. |
| Bilder | KI beschreibt, welches Bild es bräuchte. Die App zeigt einen Platzhalter und «N Bilder fehlen noch». |
| Pin on Image | Erlaubt. KI beschreibt Bild und Ort der Stecknadel; Frage bleibt unfertig, bis Bild + Stecknadel gesetzt sind. |
| Unfertige Fragen beim Start | Nachfragen («2 Fragen sind noch nicht fertig – ohne diese starten?»), dann im Run überspringen. |
| Slogan | **Denken statt Daumen.** Wie Kahoot, aber gebaut fürs Nachdenken: Schnellere Antworten bringen nicht mehr Punkte. |

## Ablauf für Nutzer:innen

1. **Startseite** → «Quiz erstellen» (ohne Konto) oder «Mitmachen» (PIN-Feld).
2. **Prompt holen**: Buttons «In ChatGPT öffnen», «In Claude öffnen» (Prompt
   per URL vorausgefüllt, öffnet im neuen Tab) und «Prompt kopieren» (jede
   andere KI). Kleine Illustration «Prompt → KI → Antwort kopieren → hier
   einfügen». Das Einfügefeld ist auf derselben Seite schon sichtbar.
3. **Mit der KI arbeiten**: Die KI fragt nach Thema, Zielgruppe, Anzahl,
   Sprache, Fragetypen, schlägt vor, nimmt Änderungen entgegen und gibt am
   Schluss das komplette Quiz in einem Codeblock aus.
4. **Einfügen**: Live-Vorschau mit verständlichen Hinweisen. Bei Fehlern
   «Fehlermeldung für die KI kopieren».
5. **Als Entwurf anlegen** → normaler Fragen-Editor. Erst jetzt wird (falls
   nötig) das Gastkonto angelegt.
6. **Quiz-Übersicht**: «Quiz starten», «Bilder ergänzen (3 fehlen)»,
   Banner «Dein Quiz wird am 28.10. gelöscht – Konto erstellen und behalten».
7. **Nach dem Spiel** (Rangliste): «Hat's gefallen? Speichere dein Quiz.»

Registrierte Nutzer:innen bekommen denselben Assistenten unter `/games`
(«Neues Quiz mit KI»), ohne Ablaufdatum.

## Textformat v1

Regeln:

- Zeilenbasiert, `Stichwort: Wert`. Gross-/Kleinschreibung egal.
- `Frage:` beginnt eine neue Frage. Alles davor gehört zum Quiz-Kopf.
- Antwortzeilen beginnen mit `- `; `- [x] ` markiert richtige Antworten.
- Reihenfolge: nummerierte Zeilen in der **richtigen** Reihenfolge.
- Zuordnung: `- links = rechts`.
- Eine Zeile ohne erkanntes Stichwort setzt das vorherige Textfeld fort
  (mehrzeilige Beschreibung/Erklärung).
- Toleriert: Text vor/nach dem Codeblock, Codeblock-Zäune, Leerzeilen,
  Markdown-Fettdruck (`**Frage:**`), Nummerierung vor `Frage:` (`3. Frage:`),
  naheliegende Synonyme (`Single Choice`, `Lösungen:`).
- Ein Fehler betrifft nur die eine Frage; der Rest wird trotzdem importiert
  (im Entwurfsmodus ist eine unvollständige Frage erlaubt).

```
Quiz: Pilze der Schweiz
Einleitung: Testet euer Wissen über Pilze!
Abschluss: Danke fürs Mitspielen!

Frage: Welcher Pilz ist tödlich giftig?
Typ: Single-Choice
Bild: Foto eines Grünen Knollenblätterpilzes im Wald
- Steinpilz
- [x] Grüner Knollenblätterpilz
- Eierschwamm
Erklärung: Er verursacht die meisten tödlichen Pilzvergiftungen.

Frage: Welche dieser Pilze sind essbar?
Typ: Multiple-Choice
- [x] Steinpilz
- [x] Eierschwamm
- Fliegenpilz

Frage: Wie heisst der Pilz mit dem roten Hut und weissen Punkten?
Typ: Texteingabe
Lösung: Fliegenpilz
Lösung: Amanita muscaria

Frage: Ordne vom kleinsten zum grössten Fruchtkörper.
Typ: Reihenfolge
1. Schwefelkopf
2. Steinpilz
3. Riesenbovist

Frage: Ordne die Pilze ihrem Lebensraum zu.
Typ: Zuordnung
- Steinpilz = Fichtenwald
- Schopftintling = Wiese
- Austernseitling = Totholz

Frage: Wie viele Pilzarten gibt es in der Schweiz ungefähr?
Typ: Zahlenschätzung
Bereich: 1000 bis 10000
Lösung: 5000
Toleranz: 1000

Frage: Wo liegt der Nationalpark?
Typ: Pin auf Bild
Bild: Umrisskarte der Schweiz
Pin: im Unterengadin, Kanton Graubünden
```

Abbildung auf das Datenmodell:

| Text | Feld |
|---|---|
| `Quiz:` / `Einleitung:` / `Abschluss:` | `games.title` / `intro_text` / `outro_text` |
| `Frage:` | `questions.prompt` |
| `Typ:` | `questions.type` (Namen wie im Fragen-Editor: Single-Choice, Multiple-Choice, Texteingabe, Reihenfolge, Zuordnung, Zahlenschätzung, Pin auf Bild) |
| `Beschreibung:` | `questions.description` (sanitized) |
| `Erklärung:` | `questions.solution_text` |
| `Bild:` / `Pin:` | `questions.image_hint` / `pin_hint` |
| Antworten, `Lösung:`, `Bereich:`, `Toleranz:` | `questions.data` je nach Typ |

Dasselbe Format wird auch **exportiert** («Als Text kopieren»): Quiz an die KI
geben («mach 5 weitere Fragen in diesem Stil», «übersetze ins Französische»),
Quizzes per Mail austauschen, lesbares Backup.

## Prompt (Gerüst)

Statisch, für alle gleich, versioniert (`Format: quiz-text/v1`). Inhalt:

1. Rolle: Du hilfst beim Erstellen eines Quiz für die App «…». Bei diesem Quiz
   bringen schnellere Antworten keine Punkte – gute Fragen regen zum
   Nachdenken und Diskutieren an.
2. Zuerst nachfragen: Thema, Zielgruppe/Alter, Anzahl Fragen, Sprache,
   gewünschte Fragetypen. Wer «mach einfach» sagt, bekommt sinnvolle Standards.
3. Format-Spezifikation mit einem Beispiel pro Typ (wie oben).
4. Regeln für die Ausgabe:
   - Immer das **komplette** Quiz in **einem** Codeblock, auch nach Änderungen.
   - Keine Bilder erfinden oder verlinken; stattdessen `Bild:` mit Beschreibung.
   - Zu jeder Frage eine kurze `Erklärung:`, bei Fakten möglichst mit Quelle.
   - Am Ende: «Kopiere jetzt den Block und füge ihn in der Quiz-App ein.»

Offen: Deep-Links (`chatgpt.com/?q=…`, `claude.ai/new?q=…`) mit der realen
Prompt-Länge testen; bei zu langer URL nur «Prompt kopieren» anbieten.

## Startseite (One-Pager)

1. **Hero**: «Denken statt Daumen.» + Unterzeile, Buttons «Quiz erstellen»
   und PIN-Feld «Mitmachen», Link «Anmelden». Visual: Beamer + Handy.
2. **Schnelligkeit zählt nicht. Nur die Antwort.** Visual: Team A tippt nach
   2 s, Team B diskutiert 40 s – beide gleich viele Punkte. Kein Timer, du
   bestimmst, wann es weitergeht. Beispiele: Schule (Verstehen statt
   Reaktion), Hochzeit (Grosi hat dieselbe Chance wie der Enkel), Team-Event.
3. **Nach jeder Frage: Auflösung als Diskussionsgrundlage.** Antwortverteilung,
   Musterlösung mit Erklärung/Bild/Video – nach jeder Frage oder am Schluss.
4. **Mehr als Multiple Choice.** Die sieben Fragetypen als kleine Karten.
5. **Fair bewertet.** Freitext selbst korrigieren, halbe Punkte, Rangliste
   zeigen, wann du willst.
6. **In 5 Minuten zum Quiz – mit deiner KI.** Die drei Schritte, «ohne Konto
   ausprobieren».
7. **Abschluss**: «Für Schulklassen, Vereine, Hochzeiten, Firmenanlässe» +
   beide Buttons.

Visuals möglichst aus echten App-Komponenten (vgl. `/styleguide`) statt
Stock-Illustrationen. Keine Kahoot-Logos/-Farben, keine Aussage wie «bei
Kahoot kann man das nicht abschalten» (Kahoot hat einen optionalen
Genauigkeitsmodus; der Vergleich bezieht sich auf das Standard-Kahoot).

## Umsetzung in Phasen

Jede Phase ist für sich deploybar (eigener Branch/MR).

### Phase 1 – Grundlagen (umgesetzt)

Nach dem Deploy Admin-Recht setzen:
`bin/quiz eval 'Quiz.Release.grant_admin("…")'`.

- **Admin-Rolle**: `users.admin` (Boolean, Default false), per Konsole/`bin/quiz
  eval` gesetzt. LiveDashboard (`/admin/dashboard`) zusätzlich darauf prüfen –
  heute ist «eingeloggt» gleich «Admin» (siehe Kommentar im Router). **Muss vor
  der offenen Registrierung live sein.**
- **Registrierung öffnen**: Route `/users/register` wieder aktivieren, ohne
  Bestätigung. Link auf Login- und Startseite.
- **Löschen in Storage**: `Quiz.Storage` hat heute nur `put/3` und `url/1`.
  Neuer Callback `delete_prefix/1` für R2 und Local. Uploads liegen in beiden
  Adaptern unter `Quiz.Storage.user_prefix(user_id)` (`uploads/<user_id>/`) →
  alle Medien eines Users lassen sich per Präfix löschen, inklusive verwaister
  Uploads.

### Phase 2 – Textformat und KI-Import (für registrierte Nutzer:innen) (umgesetzt)

- `Quiz.Games.TextFormat` (Name offen): `parse/1` → Quiz-Map + Liste von
  Fragen-Maps + Hinweise pro Frage; `render/1` für den Export. Gründlich
  getestet (jeder Typ, Toleranzen, kaputte Eingaben, Roundtrip
  `render |> parse`).
- Migration: Hinweisfelder für Bild/Stecknadel an `questions`.
- Import-LiveView (z. B. `/games/import`, in `live_session
  :require_authenticated_user`): Prompt-Buttons, Textfeld, Live-Vorschau
  (`phx-change`), «Als Entwurf anlegen» (`phx-submit`) → Game + Fragen in einer
  Transaktion über die bestehenden Changesets (`Question.changeset(…, :draft)`)
  → `push_navigate` in den Fragen-Editor.
- Prompt als versionierter Text im Code.
- Editor: Platzhalter-Darstellung für fehlende Bilder, Hinweistext anzeigen
  («Gesucht: …»), Übersicht «N Bilder fehlen noch» mit Direktlinks. Im Run
  werden fehlende Deko-Bilder nicht angezeigt (kein Platzhalter auf dem Beamer).
- Export-Button «Als Text kopieren» auf der Quiz-Seite.

### Phase 3 – Unfertige Fragen überspringen (umgesetzt)

- Heute blockiert `Quiz.Play.open_run/2` mit `{:error, {:incomplete_questions,
  …}}`. Neu: Bestätigungsdialog in `GameLive.Show`, danach Start ohne die
  unfertigen Fragen.
- Umsetzung offen und der invasivste Teil: Run, Review, Statistik, Korrektur
  und Rangliste arbeiten mit `position`. Variante A: Flag an der Frage
  (`skipped`), überall über *eine* Funktion für «spielbare Fragen» filtern.
  Variante B: unfertige Fragen beim Öffnen ans Ende verschieben und die Anzahl
  der gespielten Fragen begrenzen. Vor der Umsetzung die Positionslogik prüfen.

### Phase 4 – Gastmodus (umgesetzt)

- `users.guest` (Boolean) + `users.expires_at`. E-Mail/Passwort für Gäste
  optional (Migration der NOT-NULL-/Unique-Constraints prüfen).
- Gast wird **lazy** angelegt: erst beim «Als Entwurf anlegen», nicht beim
  Öffnen der Seite. Login über das bestehende Session-Token, mit
  Remember-Cookie (überlebt Browser-Neustart).
- Import-Seite für Gäste in einer öffentlichen Route
  (`live_session :current_user`), weil dort noch kein User existiert; alle
  weiteren Seiten funktionieren, weil der Gast ein normaler User ist.
- Limits: max. 3 Games pro Gast; Rate-Limit pro IP für das Anlegen von Gästen
  (ETS, pro Node reicht). Feature-Flag per Umgebungsvariable.
- «Konto übernehmen»: Registrierung ergänzt beim Gast E-Mail + Passwort,
  setzt `guest = false`, `expires_at = nil`. Quizzes bleiben, wo sie sind.
  `/users/settings` zeigt Gästen stattdessen «Konto sichern».
- Hinweise: Banner mit Ablaufdatum, Hinweis «Cookies gelöscht = Quiz weg»,
  Aufruf auf der Rangliste.
- **Aufräum-Job**: GenServer im Supervision-Tree (kein Oban vorhanden), läuft
  z. B. stündlich. Pro abgelaufenem Gast: zuerst `Storage.delete_prefix
  ("uploads/<id>/")`, dann User löschen (kaskadiert auf Games → Fragen,
  Teilnahmen, Antworten – Kaskaden prüfen). Idempotent, damit Fehler (R2 nicht
  erreichbar) beim nächsten Lauf nachgeholt werden und mehrere Fly-Maschinen
  sich nicht stören. Ein gerade laufendes Quiz nicht löschen (Ablauf um einen
  Lauf verschieben).

### Phase 5 – Startseite (umgesetzt)

- `PageController :home` neu als One-Pager gemäss Abschnitt oben.
- Danach die Sponsors-Seite und Login-Link einordnen.

## Offene Punkte

- Name für Gast-Import-Route und Assistent.
- Datenschutzerklärung/Nutzungsbedingungen für offene Registrierung.
- Ob `Beschreibung:` im Format nötig ist oder `Erklärung:` reicht.
- Deep-Link-Längen (siehe Prompt).
