#!/usr/bin/env python3
"""Architecture ETL_Projet_BC — layout grille propre."""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch

fig, ax = plt.subplots(figsize=(24, 14))
ax.set_xlim(0, 24); ax.set_ylim(0, 14)
ax.axis('off'); fig.patch.set_facecolor('#FAFAFA')

# ── palette ─────────────────────────────────────────────────────────────────
SRC_F, SRC_E = '#D6EAF8', '#1A5276'
MOB_F, MOB_E = '#FEF9E7', '#9A7D0A'
ETL_F, ETL_E = '#E9F7EF', '#1A6633'
BC_F,  BC_E  = '#FDEDEC', '#922B21'
GLD_F, GLD_E = '#F4ECF7', '#6C3483'
N8N_F        = '#1D8348'
MIN_F        = '#A9DFBF'
PRX_F        = '#A9DFBF'
PG_F         = '#C39BD3'
MB_F         = '#7D3C98'
BC2_F        = '#F1948A'

# ── primitives ───────────────────────────────────────────────────────────────
def box(x, y, w, h, lines, fc, ec, lw=1.6, bold_first=True):
    ax.add_patch(FancyBboxPatch((x,y), w, h, boxstyle='round,pad=0.08',
                 fc=fc, ec=ec, lw=lw, zorder=3))
    cols = ['white' if fc in (N8N_F, MB_F) else '#111'] * len(lines)
    sizes = [8.8] + [7.5]*(len(lines)-1)
    weights = ['bold'] + ['normal']*(len(lines)-1)
    step = h/(len(lines)+1)
    for i,(t,s,fw,c) in enumerate(zip(lines,sizes,weights,cols)):
        ax.text(x+w/2, y+h-step*(i+1), t, ha='center', va='center',
                fontsize=s, fontweight=fw, color=c, zorder=4)

def frame(x, y, w, h, title, fc, ec):
    ax.add_patch(FancyBboxPatch((x,y), w, h, boxstyle='round,pad=0.12',
                 fc=fc, ec=ec, lw=2.4, alpha=0.35, zorder=1))
    ax.add_patch(FancyBboxPatch((x,y), w, h, boxstyle='round,pad=0.12',
                 fc='none', ec=ec, lw=2.4, zorder=2))
    ax.text(x+w/2, y+h+0.1, title, ha='center', va='bottom',
            fontsize=9, fontweight='bold', color=ec, zorder=6)

def arr(x1,y1,x2,y2, label='', col='#555', rad=0.0, lw=1.6):
    ax.annotate('', xy=(x2,y2), xytext=(x1,y1),
        arrowprops=dict(arrowstyle='->', color=col, lw=lw,
                        connectionstyle=f'arc3,rad={rad}', mutation_scale=14), zorder=5)
    if label:
        mx,my=(x1+x2)/2,(y1+y2)/2
        ax.text(mx,my,label,ha='center',va='center',fontsize=6.5,color=col,zorder=6,
                bbox=dict(fc='#FAFAFA',ec='none',pad=0.9,alpha=0.9))

# ════════════════════════════════════════════════════════════════════════════
# FRAMES
# ════════════════════════════════════════════════════════════════════════════
frame(0.2, 7.0, 5.4, 6.3,  'Machine locale — 192.168.1.27',     SRC_F, SRC_E)
frame(0.2, 4.6, 5.4, 2.1,  'Mobile — App Flutter GPS',          MOB_F, MOB_E)
frame(6.2, 1.2, 11.4,12.0, 'Serveur ETL & Analytics — 10.14.210.159 (Docker)', ETL_F, ETL_E)
frame(18.2,5.8, 5.5, 7.5,  'Business Central — 10.14.210.119',  BC_F,  BC_E)
frame(6.4, 1.4, 11.0, 4.2, 'Gold & Analytics',                  GLD_F, GLD_E)

# ════════════════════════════════════════════════════════════════════════════
# NOEUDS
# ════════════════════════════════════════════════════════════════════════════

# --- Sources ---
box(0.5,11.8,4.8,1.2, ['data.csv  /  data.json','Fichiers plats ETL_Projet_BC'],
    SRC_F, SRC_E)
box(0.5,10.1,4.8,1.4, ['PostgreSQL local','articles  ·  clients',
                        'salesshipmentLine  ·  salesshipmentHeader'],
    SRC_F, SRC_E)
box(0.5, 8.8,4.8,1.0, ['gestion_logistique_vehicules.json',
                        'vehicules VH-001 ... VH-007'],
    SRC_F, SRC_E)
box(0.5, 7.3,4.8,1.2, ['JSON stagés (Bronze)','transformes par workflows n8n'],
    SRC_F, SRC_E)

# --- Mobile ---
box(0.5, 4.8,4.8,1.7, ['Kodzo Kilometrage  (Flutter GPS)',
                        'POST  distance_update  /  session_end',
                        'ngrok : crank-bootie-proud.ngrok-free.dev'],
    MOB_F, MOB_E)

# --- n8n ---
box(6.5,10.6,10.8,2.3, ['n8n 2.21.7   (ingestion_n8n :5678)',
                          '13 workflows ETL_Projet_BC   —   WF-01BC a WF-10BC',
                          'Ingestion  ·  Transformation (Code JS)  ·  Orchestration'],
    N8N_F, ETL_E, lw=2.2)

