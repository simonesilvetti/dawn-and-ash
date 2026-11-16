---
title: Risultati dei test di rete
type: result
tags: [rete, lag]
updated: 2026-11-16
sources: [tools/net_tests.sh, tools/windows_tests.sh]
---

# Risultati dei test di rete

Host e client sulla stessa macchina, 30 s di gioco (prova finale), client che si muove, insegue e attacca.

| Condizione | Errore riconciliazione medio (max) | Salto creep/frame | Banda in ingresso | Snapshot persi |
|---|---|---|---|---|
| 0 ms | 0.15 m (1.2) | 0.14 m | 8.1 KB/s | 0 |
| 80 ms | 0.17 m (1.6) | 0.14 m | 8.1 KB/s | 0 |
| 150 ms + jitter 30 + 3% | 0.21 m (2.3) | 0.14 m | 8.1 KB/s | 35 |
| 250 ms + 5% | 0.21 m (2.0) | 0.14 m | 8.1 KB/s | 65 |

Limiti: errore medio < 0.3 m fino a 150 ms, nessun teletrasporto visivo (< 1.5 m/frame), banda < 30 KB/s → rispettati.

Verifica del 2026-10-22 (dopo l'aggiunta di [[peppino]]), 30 s: 0 ms 0.156 m (max 1.27), 80 ms 0.170 (1.46),
150+jitter+3% 0.197 (2.35, 40 snapshot persi), **Peppino a 80 ms 0.178 (1.49)**, 250+5% 0.211 (1.93, 51 persi);
banda 8.4 KB/s; salto creep 0.14–0.17 m. Tutti `[OK]`, robustezza compresa.

Linux ↔ Windows (2026-10-26, exe Windows sotto Wine, `tools/windows_tests.sh`, client Peppino, 30 s):
host Linux + client Windows 0.158 m (max 1.22); host Windows + client Linux 0.159 m (1.22);
host Windows + client Linux a 150 ms + jitter 30 + 3% 0.210 m (2.13, 36 persi); banda 8.4 KB/s, salto creep 0.14 m.
Uguali ai numeri tra due Linux: la versione Windows può giocare con quella Linux. Vedi [[build-e-distribuzione]].

Robustezza: client terminato a forza → vittoria a tavolino per l'host, ritorno al menu e nuova partita senza crash.

## Storia
- Prima versione: errore 0.20–0.38 m e scatti dei creep di 0.93 m.
- Fix 1: campione iniziale al tempo di rendering e unità ferme non estrapolate → scatti 0.05–0.17 m.
- Fix 2: riconciliazione con ack dei comandi (indipendente dal jitter) → errore ≤ 0.17 m. → [[netcode]]

Verifica del 2026-11-16 (dopo l'aggiunta di [[gorm]], flag a 16 bit), 30 s: 0 ms 0.153 m (max 1.21), 80 ms 0.174 (1.57),
150+jitter+3% 0.204 (2.38, 33 persi), Peppino a 80 ms 0.178 (1.54), **Gorm a 80 ms 0.158 (1.48)** con muro e totem carico
visti dal client, 250+5% 0.197 (1.99, 50 persi); banda 8.4–8.5 KB/s come prima.

> [!warning] Il caso di robustezza fallisce ("nuova partita di allenamento dopo la disconnessione") **anche sul commit
> di partenza `1ea3f01`**, con la CPU occupata da altri processi: non dipende da Gorm. Da ricontrollare a macchina scarica.
