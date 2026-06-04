#!/usr/bin/env python3
"""Import des workflows ETL_Projet_BC dans n8n via l'API REST."""

import json
import urllib.request
import urllib.error
import os
import sys

API_KEY   = 'n8n_api_39cf9ddc772145ee828f396e51fdeabe'
BASE_URL  = 'http://localhost:5678/api/v1'
HEADERS   = {
    'X-N8N-API-KEY': API_KEY,
    'Content-Type':  'application/json',
    'Accept':        'application/json',
}

WF_DIR = '/home/nyanu/Documents/ETL_Projet_BC/n8n/workflows'

# Fichiers à importer (ordre logique)
FILES = [
    '04b_distance_webhook.json',
    '08_gold_to_bc.json',
    '08a_sync_customers.json',
    '08b_sync_articles.json',
    '08c_sync_headers.json',
    '08d_sync_distances.json',
    '08e_sync_shipment_lines.json',
    '08f_sync_ecommerce_lines.json',
]

def api_get(path):
    req = urllib.request.Request(f'{BASE_URL}{path}', headers=HEADERS)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f'{BASE_URL}{path}', data=data, headers=HEADERS, method='POST')
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())

def api_put(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f'{BASE_URL}{path}', data=data, headers=HEADERS, method='PUT')
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f'{BASE_URL}{path}', data=data, headers=HEADERS, method='PATCH')
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())

# Récupérer les workflows existants (pour éviter les doublons)
existing = {}
try:
    result = api_get('/workflows?limit=50')
    for wf in result.get('data', []):
        existing[wf['name']] = wf['id']
    print(f'Workflows existants dans n8n : {len(existing)}')
    for name, wfid in existing.items():
        print(f'  [{wfid}] {name}')
except Exception as e:
    print(f'Erreur récupération workflows existants : {e}')
    sys.exit(1)

print()
results = []

for filename in FILES:
    filepath = os.path.join(WF_DIR, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        wf = json.load(f)

    name = wf['name']
    wf_id = wf.get('id')

    # Préparer le payload pour l'API n8n
    # L'API n8n attend : name, nodes, connections, settings, staticData
    payload = {
        'name':        wf['name'],
        'nodes':       wf['nodes'],
        'connections': wf['connections'],
        'settings':    wf.get('settings', {'executionOrder': 'v1'}),
        'staticData':  wf.get('staticData', None),
    }
    # Les tags sont read-only via l'API n8n — ne pas les inclure dans le payload

    if name in existing:
        # Le workflow existe déjà → on le met à jour (PUT)
        existing_id = existing[name]
        print(f'↻  MISE À JOUR  [{existing_id}] {name}')
        status, resp = api_put(f'/workflows/{existing_id}', payload)
        if status in (200, 201):
            print(f'   ✔  Mis à jour (HTTP {status})')
            # Réactiver si nécessaire
            if wf.get('active', True):
                api_patch(f'/workflows/{existing_id}/activate', {})
            results.append({'file': filename, 'action': 'updated', 'id': existing_id, 'status': status})
        else:
            print(f'   ✘  Erreur HTTP {status} : {str(resp)[:200]}')
            results.append({'file': filename, 'action': 'error', 'id': existing_id, 'status': status, 'detail': str(resp)[:200]})
    else:
        # Nouveau workflow → POST
        print(f'✚  CRÉATION    {name}')
        status, resp = api_post('/workflows', payload)
        if status in (200, 201):
            new_id = resp.get('id', '?')
            print(f'   ✔  Créé avec ID [{new_id}] (HTTP {status})')
            # Activer le workflow
            if wf.get('active', True):
                act_status, _ = api_patch(f'/workflows/{new_id}/activate', {})
                print(f'   ▶  Activation : HTTP {act_status}')
            results.append({'file': filename, 'action': 'created', 'id': new_id, 'status': status})
        else:
            print(f'   ✘  Erreur HTTP {status} : {str(resp)[:300]}')
            results.append({'file': filename, 'action': 'error', 'status': status, 'detail': str(resp)[:300]})

print()
print('═' * 60)
created = [r for r in results if r['action'] == 'created']
updated = [r for r in results if r['action'] == 'updated']
errors  = [r for r in results if r['action'] == 'error']
print(f'RÉSULTAT : {len(created)} créés | {len(updated)} mis à jour | {len(errors)} erreurs')
if errors:
    print('ERREURS :')
    for e in errors:
        print(f'  {e["file"]} → HTTP {e["status"]} : {e.get("detail","")}')