# --- MinIO ---
box(6.5, 7.8,5.0,2.3, ['MinIO Bronze   (datalake_minio :9000)',
                         'bronze/etl-projet-bc/',
                         'CDC MD5  ·  versioning horodate'],
    MIN_F, ETL_E)

# --- Proxy ---
box(12.2,7.8,4.8,2.3, ['bc_ntlm_proxy   (:3128)',
                         'Authentification NTLM',
                         'relais HTTP → BC 10.14.210.119'],
    PRX_F, ETL_E)

# --- BC ---
box(18.4,6.0,5.0,6.9, ['Business Central 26.0 OnPrem',
                         'OData API v1.0',
                         '/BC260/api/etlpipeline/',
                         'Extension AL v2.2.0.0',
                         '──────────────',
                         'etlCustomers',
                         'etlArticles',
                         'etlSalesShipmentHeader',
                         'etlSalesShipmentLine',
                         'etlDistances',
                         'etlEcommerceLines'],
    BC2_F, BC_E, lw=2)

# --- PostgreSQL Gold ---
box(6.5,1.6,4.8,3.6, ['PostgreSQL 15   (dwh_postgres :5433)',
                        'schema bc_gold  ·  8 tables',
                        'distances  ·  articles  ·  clients',
                        'shipment_headers  ·  shipment_lines',
                        'ecommerce_lines  ·  vehicles',
                        'incident_log'],
    PG_F, GLD_E, lw=1.8)

# --- Metabase ---
box(12.0,1.6,5.0,3.6, ['Metabase   (analytics_metabase :3000)',
                         '3 dashboards ETL_Projet_BC',
                         'Cockpit Logistique  #21',
                         'Ventes  #19',
                         'Direction  #20',
                         'Liens publics + acces ngrok'],
    MB_F, GLD_E, lw=1.8)

# ════════════════════════════════════════════════════════════════════════════
# FLECHES
# ════════════════════════════════════════════════════════════════════════════
# Sources → n8n
arr(5.3,12.4, 6.5,12.2, 'WF-01BC  CSV/JSON',       SRC_E, rad=0.1)
arr(5.3,10.8, 6.5,12.0, 'WF-03BC  PostgreSQL',      SRC_E, rad=0.1)
arr(5.3, 9.3, 6.5,11.8, 'WF-06    vehicules',       SRC_E, rad=0.15)
arr(5.3, 7.9, 6.5,11.5, 'WF-08x   JSON stages',    SRC_E, rad=0.25)

# Mobile → n8n
arr(5.3, 5.7, 6.5,11.2, 'HTTPS POST  distance_update', MOB_E, rad=-0.15)

# n8n → MinIO
arr(9.0,10.6, 9.0, 10.1, 'CDC  versioning\n(Bronze)', ETL_E)

# n8n → proxy
arr(13.0,10.6, 13.5,10.1, 'WF-08A-F + 08D\nOData POST/PATCH', BC_E, rad=0.1)

# proxy → BC
arr(17.0, 8.9, 18.4, 9.5, 'NTLM HTTP', BC_E)

# BC → proxy → n8n (lecture WF-09BC)
arr(18.4,8.5, 17.0,8.5, 'lecture OData', BC_E, rad=0.25)
arr(12.2,8.5, 10.0,8.5, 'WF-09BC recu', GLD_E)

# n8n → Gold
arr(9.5,10.6, 8.9, 5.2, 'WF-09BC  upsert bc_gold', GLD_E, rad=-0.2)

# Gold → Metabase
arr(11.3, 3.4, 12.0, 3.4, 'SQL  /  vues bc_gold', GLD_E)

# Metabase → sortie
arr(17.0, 3.4, 18.0, 3.4, '', GLD_E)
ax.text(18.1, 3.4, 'Dashboards\npublics / ngrok',
        va='center', fontsize=7.5, color=GLD_E)

# ════════════════════════════════════════════════════════════════════════════
# TITRE & LEGENDE
# ════════════════════════════════════════════════════════════════════════════
ax.text(12, 13.7, 'Architecture du Flux Complet — ETL_Projet_BC',
        ha='center', va='center', fontsize=15, fontweight='bold', color='#111')

legende = [
    mpatches.Patch(fc=SRC_F, ec=SRC_E, label='Sources (192.168.1.27)'),
    mpatches.Patch(fc=MOB_F, ec=MOB_E, label='Mobile GPS (Flutter)'),
    mpatches.Patch(fc=ETL_F, ec=ETL_E, label='Serveur ETL 10.14.210.159'),
    mpatches.Patch(fc=BC_F,  ec=BC_E,  label='Business Central 10.14.210.119'),
    mpatches.Patch(fc=GLD_F, ec=GLD_E, label='Gold & Analytics'),
]
ax.legend(handles=legende, loc='lower center', ncol=5, fontsize=8.5,
          framealpha=0.95, bbox_to_anchor=(0.5, -0.01))

plt.tight_layout(pad=0.2)
out = '/home/nyanu/Documents/ETL_Projet_BC/docs/architecture_flux.png'
plt.savefig(out, dpi=180, bbox_inches='tight', facecolor='#FAFAFA')
print(f'OK : {out}')
