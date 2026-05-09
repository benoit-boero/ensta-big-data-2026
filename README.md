# Prerequisites

You need `numpy` and `pySpark`.
You can probably just run from your virtual env :
```bash
pip install numpy pyspark
```

# Instruction to get the data

Get a Météo France API Key, then run

```
./get_data.sh $API_KEY
```

# Instruction to digest the data

With PySpark installed, run

```
python3 digest.py
```

# Instruction to analyse the data


Simply run `./venv/bin/python3 process.py` and follow the instruction (after waiting for a while so the data has time to get loaded).
Of course, you first need to fetch the data with `get_data.sh` and to digest it with `diget.py`.
