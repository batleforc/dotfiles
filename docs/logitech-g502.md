# Souris Logitech G502 X LIGHTSPEED : fréquence et profils

État au 20 novembre 2026, avec OpenLogi 0.9.0.

## Où on en est

| | Valeur | D'où ça vient |
|---|---|---|
| Profil actif | **profil d'usine n°2** | mémoire de la souris |
| DPI | **1600** | OpenLogi (`dpi = 1600` dans `~/.config/openlogi/config.toml`) |
| Fréquence | **500 Hz** | fixée par le profil 2, non modifiable |

Le but initial était 1600 DPI à 1000 Hz. Les 1600 DPI sont en place, les 1000 Hz non.

## Pourquoi pas 1000 Hz

- **Les profils de la souris sont en mémoire morte.** Les profils 1 et 2 sont stockés
  dans des secteurs `0x01xx`, en lecture seule : ce sont les profils d'usine. La
  souris a refusé de réécrire le profil 2 (`Sector 257 not a writable sector`). Rien
  n'a été écrit.
- **En mode embarqué, c'est le profil qui fixe la fréquence.** Toute écriture de la
  fréquence est refusée par la souris (`InvalidArgument` sur la fonction HID++ `0x8060`).
- **Le mode hôte n'est pas encore pris en charge pour ce modèle.** OpenLogi peut
  passer une souris G en mode hôte (c'est alors lui qui fixe DPI, fréquence et
  boutons, et il rend la main au profil embarqué quand son agent s'arrête). Mais il
  lui faut la disposition des boutons de la souris, et la version 0.9.0 ne la
  connaît que pour la **G502 LIGHTSPEED** (`wpid 0x407f`). La **G502 X** est
  `0x409f`, et un test du projet vérifie explicitement qu'elle n'en a pas
  (`crates/openlogi-core/src/binding/gaming.rs`).

## Les deux profils d'usine

Sauvegarde complète : [`g502/onboard-profiles-factory.yaml`](g502/onboard-profiles-factory.yaml)
(lue avec Solaar, sans numéro de série).

| | Profil 1 | Profil 2 (actif) |
|---|---|---|
| Fréquence | **1000 Hz** | 500 Hz |
| Paliers DPI | 800 / 1200 / **1600** / 2400 / 3200 | idem |
| Boutons | rôles standard | un bouton devient **G-Shift** |
| Couche G-Shift (bouton G-Shift maintenu) | vide | `Ctrl+T`, `Ctrl+Shift+Tab`, `Ctrl+Tab`, `Ctrl+0`, `Ctrl+Z`, `Ctrl+X`, et des clics souris |

Le passage au profil 1 donne donc 1000 Hz, **au prix des raccourcis G-Shift**.

## Option A : passer au profil 1 maintenant

Dans `~/.config/openlogi/config.toml`, sous la section de la souris :

```toml
[devices."unit:ca8fc575"]
dpi = 1600
onboard_memory = { profile = 1 }
```

Puis :

```bash
systemctl --user restart openlogi-agent
openlogi diag onboard              # attendu : "profile 1 ... [active]"
openlogi api devices               # récupère l'identifiant de la souris
openlogi api report-rate --device "slot 1 on receiver 16BB5BDD"   # attendu : 1000
```

**Pour revenir en arrière**, retirer la ligne `onboard_memory`, relancer l'agent,
puis remettre le profil 2 actif (`onboard_memory = { profile = 2 }` le temps d'un
redémarrage de l'agent, puis retirer la ligne).

⚠️ La syntaxe `{ profile = <n> }` vient de la doc d'OpenLogi
(`docs/CONFIGURATION.md`), mais **elle n'a pas été testée sur cette souris**. Un
mauvais format n'abîme rien : l'agent refuse alors tout le fichier, démarre avec
sa config par défaut, et l'erreur s'affiche dans
`journalctl --user -u openlogi-agent`. Sauvegarde le fichier avant de le modifier.

Ce fichier n'est pas géré par chezmoi : OpenLogi le réécrit lui-même.

## Option B : attendre qu'OpenLogi gère la G502 X

C'est la seule façon d'avoir le mélange voulu : **profil 2 et ses raccourcis quand
OpenLogi ne tourne pas, 1000 Hz et 1600 DPI quand il tourne**.

Pour savoir si une nouvelle version prend en charge `0x409f` :

```bash
gh search code 409f --repo AprilNEA/OpenLogi        # cherche la disposition des boutons
gh release list --repo AprilNEA/OpenLogi --limit 5  # notes de version
```

Quand c'est le cas (weebo-os installe OpenLogi par `files/scripts/binary/install-openlogi.sh`,
et updatecli ouvre une PR à chaque nouvelle version) :

```toml
[devices."unit:ca8fc575"]
dpi = 1600
report_rate = 1000
onboard_memory = "off"
```

Puis `systemctl --user restart openlogi-agent` et `openlogi diag onboard`
(attendu : `mode: host`).

Sans prise en charge, ce même bloc ne fait rien : l'agent reste en mode embarqué et
répète `report-rate write failed ... InvalidArgument` dans son journal. Retirer
alors ces deux lignes.

## Outils

- **OpenLogi** : `openlogi list`, `openlogi api …`, `openlogi diag onboard`. Son
  agent (`openlogi-agent.service`) est activé pour tous les utilisateurs par l'image.
- **Solaar** a été retiré de weebo-os (PR #153) : il se disputait le récepteur avec
  OpenLogi. Il n'est plus là pour relire les profils après la mise à jour de
  l'image ; `openlogi diag onboard` montre le profil actif et le mode.
