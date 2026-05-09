# Analyse de la fréquentation des transports en commun en Île-de-France
 
Wiam Benrguibi & Benoit Boero  — ENSTA Paris, Big Data 2025-2026
 
---
 
## Contexte
 
Île-de-France Mobilités (IDFM) coordonne l'ensemble du réseau de transport francilien : 85 opérateurs, 1 900 lignes, 40 000 arrêts. Chaque passage en validation est enregistré, ce qui produit une volumétrie de données considérable sur plusieurs années.
 
On s'est posé deux questions concrètes :
 
- Comment évolue la fréquentation du réseau de surface (bus, tramway) selon le jour de la semaine, la ligne, et l'année ?
- Est-ce que la pluie a un effet mesurable sur le nombre de validations quotidiennes ?
L'idée derrière la deuxième question est simple : par temps de pluie, les gens qui hésitent entre marcher ou prendre le bus vont davantage valider. On voulait vérifier si ça se voit dans les données à l'échelle de toute l'Île-de-France sur 9 ans.
 
## Dataset
 
### Validations réseau de surface — IDFM
 
- **Source** : https://data.iledefrance.fr/explore/dataset/histo-validations-reseau-surface/
- **Format** : fichiers texte séparés par tabulations (TSV), un fichier par trimestre par année, distribués en archives ZIP
- **Couverture** : 2016 à 2024 inclus
- **Colonnes principales** : `jour` (date), `CODE_STIF_LINE` (identifiant ligne), `ID_TITRE` (type de titre), `NB_VALD` (nombre de validations)
- **Taille** : --
- **Point d'attention** : le format n'est pas homogène d'une année à l'autre. Certains fichiers utilisent `;` comme séparateur, d'autres des tabulations. Certains trimestres ont des colonnes supplémentaires. Les formats de date varient. Tout ça est corrigé dans `getdata.sh` avant d'attaquer Spark.

## Prerequisites

You need `numpy` and `pySpark`.
You can probably just run from your virtual env :
```bash
pip install numpy pyspark
```

## Instruction to get the data

Get a Météo France API Key, then run

```
./get_data.sh $API_KEY
```

## Instruction to digest the data

With PySpark installed, run

```
python3 digest.py
```

## Instruction to analyse the data


Simply run `./venv/bin/python3 process.py` and follow the instruction (after waiting for a while so the data has time to get loaded).
Of course, you first need to fetch the data with `get_data.sh` and to digest it with `diget.py`.
