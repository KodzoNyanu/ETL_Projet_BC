#!/usr/bin/env python3
"""
Fix n8n v2.x workflow_published_version + workflow_history.connections.

Problèmes corrigés (découverts 2026-06-25) :
  1. workflow_published_version vide → le task runner n8n v2 ne trouve pas le code
     des sous-workflows (ex: WF-08D) → exécution de 0 nœuds en 7-31 ms.
  2. workflow_history.connections = '{}' sur les entrées créées manuellement
     → n8n ne sait pas enchaîner les nœuds → même symptôme.

Usage : python3 fix_n8n_publish.py [chemin/database.sqlite]
"""

import sqlite3, sys, os

DB = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    '~/Documents/ETL_Projet/n8n_data/database.sqlite'
)

if not os.path.exists(DB):
    print(f"Erreur : base introuvable → {DB}")
    sys.exit(1)

conn = sqlite3.connect(DB)
cur  = conn.cursor()

# ── 1. Corriger workflow_history.connections vides ──────────────────────────
cur.execute("""
    SELECT wh.versionId, we.id, we.connections
    FROM workflow_history wh
    JOIN workflow_entity we ON wh.workflowId = we.id
    WHERE length(wh.connections) <= 2
""")
rows = cur.fetchall()
fixed_conn = 0
for vid, wf_id, real_conn in rows:
    cur.execute(
        "UPDATE workflow_history SET connections=? WHERE versionId=?",
        (real_conn, vid)
    )
    fixed_conn += 1
    print(f"  ✅ connections fixes : {vid[:8]}... ({wf_id})")

# ── 2. Peupler workflow_published_version ───────────────────────────────────
cur.execute("""
    SELECT wh.workflowId, wh.versionId
    FROM workflow_history wh
    INNER JOIN (
        SELECT workflowId, MAX(createdAt) as latest
        FROM workflow_history GROUP BY workflowId
    ) latest ON wh.workflowId = latest.workflowId AND wh.createdAt = latest.latest
""")
history = {row[0]: row[1] for row in cur.fetchall()}

cur.execute("SELECT id, name, activeVersionId FROM workflow_entity WHERE active=1")
published = 0
skipped   = 0
for wf_id, name, active_vid in cur.fetchall():
    # Préférer activeVersionId si présent dans workflow_history, sinon dernière entrée
    cur.execute("SELECT versionId FROM workflow_history WHERE versionId=?", (active_vid,))
    version_to_pub = active_vid if cur.fetchone() else history.get(wf_id)

    if not version_to_pub:
        print(f"  ⚠️  SKIP {name} — pas d'entrée workflow_history")
        skipped += 1
        continue

    cur.execute("""
        INSERT INTO workflow_published_version
          (workflowId, publishedVersionId, createdAt, updatedAt)
        VALUES (?, ?, datetime('now'), datetime('now'))
        ON CONFLICT(workflowId) DO UPDATE SET
          publishedVersionId=excluded.publishedVersionId,
          updatedAt=datetime('now')
    """, (wf_id, version_to_pub))
    print(f"  ✅ published : {name[:55]} → {version_to_pub[:8]}...")
    published += 1

conn.commit()
conn.close()

print(f"\nDone — {fixed_conn} connections fixées | {published} workflows publiés | {skipped} ignorés")
print("→ Relance n8n : docker restart ingestion_n8n")
