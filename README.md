# Impact de la météo sur les validations des transports en Île-de-France

## Contexte
 
Île-de-France Mobilités (IDFM) coordonne l'ensemble du réseau de transport francilien : 85 opérateurs, 1 900 lignes, 40 000 arrêts. Chaque passage en validation est enregistré, ce qui produit une volumétrie de données considérable sur plusieurs années.
 
On s'est posé deux questions concrètes :
 
- Comment évolue la fréquentation du réseau de surface (bus, tramway) selon le jour de la semaine, la ligne, et l'année ?
- Est-ce que la pluie a un effet mesurable sur le nombre de validations quotidiennes ?
L'idée derrière la deuxième question est simple : par temps de pluie, les gens qui hésitent entre marcher ou prendre le bus vont davantage valider. On voulait vérifier si ça se voit dans les données à l'échelle de toute l'Île-de-France sur 9 ans.
 
---

# Dataset

## Validations réseau de surface — IDFM
 
- **Source** : https://data.iledefrance.fr/explore/dataset/histo-validations-reseau-surface/
- **Format** : fichiers texte séparés par tabulations (TSV), un fichier par trimestre par année, distribués en archives ZIP
- **Couverture** : 2016 à 2024 inclus
- **Colonnes principales** : `jour` (date), `CODE_STIF_LINE` (identifiant ligne), `ID_TITRE` (type de titre), `NB_VALD` (nombre de validations)
- **Taille** : 2Go
- **Point d'attention** : le format n'est pas homogène d'une année à l'autre. Certains fichiers utilisent `;` comme séparateur, d'autres des tabulations. Certains trimestres ont des colonnes supplémentaires. Les formats de date varient. Tout ça est corrigé dans `getdata.sh` avant d'attaquer Spark.

### Format
Parquet.

### Colonnes principales

| Colonne | Description |
|---|---|
| date | Date |
| date_parsed | Date convertie |
| nb_vald | Nombre de validations |
| categorie_titre | Type de titre |
| code_stif_ligne | Code ligne |
| libelle_ligne | Nom ligne |

---

## Données météo

### Colonnes principales

| Colonne | Description |
|---|---|
| rr | Niveau de précipitations |
| temperature | Température |
| humidity | Humidité |
| wind_speed | Vitesse du vent |

---

# Méthodologie

Le projet utilise PySpark afin de traiter efficacement un grand volume de données.

## Pipeline

1. Chargement des données Parquet ;
2. Nettoyage des données ;
3. Transformation des colonnes ;
4. Agrégation des validations ;
5. Analyse statistique.

---

## Nettoyage des données

Conversion des validations :

```python
df = df.withColumn(
    "nb_validation_clean",
    col("nb_vald").try_cast("int")
).fillna({"nb_validation_clean": 0})
```

Nettoyage des précipitations :

```python
df_clean = df.withColumn(
    "rr_clean",
    translate(col("rr"), ",", ".").try_cast("float")
).fillna({"rr_clean": 0})
```

---

# Analyses réalisées

## 1. Comparaison semaine / week-end

Utilisation de `dayofweek()` afin de calculer la fréquentation moyenne selon les jours de la semaine.

Fonctions utilisées :

- `dayofweek`
- `groupBy`
- `sum`
- `avg`

---

## 2. Impact de la pluie

Les jours sont classés selon le niveau de précipitations grâce à `Bucketizer`.

| Catégorie | Intervalle |
|---|---|
| Faible pluie | 0 - 1 mm |
| Pluie moyenne | 1 - 15 mm |
| Forte pluie | > 15 mm |

---

## 3. Impact selon le type de titre

Analyse des validations par catégorie de titre :

- contrat solidarité ;
- autre titre ;
- abonnements classiques.

---

## 4. Lignes les plus fréquentées

Agrégation des validations :

- par année ;
- par ligne ;
- puis pivot des résultats pour comparer les fréquentations annuelles.

---

# Technologies utilisées

| Technologie | Utilisation |
|---|---|
| Python | Développement |
| PySpark | Traitement Big Data |
| Apache Spark | Calcul distribué |
| Parquet | Stockage optimisé |

---

# Résultats

Les analyses montrent que :

- les week-ends ont une fréquentation plus faible ;
- les jours de pluie réduisent le nombre de validations ;
- certains types de titres sont plus sensibles aux conditions météo ;
- certains lignes sont plus fréquentées que d'autres ;

---

# Exécution du projet

## Prérequis

- Python 3.10+
- Apache Spark 3+
- Java 11+
- Numpy

---

## Installation

```
pip install pyspark numpy
```

---

## Récupération des données

Se munir d'une clef API météo france (il faut créer un compte sur le site).
```bash
bash get_data.sh $API_KEY
---

## Digestion des données
```bash
python digest.py
```


## Lancement

```bash
python process.py
```


### Menu disponible :

```text
1) Compare week days and weekends
2) Compare rainy days and sunny days
3) Compare rainy days and sunny days but grouping by membership type
4) Compare line frequentation
q) exit
```


---


# Structure du projet

```text
project/
│
├── data-parquet/
├── get_data.sh
├── digest.py
├── process.py
├── QUESTIONS.md
└── README.md
```

---

# Dépendances

| Librairie | Version |
|---|---|
| pyspark | 3.x |
| Python | 3.10+ |
| numpy | 2.4+ |

---

# Perspectives

- Ajouter des visualisations graphiques ;
- Intégrer davantage de variables météo ;
- Construire un modèle prédictif de fréquentation.

---

# Auteurs

Projet réalisé dans le cadre du module Big Data par Wiam Benrguibi et Benoit Boero.
