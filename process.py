from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum, dayofweek, avg, translate, count, \
        year, lower, when
from pyspark.ml.feature import Bucketizer
from functools import reduce

# Create Spark session
spark = SparkSession.builder \
    .appName("Weekly Validation Analysis") \
    .getOrCreate()

# Load parquet data
df = spark.read.parquet("data-parquet")
df = df.withColumn(
    "nb_validation_clean",
    col("nb_vald").try_cast("int")
    ).fillna({"nb_validation_clean": 0})


def compare_week_and_weekend():
    # Extract day of week (1=Sunday, 7=Saturday)
    df_labelled = df.withColumn("day_of_week", dayofweek(col("date_parsed")))

    # Aggregate total validations per day
    df_daily = df_labelled.groupBy("date_parsed", "day_of_week").agg(
        sum("nb_validation_clean").alias("total_validations")
    )

    # Compute average per day of week
    df_result = df_daily.groupBy("day_of_week").agg(
        avg("total_validations").alias("avg_validations")
    ).orderBy("day_of_week")

    # Show result
    df_result.show()

    # Optional: write result
    # df_result.write.mode("overwrite").parquet("weekly_avg_validations")


def compare_rainy_days_and_sunny_days():
    df_clean = df.withColumn(
        "rr_clean",
        translate(col("rr"), ",", ".").try_cast("float")
    ).fillna({"rr_clean": 0})

    splits = [0, 1, 15, float("inf")]

    bucketizer = Bucketizer(
        splits=splits,
        inputCol="rr_clean",
        outputCol="rain_bucket_id"
    )

    df_bucketed = bucketizer.transform(df_clean)

    df_daily = df_bucketed.groupBy("date", "rain_bucket_id").agg(
        sum("nb_validation_clean").alias("total_validations")
    )

    df_result = df_daily.groupBy("rain_bucket_id").agg(
        avg("total_validations").alias("avg_validations"),
        count("*").alias("num_days")
    ).orderBy("rain_bucket_id")

    df_result.show()


def compare_rainy_days_and_sunny_days_per_title():
    df_clean = df.withColumn(
        "rr_clean",
        translate(col("rr"), ",", ".").try_cast("float")
    ).fillna({"rr_clean": 0})

    splits = [0, 1, 15, float("inf")]

    bucketizer = Bucketizer(
        splits=splits,
        inputCol="rr_clean",
        outputCol="rain_bucket_id"
    )

    df_bucketed = bucketizer.transform(df_clean)

    df_bucketed = df_bucketed.withColumn(
            "categorie_clean",
            when(lower(col("categorie_titre"))
                 .like("%solidarit%"), "contrat solidarite")
            .when(lower(col("categorie_titre"))
                  .like("%autre%"), "autre titre")
            .otherwise(lower(col("categorie_titre")))
            )

    df_daily = df_bucketed\
        .groupBy("date", "rain_bucket_id", "categorie_clean").agg(
            sum("nb_validation_clean").alias("total_validations")
            )

    df_result = df_daily.groupBy("rain_bucket_id", "categorie_clean").agg(
        avg("total_validations").alias("avg_validations"),
        count("*").alias("num_days")
    ).orderBy("categorie_clean", "rain_bucket_id")

    df_result.show(n=100, truncate=False)


def most_frequented_lines():
    df_yeared = df.withColumn("annee", year(col("date_parsed")))

    df_line_year = df_yeared\
        .groupBy("annee", "code_stif_ligne", "libelle_ligne").agg(
            sum("nb_validation_clean").alias("total_validations")
        )

    # Pivot : transforme les années en colonnes
    df_pivot = df_line_year.groupBy("code_stif_ligne", "libelle_ligne")\
        .pivot("annee").sum("total_validations")

    # Remplace les nulls par 0 pour le calcul
    years = [str(y) for y in range(2016, 2024)]
    df_pivot = df_pivot.fillna({y: 0 for y in years})

    # Ajoute une colonne total sur toutes les années
    df_pivot = df_pivot\
        .withColumn("total_all_years",
                    reduce(lambda a, b: a + b, [col(y) for y in years])
                    )

    # Trie par total
    df_pivot.orderBy(col("total_all_years").desc()).show()


def switcher():
    redo = True
    while (redo):
        print("\n\nChose what processing you want to do:")
        print("1) Compare week days and weekends")
        print("2) Compare rainy days and sunny days")
        print("3) Compare rainy days and sunny days but grouping by membership\
 type")
        print("4) Compare line frequentation")
        print("q) exit")
        x = input()
        match x:
            case "1":
                compare_week_and_weekend()
            case "2":
                compare_rainy_days_and_sunny_days()
            case "3":
                compare_rainy_days_and_sunny_days_per_title()
            case "4":
                most_frequented_lines()
            case "q":
                redo = False
            case _:
                pass


switcher()
