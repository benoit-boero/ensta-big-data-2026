# Questions

## 1. Distributed computing principles

Notre pipeline repose sur le principe de **parallélisme de données** : Spark découpe les données en partitions et les traite simultanément sur plusieurs cœurs (ou plusieurs nœuds dans un vrai cluster).

Concrètement, quand on appelle `spark.read.csv(path_list)` avec la liste de tous nos fichiers trimestriels, Spark crée une partition par fichier. Chaque partition est traitée indépendamment (lecture, parsing, conversion de date) sans aucune coordination nécessaire entre les workers à cette étape. C'est du parallélisme embarrassant, ce qui est idéal.

La jointure entre le dataset IDFM et les données météo sur la colonne `date_parsed` est l'opération qui nécessite une coordination : Spark doit regrouper les lignes ayant la même date sur le même executor, ce qui implique un **shuffle**. Dans notre cas, le dataset météo est très petit (environ 3 300 lignes sur 9 ans), ce qui en fait un candidat naturel pour un **broadcast join** : plutôt que de redistribuer les deux tables, on envoie la petite directement à chaque executor, éliminant complètement le shuffle.

Les agrégations (groupBy par jour de semaine, par catégorie de pluie, par ligne) induisent également des shuffles. Les lignes partageant la même clé de regroupement sont envoyées sur le même executor avant réduction.

## 2. Choix du format de stockage

On a choisi **Parquet** comme format de sortie après l'ingestion, et ce choix est central dans notre architecture.

Le CSV aurait été plus simple à inspecter à la main, mais il présente plusieurs problèmes pour notre usage : pas de typage natif (tout est relu comme des chaînes de caractères), pas de compression efficace par défaut, et surtout une lecture en ligne complète même quand on n'utilise qu'une ou deux colonnes. Sur un dataset de plusieurs dizaines de millions de lignes, lire toutes les colonnes juste pour calculer une moyenne sur `NB_VALD` et `rr` est un gaspillage important.

Parquet est un format **orienté colonne** ce qui permet de ne lire physiquement que les colonnes nécessaires à la requête. Il inclut aussi la compression par colonne (via Snappy ou Gzip) et embarque le schéma, ce qui évite de le ré-inférer à chaque lecture. Pour nos analyses (agrégations sur quelques colonnes d'une large table), c'est exactement le bon compromis.
