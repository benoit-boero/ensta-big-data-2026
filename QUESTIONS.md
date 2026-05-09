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

## 3. Optimisations appliquées et envisagées

**Ce qu'on a fait :**

- **DataFrame API plutôt que RDDs** : on bénéficie de l'optimiseur Catalyst (plan d'exécution logique → physique optimisé) et du moteur Tungsten (génération de bytecode, gestion mémoire off-heap). Écrire la même logique en RDD aurait été plus lent et beaucoup plus verbeux.
- **Export Parquet** : les analyses en aval ne relisent que les colonnes dont elles ont besoin, ce qui réduit drastiquement l'I/O.
- **Dataset de test réduit** (500 000 lignes) : pendant le développement, on itère sur le petit dataset pour ne pas relancer le pipeline complet à chaque modification.

**Ce qu'on aurait fait avec plus de temps :**

- **Broadcast join explicite** sur `df_weather` : `df_rs.join(broadcast(df_weather), on="date_parsed")`. Avec une table météo de 3 300 lignes, le gain serait significatif.
- **Partitionnement du Parquet par année** : `.partitionBy("year")` à l'écriture, pour que les requêtes filtrées sur une année précise ne lisent pas les autres partitions (partition pruning).
- **Caching du Parquet jointé** : on relit plusieurs fois le même dataset pour différentes analyses. Un `df.cache()` après le premier chargement éviterait les relectures disque répétées.
- **Predicate pushdown au niveau CSV** : filtrer les dates inutiles dès la lecture, avant même de charger les données en mémoire.

## 4. Ce qui casserait avec un dataset 100× plus grand

À volume ×100, plusieurs points du pipeline actuel deviendraient problématiques :

**Exécution locale** : on tourne avec `spark.driver.memory = 4g` sur une seule machine. À cette échelle, il faudrait un vrai cluster (Spark sur YARN, EMR, Dataproc) avec plusieurs executors et une mémoire distribuée.

**Les `count()` et `show()` dans `digest.py`** : ces appels rapatrient des métadonnées au driver et peuvent provoquer des OOM. Il faudrait les supprimer ou les remplacer par des estimations approximatives (`approxCountDistinct`).

**Ingestion des CSV bruts** : télécharger et normaliser des centaines de fichiers hétérogènes en bash devient fragile à grande échelle. On migrerait vers un pipeline de streaming (Kafka + Spark Structured Streaming) et on stockerait les données brutes directement dans un data lake objet (S3, GCS) en Parquet ou Delta Lake.

**Le shuffle de la jointure** : sans broadcast, une jointure à grande échelle implique de redistribuer des centaines de Go entre les executors. Il faudrait s'assurer que `spark.sql.shuffle.partitions` est calibré correctement (par défaut 200, souvent trop peu à grande échelle).

## 5. Ce qu'on a retenu du cours

La leçon la plus concrète de ce projet, c'est que **le vrai problème dans un pipeline Big Data ce n'est presque jamais le calcul distribué lui-même — c'est la qualité et l'hétérogénéité des données en entrée**.

On avait anticipé que la partie difficile serait d'écrire du Spark performant. En pratique, on a passé beaucoup plus de temps à comprendre pourquoi certains fichiers de 2022 utilisaient des points-virgules au lieu de tabulations, pourquoi le fichier T4 2024 avait une colonne de plus que les autres, ou pourquoi les dates 2024 étaient écrites `/24` au lieu de `/2024`. Tout ça avant même de lancer une session Spark.

Ça nous a poussés à vraiment soigner `getdata.sh` et à isoler proprement la couche de nettoyage de la couche analytique. Le fait de stocker les données nettoyées en Parquet comme couche intermédiaire stable, indépendante des aléas du format source, n'était pas une évidence au départ, c'est quelque chose qu'on a compris en pratiquant.

