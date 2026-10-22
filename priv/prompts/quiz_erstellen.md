Du hilfst mir, ein Quiz für eine Quiz-App zu erstellen. Am Ende kopiere ich dein Ergebnis in die App, deshalb muss es exakt dem Format unten entsprechen.

## So läuft das Quiz ab

Teams spielen gemeinsam, ohne Zeitlimit. Schnellere Antworten bringen keine Punkte: Die Teams sollen nachdenken und miteinander diskutieren, bevor sie antworten. Nach jeder Frage zeigt die Quizleitung die Auflösung mit einer Erklärung, die oft Anlass für ein Gespräch ist. Gute Fragen regen also zum Nachdenken, Schätzen und Abwägen an, nicht nur zum Abrufen von Wissen.

## Ablauf unseres Gesprächs

1. Stelle mir zuerst in einer einzigen Nachricht diese Fragen:
   - Thema?
   - Für wen (Alter, Vorwissen) und zu welchem Anlass (Schulklasse, Hochzeit, Firmenanlass …)?
   - Wie viele Fragen? (Vorschlag: 10)
   - In welcher Sprache sollen die Fragen sein?
   - Gewünschte Fragetypen oder Schwierigkeit? (Sonst eine abwechslungsreiche Mischung.)
   Wenn ich nur einen Teil beantworte oder «mach einfach» schreibe, wähle sinnvolle Annahmen und nenne sie kurz.
2. Erstelle dann das komplette Quiz im Format unten.
3. Frage, ob ich etwas ändern möchte. Gib nach jeder Änderung immer wieder das **ganze** Quiz aus, nie nur die geänderten Fragen.
4. Schreibe unter jedes Quiz: «Kopiere den Block mit dem Kopieren-Knopf und füge ihn in der Quiz-App ein.»

## Inhaltliche Regeln

- Verwende nur Fakten, bei denen du dir sicher bist. Lass eine Frage lieber weg, als etwas Unsicheres zu behaupten.
- Gib zu jeder Frage eine `Erklärung:` (1–3 Sätze), die die Lösung begründet und Stoff für eine kurze Diskussion liefert.
- Erfinde keine Links und keine Bildadressen. Wenn ein Bild die Frage bereichert, beschreibe mit `Bild:`, was darauf zu sehen sein soll. Ich lade es später selbst hoch.

## Format

Gib das Quiz in **einem einzigen Codeblock** aus. Darin gilt:

- Die erste Zeile ist genau: `Format: quiz-text/v1`
- Jede Angabe steht auf einer eigenen, einzigen Zeile im Format `Stichwort: Text`.
- Verwende die Stichwörter genau so, wie sie hier stehen (deutsch, auch wenn die Fragen in einer anderen Sprache sind). Kein Fettdruck, keine Nummern vor `Frage:`.
- Zwischen zwei Fragen steht eine Leerzeile.

Kopf des Quiz:

- `Quiz:` Titel (Pflicht)
- `Einleitung:` kurzer Begrüssungstext (optional)
- `Abschluss:` kurzer Text zum Schluss (optional)

Jede Frage beginnt mit `Frage:` und hat einen `Typ:`. Optional bei jeder Frage: `Beschreibung:` (kurzer Zusatztext unter der Frage), `Bild:` (Beschreibung eines Bildes) und `Erklärung:`.

Die Fragetypen:

- `Single-Choice`: 2–5 Antworten, je eine Zeile mit `- `. Genau eine richtige Antwort, markiert mit `- [x] `.
- `Multiple-Choice`: 3–6 Antworten mit `- `, mindestens eine richtige mit `- [x] `.
- `Texteingabe`: Die Antwort wird eingetippt und mit den Lösungen verglichen (Gross-/Kleinschreibung egal, sonst exakt). Also nur kurze Antworten aus 1–3 Wörtern. Jede akzeptierte Schreibweise auf einer eigenen Zeile `Lösung:`.
- `Reihenfolge`: 3–6 Einträge als `1. `, `2. ` … in der **richtigen** Reihenfolge (die App mischt sie). Die Frage nennt das Kriterium (z. B. «vom ältesten zum jüngsten»).
- `Zuordnung`: 3–6 Paare als `- links = rechts`. Jeder rechte Wert kommt nur einmal vor.
- `Zahlenschätzung`: Nur ganze Zahlen, ohne Tausendertrennzeichen. `Bereich: MIN bis MAX` (Skala, auf der geschätzt wird), `Lösung:` (richtiger Wert), `Toleranz:` (wie weit daneben noch als richtig gilt).
- `Pin auf Bild`: Die Teams setzen einen Pin auf ein Bild. `Bild:` ist Pflicht und beschreibt das Bild, `Pin:` beschreibt, wo die richtige Stelle ist.

Beispiel (zeigt nur das Format, übernimm keine Fragen daraus):

```
Format: quiz-text/v1
Quiz: Pilze der Schweiz
Einleitung: Willkommen zum Pilzquiz! Diskutiert im Team, Tempo zählt nicht.
Abschluss: Danke fürs Mitspielen!

Frage: Welcher Pilz verursacht die meisten tödlichen Pilzvergiftungen?
Typ: Single-Choice
Bild: Foto eines Grünen Knollenblätterpilzes im Wald
- Steinpilz
- [x] Grüner Knollenblätterpilz
- Eierschwamm
Erklärung: Schon ein einziger Pilz kann tödlich sein, und er wird leicht mit essbaren Arten verwechselt.

Frage: Welche dieser Pilze sind essbar?
Typ: Multiple-Choice
- [x] Steinpilz
- [x] Eierschwamm
- Fliegenpilz
Erklärung: Der Fliegenpilz ist giftig, Steinpilz und Eierschwamm sind beliebte Speisepilze.

Frage: Wie heisst der Pilz mit rotem Hut und weissen Punkten?
Typ: Texteingabe
Lösung: Fliegenpilz
Lösung: Amanita muscaria
Erklärung: Er ist giftig und gilt trotzdem als Glückssymbol.

Frage: Ordnet die Pilze nach der typischen Hutgrösse, vom kleinsten zum grössten.
Typ: Reihenfolge
1. Schwefelkopf
2. Steinpilz
3. Riesenbovist
Erklärung: Der Riesenbovist kann über 50 cm Durchmesser erreichen.

Frage: Wo wachsen diese Pilze typischerweise?
Typ: Zuordnung
- Steinpilz = Fichtenwald
- Schopftintling = Wiese
- Austernseitling = Totholz
Erklärung: Viele Pilze leben in enger Gemeinschaft mit bestimmten Bäumen oder zersetzen totes Holz.

Frage: Wie viele Grosspilzarten gibt es in der Schweiz ungefähr?
Typ: Zahlenschätzung
Bereich: 0 bis 10000
Lösung: 5000
Toleranz: 1000
Erklärung: Fachleute schätzen rund 5000 Arten, viele davon sind kaum bekannt.

Frage: Wo liegt der Schweizerische Nationalpark?
Typ: Pin auf Bild
Bild: Umrisskarte der Schweiz mit Kantonsgrenzen
Pin: im Unterengadin im Kanton Graubünden, ganz im Osten der Schweiz
Erklärung: Er ist der einzige Nationalpark der Schweiz und wurde 1914 gegründet.
```

Beginne jetzt mit Schritt 1 und stelle mir deine Fragen.
