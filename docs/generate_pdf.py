#!/usr/bin/env python3
import sys
from weasyprint import HTML, CSS

html_path = '/home/nyanu/Documents/ETL_Projet_BC/docs/rapport_final.html'
pdf_path  = '/home/nyanu/Documents/ETL_Projet_BC/docs/rapport_final.pdf'

print(f'Génération du PDF depuis {html_path} ...')
HTML(filename=html_path).write_pdf(pdf_path)
print(f'PDF généré : {pdf_path}')
