# NVidiaLogRemover

## [🇫🇷 Version Française](#français)

## [🇬🇧 English Version](#english)

---

## Français

Petit outil (en français ou en anglais, pensé pour un enfant de 12 ans) qui règle le problème du fichier journal NVIDIA
`C:\ProgramData\NVIDIA Corporation\nvtopps\nct\nvlog.nvlgstg`, qui grossit énormément
avec les pilotes **621.14** et **621.24** (jusqu'à 30 Go par heure de jeu).

### Utilisation

1. Organisation du dossier (ne pas déplacer ni renommer `scripts\`) :
   ```
   EXECUTE_MOI_Français.bat     <- à lancer (programme en français)
   RUN_ME_English.bat           <- à lancer (programme en anglais)
   Documentation_Français.html  <- guide illustré pour l'enfant (français)
   Documentation_English.html   <- guide illustré pour l'enfant (anglais)
   README.md                    <- ce fichier
   scripts\
       NettoyageNvidia.ps1             (fenêtre, paramètre -Language fr|en)
       NettoyageJournalDemarrage.ps1   (vérification auto, paramètre -Language fr|en)
       messages.fr.psd1                (textes en français)
       messages.en.psd1                (textes en anglais, mêmes clés)
   ```
2. Double-cliquer sur **`EXECUTE_MOI_Français.bat`** (ou **`RUN_ME_English.bat`**) puis cliquer sur **Oui** (droits administrateur).
3. Cliquer sur le **bouton jaune** : c'est toujours la prochaine étape. Recommencer jusqu'à « Tout est réparé ! ».
4. Si un redémarrage est demandé : redémarrer, relancer le `.bat`, et continuer avec le bouton jaune.
   À chaque ouverture et après chaque action, l'outil regarde l'état réel de l'ordinateur
   (journal vidé ? mauvais pilote enlevé ? bon pilote téléchargé ? installé ?) et indique l'étape suivante.

Le guide illustré pour l'enfant est dans `Documentation_Français.html` (ou `Documentation_English.html`).

### Ce que fait l'outil

| Étape | Action |
| --- | --- |
| 1 | Arrête le service « NVIDIA Display Container LS », supprime `nvlog.nvlgstg`, redémarre le service |
| 2 | Si le pilote 621.14 ou 621.24 est installé : lance le désinstalleur NVIDIA |
| 3 | Télécharge le pilote 621.01 (~1 Go) dans `C:\ProgramData\NVidiaLogRemover\` et vérifie sa signature NVIDIA |
| 4 | Lance l'installateur NVIDIA 621.01 |
| 5 | Supprime le fichier téléchargé et le dossier extrait `C:\NVIDIA\DisplayDriver\621.01` |

La taille actuelle du fichier journal est affichée en direct (rafraîchie toutes les 2 secondes).
Pendant les vérifications (jusqu'à une quinzaine de secondes, surtout pour contrôler la signature du pilote téléchargé),
la fenêtre affiche « je vérifie . . . » avec une animation, et les boutons restent grisés.

### Nettoyage automatique

En bas de la fenêtre, trois choix créent, modifient ou suppriment une tâche planifiée Windows
(`NVidiaLogRemover-NettoyageDemarrage`, visible dans le Planificateur de tâches). Elle supprime le fichier
journal s'il dépasse **200 Mo** (arrêt du service, suppression, redémarrage du service).

| Choix | Quand | Risque |
| --- | --- | --- |
| Désactivé | jamais (la tâche et son dossier sont supprimés) | le journal peut grossir |
| **À l'ouverture et à la fermeture de Windows** (conseillé) | démarrage (+1 min), ouverture de session (+1 min, couvre le « démarrage rapide » de Windows), arrêt / redémarrage (événement `User32` 1074) | aucun pour les jeux ; à l'arrêt, exécution « au mieux » (Windows peut couper avant la fin), la vérification suivante rattrape |
| Toutes les 3 heures | démarrage (+1 min) puis toutes les 3 h | peut tomber **pendant une partie** : l'arrêt du service NVIDIA peut figer, faire clignoter ou planter le jeu (confirmation demandée) |

- La tâche tourne avec le compte SYSTEM, même si personne n'ouvre de session.
- Son script est copié dans `C:\Program Files\NVidiaLogRemover\` (dossier modifiable uniquement par un administrateur).
- Les lignes d'historique de la tâche sont écrites dans la langue du `.bat` qui l'a créée.
- La limite (`StartupThresholdMB`) et l'intervalle (`StartupRepeatHours`) se changent en haut de
  `scripts\NettoyageNvidia.ps1`, puis rechoisir le mode pour recréer la tâche.

### Historique

Toutes les actions (fenêtre et nettoyage automatique) sont écrites dans `C:\ProgramData\NVidiaLogRemover\journal.txt`.

### Modifier les réglages

- Versions, URL et seuils : bloc `$Config` en haut de `scripts\NettoyageNvidia.ps1`.
- Textes affichés : `scripts\messages.fr.psd1` et `scripts\messages.en.psd1` (mêmes clés), à enregistrer
  en UTF-8 **avec BOM**, sinon les accents s'affichent mal sous Windows PowerShell 5.1.

### Publier une version

Le workflow GitHub `.github/workflows/release.yml` crée automatiquement une release quand on pousse un tag `v*` :

```
git tag v1.0.0
git push origin v1.0.0
```

Il fabrique `NVidiaLogRemover-v1.0.0.7z` (un dossier `NVidiaLogRemover` avec les deux `.bat`, les deux guides,
`README.md` et `scripts\`) et le joint à la release GitHub. `.gitattributes` garantit que les `.bat` / `.ps1` / `.psd1`
gardent leurs fins de ligne Windows (CRLF) dans l'archive.

[⬆ Haut de page](#nvidialogremover) · [🇬🇧 English version](#english)

---

## English

Small tool (in French or English, designed for a 12-year-old) that fixes the NVIDIA log file problem:
`C:\ProgramData\NVIDIA Corporation\nvtopps\nct\nvlog.nvlgstg` grows enormously
with drivers **621.14** and **621.24** (up to 30 GB per hour of gaming).

### Usage

1. Folder layout (do not move or rename `scripts\`):
   ```
   EXECUTE_MOI_Français.bat     <- run this (program in French)
   RUN_ME_English.bat           <- run this (program in English)
   Documentation_Français.html  <- illustrated guide for the child (French)
   Documentation_English.html   <- illustrated guide for the child (English)
   README.md                    <- this file
   scripts\
       NettoyageNvidia.ps1             (window, -Language fr|en parameter)
       NettoyageJournalDemarrage.ps1   (automatic check, -Language fr|en parameter)
       messages.fr.psd1                (French texts)
       messages.en.psd1                (English texts, same keys)
   ```
2. Double-click **`RUN_ME_English.bat`** (or **`EXECUTE_MOI_Français.bat`**) then click **Yes** (administrator rights).
3. Click the **yellow button**: it is always the next step. Repeat until "Everything is fixed!".
4. If a restart is requested: restart, run the `.bat` again, and carry on with the yellow button.
   Every time it opens and after every action, the tool checks the real state of the computer
   (log emptied? wrong driver removed? right driver downloaded? installed?) and shows the next step.

The illustrated guide for the child is `Documentation_English.html` (or `Documentation_Français.html`).

### What the tool does

| Step | Action |
| --- | --- |
| 1 | Stops the "NVIDIA Display Container LS" service, deletes `nvlog.nvlgstg`, starts the service again |
| 2 | If driver 621.14 or 621.24 is installed: runs the NVIDIA uninstaller |
| 3 | Downloads driver 621.01 (~1 GB) to `C:\ProgramData\NVidiaLogRemover\` and checks its NVIDIA signature |
| 4 | Runs the NVIDIA 621.01 installer |
| 5 | Deletes the downloaded file and the extracted folder `C:\NVIDIA\DisplayDriver\621.01` |

The current log file size is shown live (refreshed every 2 seconds).
While checking (up to about fifteen seconds, mostly to verify the signature of the downloaded driver),
the window shows an animated "checking . . ." and the buttons stay greyed out.

### Automatic cleanup

At the bottom of the window, three choices create, change or delete a Windows scheduled task
(`NVidiaLogRemover-NettoyageDemarrage`, visible in Task Scheduler). It deletes the log file
if it is larger than **200 MB** (stop the service, delete, start the service again).

| Choice | When | Risk |
| --- | --- | --- |
| Off | never (the task and its folder are deleted) | the log can grow |
| **When Windows starts and shuts down** (recommended) | boot (+1 min), log-on (+1 min, covers Windows "Fast Startup"), shutdown / restart (`User32` event 1074) | none for games; at shutdown it is "best effort" (Windows may cut it short), the next check catches up |
| Every 3 hours | boot (+1 min) then every 3 h | can happen **during a game**: stopping the NVIDIA service can freeze, flicker or crash the game (confirmation requested) |

- The task runs under the SYSTEM account, even if nobody logs in.
- Its script is copied to `C:\Program Files\NVidiaLogRemover\` (folder only administrators can modify).
- The task's history lines are written in the language of the `.bat` that created it.
- The limit (`StartupThresholdMB`) and the interval (`StartupRepeatHours`) are set at the top of
  `scripts\NettoyageNvidia.ps1`; then choose the mode again to recreate the task.

### History

Every action (window and automatic cleanup) is written to `C:\ProgramData\NVidiaLogRemover\journal.txt`.

### Changing the settings

- Versions, URL and thresholds: `$Config` block at the top of `scripts\NettoyageNvidia.ps1`.
- Displayed texts: `scripts\messages.en.psd1` and `scripts\messages.fr.psd1` (same keys), saved
  as UTF-8 **with BOM**, otherwise accents break in Windows PowerShell 5.1.

### Publishing a release

The GitHub workflow `.github/workflows/release.yml` creates a release automatically when a `v*` tag is pushed:

```
git tag v1.0.0
git push origin v1.0.0
```

It builds `NVidiaLogRemover-v1.0.0.7z` (one `NVidiaLogRemover` folder with both `.bat` files, both guides,
`README.md` and `scripts\`) and attaches it to the GitHub release. `.gitattributes` makes sure the `.bat` / `.ps1` / `.psd1`
files keep their Windows (CRLF) line endings in the archive.

[⬆ Back to top](#nvidialogremover) · [🇫🇷 Version française](#français)
