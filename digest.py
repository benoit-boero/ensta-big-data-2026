from pyspark.sql import SparkSession
from pyspark.sql.functions import to_date
from pyspark.sql import SparkSession


def make_rs_data_path(year):
    return "./data/data-rs-"+str(year)+"/*NB_SURFACE.txt"


def make_weather_data_path(year):
    return "./data/meteo-"+str(year)


def ingest_data():
    spark = SparkSession \
        .builder \
        .config("spark.driver.memory", "4g") \
        .config("spark.executor.memory", "4g") \
        .getOrCreate()

    rs_path_list = [
        make_rs_data_path(i) for i in range(2016, 2025)
    ]

    # Ingestion des donées de surface du réseau:
    df_rs = spark.read\
        .option("header", True)\
        .option("sep", "\t")\
        .csv(rs_path_list)\
        .orderBy("jour")\
        .withColumn(
                "date_parsed",
                to_date("jour", "dd/MM/yyyy")
        )

    weather_path_list = [
        make_weather_data_path(i) for i in range(2016, 2025)
    ]

    # Ingestion des données météo
    df_weather = spark.read\
        .option("header", True)\
        .option("sep", ";")\
        .csv(weather_path_list)\
        .orderBy("date")\
        .select("date", "rr")\
        .withColumn(
                "date_parsed",
                to_date("date", "yyyyMMdd")
        )

    # Jointure
    df_joined = df_rs.join(df_weather, on="date_parsed", how="left")

    print("Number of rs rows:", df_rs.count())
    df_rs.show()
    print("Number of weather rows:", df_weather.count())
    df_weather.show()
    print("Number of joined rows:", df_joined.count())
    df_joined.show()

    # Écriture des données au format parquet
    parquet_dir = "./data-parquet"
    print("Ouputing the full aggregated dataset as parquet in", parquet_dir)
    df_joined.write.mode("overwrite").parquet(parquet_dir)

    # Écriture d'un plus petit dataset pour les tests
    parquet_dir_test = parquet_dir + "-test"
    print("Ouputing a short version (500000 lines) of \
the dataset as parquet in", parquet_dir_test)
    df_joined.limit(500000).write.mode("overwrite").parquet(parquet_dir_test)

ingest_data()
