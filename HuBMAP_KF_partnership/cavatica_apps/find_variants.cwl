{
  "class": "CommandLineTool",
  "cwlVersion": "v1.2",
  "$namespaces": {
    "sbg": "https://sevenbridges.com"
  },
  "baseCommand": [
    "spark-submit"
  ],
  "inputs": [
    {
      "loadListing": "deep_listing",
      "id": "input_unique_variant_set",
      "type": "Directory",
      "inputBinding": {
        "prefix": "--input_unique_variant_set",
        "shellQuote": false,
        "position": 0
      },
      "label": "input_unique_variant_set"
    },
    {
      "id": "cpu",
      "type": "int?",
      "default": 25
    },
    {
      "id": "ram",
      "type": "int?",
      "default": 80
    },
    {
      "loadListing": "deep_listing",
      "id": "input_gvcf_parquet",
      "type": "Directory?",
      "inputBinding": {
        "prefix": "--input_gvcf_parquet",
        "shellQuote": false,
        "position": 0
      }
    },
    {
      "loadListing": "deep_listing",
      "id": "input_bed",
      "type": "Directory?",
      "inputBinding": {
        "prefix": "--input_bed",
        "shellQuote": false,
        "position": 0
      }
    },
    {
      "id": "executor_mem",
      "type": "int?"
    },
    {
      "id": "shuffle_partitions",
      "type": "int?",
      "default": 498
    }
  ],
  "outputs": [
    {
      "id": "variant_genotype",
      "type": "Directory?",
      "outputBinding": {
        "glob": "*.parquet",
        "loadListing": "deep_listing"
      }
    },
    {
      "id": "output",
      "type": "File?",
      "outputBinding": {
        "glob": "*.txt"
      }
    },
    {
      "id": "out_log",
      "type": "File?",
      "outputBinding": {
        "glob": "*.log"
      }
    }
  ],
  "label": "find_variants",
  "arguments": [
    {
      "prefix": "",
      "shellQuote": false,
      "position": -2,
      "valueFrom": "--driver-memory $(inputs.ram)G find_variants.py"
    },
    {
      "prefix": "",
      "shellQuote": false,
      "position": -3,
      "valueFrom": "--conf \"spark.sql.shuffle.partitions=$(inputs.shuffle_partitions)\""
    },
    {
      "prefix": "",
      "shellQuote": false,
      "position": -3,
      "valueFrom": "--executor-cores 4"
    }
  ],
  "requirements": [
    {
      "class": "ShellCommandRequirement"
    },
    {
      "class": "LoadListingRequirement"
    },
    {
      "class": "ResourceRequirement",
      "ramMin": 80,
      "coresMin": 25
    },
    {
      "class": "DockerRequirement",
      "dockerPull": "pgc-images.sbgenomics.com/stearb2/bens-docker-repository:latest"
    },
    {
      "class": "InitialWorkDirRequirement",
      "listing": [
        {
          "entryname": "find_variants.py",
          "entry": "\"\"\"\nScript to filter a parquet file using a BED file\n\"\"\"\nimport argparse\nfrom argparse import RawTextHelpFormatter\nimport pyspark\nimport sys\nimport os\nimport time\nimport pandas as pd\n#import pyranges as pr\nimport numpy as np\nfrom collections import Counter\nfrom pyspark.sql import SparkSession\nfrom pyspark import SparkConf\nfrom pyspark.sql.functions import col,collect_list, concat, lit, when, monotonically_increasing_id, concat_ws,broadcast \nimport pyspark.sql.functions as F\n#from pyspark.sql.types import StructType,StructField, StringType,IntegerType, FloatType, BooleanType, ArrayType\n#import scipy.sparse as ss\nimport logging\n\n'''\nimport  traceback # logging, sys,\nlogger = logging.getLogger('logger')\nfh = logging.FileHandler('test.log')\nlogger.addHandler(fh)\ndef exc_handler(exctype, value, tb):\n    logger.exception(''.join(traceback.format_exception(exctype, value, tb)))\nsys.excepthook = exc_handler'''\n\nparser = argparse.ArgumentParser( description = 'Script to filter parquet files. \\n\\\nMUST BE RUN WITH spark-submit. For example: \\n\\\n    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \\n\\\n    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \\n\\\n    --driver-memory 60G asd_parquet_filter.py',\n    formatter_class=RawTextHelpFormatter)\n    \nparser.add_argument('--input_unique_variant_set', help='set of variants/locations to search genotypes for')\nparser.add_argument('--input_gvcf_parquet', help='Parquet VCF File')\nparser.add_argument('--input_bed', help='Bed file to use for filtering Parquet Files')\nargs = parser.parse_args()\ninput_unique_variant_set = args.input_unique_variant_set\ninput_gvcf_parquet = args.input_gvcf_parquet\ninput_bed = args.input_bed\n\nspark = SparkSession.builder.master(\"local[*]\").appName(\"Find_Variants\").getOrCreate()\n\n#bs_name = str(input_gvcf_parquet).split('/')[-1].split('.')[0]\n\n#time.sleep(20)\n#print(spark.sparkContext.getConf().getAll())\n'''\ntime.sleep(30)\nprint(os.cpu_count())\nexecutor_count = len(spark.sparkContext._jsc.sc().statusTracker().getExecutorInfos()) - 1\nprint(executor_count)\ncores_per_executor = int(spark.sparkContext.getConf().get('spark.executor.cores','1'))\nprint(cores_per_executor)'''\n\nprint('Sleeping for 1 min.'); time.sleep(30)\n\n\nlength_chr_15=101991189 \nnb_buckets = 100\nlength_bucket = length_chr_15 // nb_buckets\n\n# This will just be a vector of unique_variant_locations\nvariants = spark.read.parquet(input_unique_variant_set)\nvariants = variants.withColumn('unique_location',concat(col(\"chromosome\"),\n                            lit(\":\"),col(\"start\"),lit(\":\"),col(\"end\")))\n\ndf = spark.read.parquet(input_gvcf_parquet)\n\ndf = df.select(col('contigName').alias('chromosome'),'start','end',col('referenceAllele').alias('reference'),\n            col('alternateAlleles').alias('alternate'),'qual','INFO_DP', 'splitFromMultiAllelic','genotypes') \\\n        .withColumn('alternate',F.explode('alternate')) \\\n        .withColumn('chromosome',F.regexp_replace(col(\"chromosome\"), \"[chr,]\", \"\") ) \\\n        .withColumn(\"start\", df[\"start\"]+1) \\\n        .withColumn('unique_variant_id',concat(col(\"chromosome\"), lit(\":\"),col(\"start\"),lit(':'),col('reference'),lit(':'),col('alternate'))) \\\n        .withColumn('unique_location',concat(col(\"chromosome\"), lit(\":\"),col(\"start\"),lit(\":\"),col(\"end\"))) \\\n        .withColumn('bucket', F.floor(col('end') / length_bucket))\n\nvariants_noneqtl = variants#.where(col('eqtl_boolean') == 0)\n\ndf = df.repartition(1000, \"chromosome\", \"bucket\")\n\ndf = df.where(~ ((df.splitFromMultiAllelic == 'true') & (df.alternate == '<NON_REF>') ))\n\n\nvariants_noneqtl = variants_noneqtl.select(col('chromosome').alias('var_chrom'),\n                                    col('start').alias('var_start'), F.floor(col('start') / length_bucket).alias('var_bucket'), col('end').alias('var_end'),col('unique_variant_id').alias('var_unique_variant_id'))\n\n\nprint('starting join...'); \n\nvariants_noneqtl = variants_noneqtl.repartition(1000, \"var_chrom\", \"var_bucket\")\n\ndf_join = df.join(variants_noneqtl, \n              (df['chromosome'] == variants_noneqtl['var_chrom']) &\\\n              (df['bucket'] == variants_noneqtl['var_bucket']) &\\\n              (df['start'] <= variants_noneqtl['var_start']) &\\\n              (df['end'] >= variants_noneqtl['var_start']),'right' ) \n              \n#print(df.count())\n\ndf_join = df_join.repartition(10,  \"var_bucket\")\n\ndf_join = df_join.withColumn('calls', df_join.genotypes.getItem(0).getItem('6'))\ndf_join = df_join.withColumn('calls_str',concat(df_join.calls.getItem(0), lit(\":\"), df_join.calls.getItem(1) ))\ndf_join = df_join.withColumn('AdditiveGenotype',when(df_join.calls_str.contains('-')  ,-9)\\\n                      .otherwise(df_join.calls.getItem(0) + df_join.calls.getItem(1)))\n\n# 'var_chrom','var_start','var_end','var_unique_variant_id','unique_location'\ndf_join = df_join.drop('calls','calls_str')           \n\n# Create Participant ID column (should just be one participant per file)\n#df_join = df_join.withColumn('participant_id', df_join.genotypes.getItem(0).getItem('0'))\ndf_join = df_join.withColumn('INFO_DP',df_join.genotypes.getItem(0).getItem('10'))\ndf_join = df_join.withColumn('qual',df_join.genotypes.getItem(0).getItem('1'))\ndf_join = df_join.withColumn('PL',df_join.genotypes.getItem(0).getItem('9'))\n\ndf_join = df_join.withColumn('AdditiveGenotype',when((df_join.INFO_DP < 15) | (df_join.qual < 25) ,-9)\\\n                      .otherwise(df_join.AdditiveGenotype))\n                      \ndf_join = df_join.where(~ ((df_join.splitFromMultiAllelic == 'true') & (df_join.alternate == '<NON_REF>') ))\n#df_join = df_join.drop(*(\"splitFromMultiAllelic\")).dropDuplicates(['unique_variant_id','AdditiveGenotype'])\n\ndf_join = df_join.withColumn('PL_00',df_join.PL.getItem(0)).withColumn('PL_01',df_join.PL.getItem(1)).withColumn('PL_11',df_join.PL.getItem(2))\n\ndf_join = df_join.withColumn('AdditiveGenotype',when((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\\\n                                           (col('AdditiveGenotype') == 0 ),-9).otherwise(df_join.AdditiveGenotype))\n                                           \ndf_join = df_join.withColumn('AdditiveGenotype',when(((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\\\n                     (df_join.PL_11 == 0)) & (col('AdditiveGenotype') == 0 ) ,-9).otherwise(df_join.AdditiveGenotype))\n\ndf_join = df_join.drop(*(\"PL\",\"PL_00\",\"PL_01\",\"PL_11\",\"splitFromMultiAllelic\",\"genotypes\",\"INFO_DP\",\"qual\"))           \ndf_join = df_join.na.fill(value=-9,subset=[\"AdditiveGenotype\"])\n\n#dfj_cnt = df_join.count()\n#print(dfj_cnt)\n\n\n#[i for i in df_join.columns if not i.startswith('buck')]\ndf_join.write.mode('overwrite').partitionBy(\"chromosome\").parquet('jeremy_results_aug7.parquet') \n# .repartition(10,'chromosome','bucket')\n# .repartitionByRange(30, \"chromosome\", \"start\")\n\nsys.exit()\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nt0 = time.time()\n\n# This will just be a vector of unique_variant_locations\nvariants = spark.read.parquet(input_unique_variant_set)\nvariants = variants.withColumn('unique_location',concat(col(\"chromosome\"),\n                            lit(\":\"),col(\"start\"),lit(\":\"),col(\"end\")))\\\n\n#var_len = variants.count()   \n\ndf = spark.read.parquet(input_gvcf_parquet)\n\ndf = df.select(col('contigName').alias('chromosome'),'start','end',col('referenceAllele').alias('reference'),\n            col('alternateAlleles').alias('alternate'),'qual','INFO_DP', 'splitFromMultiAllelic','genotypes')\\\n        .withColumn('alternate',F.explode('alternate')).withColumn('chromosome',F.regexp_replace(col(\"chromosome\"), \"[chr,]\", \"\") ).withColumn(\"start\", df[\"start\"]+1)\\\n        .withColumn('unique_variant_id',concat(col(\"chromosome\"),lit(\":\"),col(\"start\"),lit(':'),col('reference'),lit(':'),col('alternate'))).withColumn('unique_location',concat(col(\"chromosome\"),\n                            lit(\":\"),col(\"start\"),lit(\":\"),col(\"end\")))\n                            \ntend_read = time.time() - t0            \n\n\n\n#df = df.where(~ (col('alternate') == '<NON_REF>'))\n##################################################################\n\n#df = df.repartition(300, \"chromosome\", \"start\")\n#df = df.where(col('chromosome') == '15') \n#print(df.count()); time.sleep(10)\n\ndf = df.repartitionByRange(2400, \"chromosome\", \"start\")\n#print('done repartitioning...'); time.sleep(5)\n#print('Number of partitions: '+str(df.rdd.getNumPartitions()))\n\nt0  = time.time()\nvariants_noneqtl = variants.where(col('eqtl_boolean') == 0)\n\n#variants_noneqtl = variants_noneqtl.repartition(30, \"chromosome\", \"start\")\n#variants_noneqtl = variants_noneqtl.coalesce(1)\n#assert variants_noneqtl.rdd.getNumPartitions() == 1\n#vnon_cnt = variants_noneqtl.count()\n#print(f'Done removing eqtl variants from search space... Non-eqtl count: {vnon_cnt}'); #time.sleep(5)\nt_var_noneqtl = time.time() - t0\n\nt0 = time.time(); \n  \n#c = df_chrom.count()\n#variants_noneqtl = variants_noneqtl.where(col('chromosome') == '15')  #c2 = var_chrom.count()\n#vnon_cnt_dedup = var_chrom.dropDuplicates().count()\nvariants_noneqtl = variants_noneqtl.select(col('chromosome').alias('var_chrom'),\n                                    col('start').alias('var_start'), col('end').alias('var_end'),col('unique_variant_id').alias('var_unique_variant_id'))\n\nvariants_noneqtl = variants_noneqtl.repartitionByRange(30, \"var_chrom\", \"var_start\")\n#variants_noneqtl = variants_noneqtl.repartition(100, \"chromosome\", \"start\")\n#variants_noneqtl = variants_noneqtl.coalesce(1)\n#var_chrom1 = variants_noneqtl.where(col('var_chrom') == '1')\n#var_chrom1.cache()\n#variants_noneqtl.cache()    \n\n#df_chrom1 = df.where(col('chromosome') == '1')\n\ntend_subset = time.time() - t0;                                            \n\nt0 = time.time();   \n# search for direct matches and then drop them from each df,\n'''df_join = df_chrom1.join(broadcast(var_chrom1), \n              (df_chrom1['chromosome'] == var_chrom1['var_chrom']) &\\\n              (df_chrom1['start'] <= var_chrom1['var_start']) &\\\n              (df_chrom1['end'] >= var_chrom1['var_start']),'right' )'''\n              \nvariants_noneqtl.count()\n#variants_noneqtl.cache()\ndf.count()\n\nprint('starting join...'); time.sleep(30)\n\ndf_join = df.join(variants_noneqtl, \n              (df['chromosome'] == variants_noneqtl['var_chrom']) &\\\n              (df['start'] <= variants_noneqtl['var_start']) &\\\n              (df['end'] >= variants_noneqtl['var_start']),'right' ) \n        \n'''df_join = variants_noneqtl.join(df, \n              (df['chromosome'] == variants_noneqtl['chromosome']) &\\\n              (df['start'] <= variants_noneqtl['start']) &\\\n              (df['end'] >= variants_noneqtl['start']),'left' )'''              \n\ndfj_cnt = df_join.count()\ntend_filter = time.time() - t0;\n\n\n#df_parts = df.rdd.mapPartitions(lambda it: [sum(1 for _ in it)]).collect()\n#var_parts = variants_noneqtl.rdd.mapPartitions(lambda it: [sum(1 for _ in it)]).collect()\ndf_join_parts = df_join.rdd.mapPartitions(lambda it: [sum(1 for _ in it)]).collect()\n\nwith open('stats.txt', 'w') as f:\n    f.write(f'df_JOIN max/min/mean partition size: max: {max(df_join_parts)}, min: {min(df_join_parts)}, mean: {np.mean(df_join_parts)}\\n')\n    f.write(f'df_JOIN num partitions is {len(df_join_parts)}')\n#    f.write(f'num df partitions: {len(df_parts)}, num var partitions: {len(var_parts)}\\n')\n#    f.write(f'df_parts: {df_parts}\\n')\n#    f.write(f'var_parts: {var_parts}\\n')\n#    f.write(f'df max/min/mean partition size: max: {max(df_parts)}, min: {min(df_parts)}, mean: {np.mean(df_parts)}\\n')\n#   f.write(f'var max/min/mean partition size: max: {max(var_parts)}, min: {min(var_parts)}, mean: {np.mean(var_parts)}\\n')\n\n#with open('stats.txt', 'w') as f:\n#    f.write(f' join took {tend_filter/60} minutes and df is {dfj_cnt} rows long\\n')\n#    f.write(f' df len: {df.count()}  and var len: {variants_noneqtl.count()}\\n')\n    \n#df_join.write.parquet('find_variants_test_july28.parquet')\n#df_join = df_join.coalesce(1)\n\n\n############################\n###### Post processing #####\n############################\n#print('\\n\\n\\POST PROCESSING...\\n\\n\\n'); time.sleep(20)\ndf_join = df_join.withColumn('calls', df_join.genotypes.getItem(0).getItem('6'))\\\n        .withColumn('calls_str',concat(df_join.calls.getItem(0), lit(\":\"), df_join.calls.getItem(1) ))\\\n        .withColumn('AdditiveGenotype',when(df_join.calls_str.contains('-')  ,-9)\\\n                  .otherwise(df_join.calls.getItem(0) + df_join.calls.getItem(1)))\\\n        .withColumn('participant_id', df_join.genotypes.getItem(0).getItem('0'))\\\n        .withColumn('INFO_DP',df_join.genotypes.getItem(0).getItem('10'))\\\n        .withColumn('qual',df_join.genotypes.getItem(0).getItem('1'))\\\n        .withColumn('PL',df_join.genotypes.getItem(0).getItem('9'))\\\n        .withColumn('AdditiveGenotype',when((df_join.INFO_DP < 15) | (df_join.qual < 25) ,-9)\\\n                  .otherwise(df_join.AdditiveGenotype))\\\n        .where(~ ((df_join.splitFromMultiAllelic == 'true') & (df_join.alternate == '<NON_REF>') ))\\\n        .withColumn('PL_00',df_join.PL.getItem(0)).withColumn('PL_01',df_join.PL.getItem(1))\\\n        .withColumn('PL_11',df_join.PL.getItem(2))\\\n        .withColumn('AdditiveGenotype',when((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\\\n                           (col('AdditiveGenotype') == 0 ),-9).otherwise(df_join.AdditiveGenotype))\\\n        .withColumn('AdditiveGenotype',when(((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\\\n                 (df_join.PL_11 == 0)) & (col('AdditiveGenotype') == 0 ) ,-9).otherwise(df_join.AdditiveGenotype)).drop(*(\"PL\",\"PL_00\",\"PL_01\",\"PL_11\"))\n\n'''\ndf_join = df_join.withColumn('calls', df_join.genotypes.getItem(0).getItem('6'))\ndf_join = df_join.withColumn('calls_str',concat(df_join.calls.getItem(0), lit(\":\"), df_join.calls.getItem(1) ))\ndf_join = df_join.withColumn('AdditiveGenotype',when(df_join.calls_str.contains('-')  ,-9)\\\n                      .otherwise(df_join.calls.getItem(0) + df_join.calls.getItem(1)))\n\n# Create Participant ID column (should just be one participant per file)\ndf_join = df_join.withColumn('participant_id', df_join.genotypes.getItem(0).getItem('0'))\ndf_join = df_join.withColumn('INFO_DP',df_join.genotypes.getItem(0).getItem('10'))\ndf_join = df_join.withColumn('qual',df_join.genotypes.getItem(0).getItem('1'))\ndf_join = df_join.withColumn('PL',df_join.genotypes.getItem(0).getItem('9'))\n\ndf_join = df_join.withColumn('AdditiveGenotype',when((df_join.INFO_DP < 15) | (df_join.qual < 25) ,-9)\\\n                      .otherwise(df_join.AdditiveGenotype))\ndf_join = df_join.where(~ ((df_join.splitFromMultiAllelic == 'true') & (df_join.alternate == '<NON_REF>') ))\n\n#df_join = df_join.sort(['chromosome','start'])\n#df_join = df_join.drop(*(\"splitFromMultiAllelic\")).dropDuplicates(['unique_variant_id','AdditiveGenotype'])\n\ndf_join = df_join.withColumn('PL_00',df_join.PL.getItem(0)).withColumn('PL_01',df_join.PL.getItem(1)).withColumn('PL_11',df_join.PL.getItem(2))\n\ndf_join = df_join.withColumn('AdditiveGenotype',when((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\\\n                                           (col('AdditiveGenotype') == 0 ),-9).otherwise(df_join.AdditiveGenotype))\n                                           \ndf_join = df_join.withColumn('AdditiveGenotype',when(((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\\\n                     (df_join.PL_11 == 0)) & (col('AdditiveGenotype') == 0 ) ,-9).otherwise(df_join.AdditiveGenotype))\n\ndf_join = df_join.drop(*(\"PL\",\"PL_00\",\"PL_01\",\"PL_11\"))\n\n# Maybe drop all -9's bc if its not found its -9 anyway? what % of -9's do we have?\ndf_cnt2 = df_join.count()\n'''\n\n#tend_post_process = time.time() - t0\n\n#with open('stats.txt', 'w') as f:\n#    f.write(f' join took {tend_filter/60} minutes and df is {dfj_cnt} rows long\\n')\n#    f.write(f' post process took {tend_post_process/60} minutes and df is now {df_cnt2} rows long\\n')\n\n\n\n'''\n#print('\\n\\n\\ANTI-JOIN...\\n\\n\\n'); time.sleep(20)\nt0 = time.time()\n# Get list of these vars/locations and get the rows of vars that are not in this list, do anti-join\n# and set these variants to -9 (missiing)\ndf_join = df_join.select(['chromosome','start','end','unique_location',col('unique_variant_id').alias('var_unique_variant_id') ,'AdditiveGenotype'])\n\nunmatched_df = variants_noneqtl.join(df_join, ['var_unique_variant_id'],'left_anti')\nnon_matched_vars = unmatched_df.count()\ndf_select = df_join.select(['var_unique_variant_id','AdditiveGenotype'])\n\nunmatched_select = unmatched_df.select(['var_unique_variant_id']).drop('AdditiveGenotype').withColumn('AdditiveGenotype',lit(-9))\n\ndf_new_genotypes = df_select.union(unmatched_select)\n#df_new_cnt = df_new_genotypes.count()\ntend_left_anti = time.time() - t0;\n\n#print('\\n\\n\\nSAVING...\\n\\n\\n'); time.sleep(20)\nt0 = time.time();    \n#df_new_genotypes.repartitionByRange(30, \"chromosome\", \"start\").mode('overwrite').partitionBy(\"chromosome\").parquet('new_genotypes_july_30p.parquet') \n#df_new_genotypes.repartition(10, \"unique_variant_id\").write.parquet('new_genotypes_july14.parquet')\n    \n    \n# MUST TEST THIS\nCADD_SCORED_FILE_ID = str(input_parquet).split('/')[-1].split('.')[0]\n# For CHD cohort\nif CADD_SCORED_FILE_ID.startswith('BS_'):\n    bs_name = CADD_SCORED_FILE_ID\n    SAVE_STRING = f'CHD_{bs_name}_scored_variants.parquet'\n# For KUTD cohort    \nelif CADD_SCORED_FILE_ID.startswith('GF_'): \n    kutd_name = CADD_SCORED_FILE_ID.replace('_KUTD','') \n    SAVE_STRING = f'KUTD_{kutd_name}_scored_variants.parquet'\n\n\ndf_new_genotypes.coalesce(1).write.parquet('new_genotypes_july20_reverse_join_args.parquet')\n#df_new_genotypes.count()\ntend_save = time.time() - t0;\n\n\n\n\nwith open('stats.txt', 'w') as f:\n    #f.write(f'calling df.count() took {tend_subset/60} minutes\\n')\n    #f.write(f'Removing eqtls took {t_var_noneqtl/60} min, we now have {vnon_cnt} variants out of the {var_len} we started with.\\n')\n    f.write(f'Big join took {tend_filter/60} minutes')\n    #f.write(f'Big JOIN of df ({c}) w/ variants ({vnon_cnt}) took {tend_filter/60} minutes and is {dfj_cnt} rows long\\n')\n    f.write(f'Post proccessing part took: {tend_post_process/60} min.\\n')\n    f.write(f'Number of unmatched variants is {non_matched_vars}\\n')\n    #f.write(f'Unique Variants in variants_noneqtl is {vnon_cnt_dedup}\\n')\n    #f.write(f'After post processing, df_join now has {df_cnt2} variants\\n')\n    #f.write(f'df w/ new GTs has {df_new_cnt} rows and {df_new_genotypes.dropDuplicates().count()} unique rows\\n')\n    f.write(f'Doing left anti join took {tend_left_anti/60} min\\n')\n    f.write(f'Saving took {tend_save/60} min\\n\\n')\n   \n    #f.write(\"Save command:     df_join.write.repartitionByRange(30, 'chromosome', 'start').mode('overwrite').partitionBy('chromosome').parquet('test_FULL_join_july_30p.parquet') \")\n    #f.write(f'len of anti_join {v}')\n\n'''\n\n\n    \n    ",
          "writable": false
        }
      ]
    },
    {
      "class": "InlineJavascriptRequirement"
    }
  ],
  "hints": [
    {
      "class": "sbg:AWSInstanceType",
      "value": "m5.12xlarge;ebs-gp2;1024"
    }
  ],
  "sbg:projectName": "Taylor_Urbs_R03_KF_Cardiac",
  "sbg:revisionsInfo": [
    {
      "sbg:revision": 0,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657049578,
      "sbg:revisionNotes": null
    },
    {
      "sbg:revision": 1,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657049889,
      "sbg:revisionNotes": "first save"
    },
    {
      "sbg:revision": 2,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657062438,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 3,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657150369,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 4,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657150783,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 5,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657295724,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 6,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657302148,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 7,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657302517,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 8,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657302875,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 9,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657303724,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 10,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657304078,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 11,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657465047,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 12,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657465902,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 13,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657466571,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 14,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657466919,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 15,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657467803,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 16,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657468461,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 17,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657468464,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 18,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657468757,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 19,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657469610,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 20,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657473286,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 21,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657474883,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 22,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657475165,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 23,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657475447,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 24,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657475697,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 25,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657476588,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 26,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657480786,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 27,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657490734,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 28,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657492719,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 29,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657493020,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 30,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657540822,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 31,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657542250,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 32,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657543179,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 33,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657545093,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 34,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657545341,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 35,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657547060,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 36,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657551180,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 37,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657551184,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 38,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657562923,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 39,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657563486,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 40,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657563735,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 41,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657564190,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 42,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657565149,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 43,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657565881,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 44,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657566465,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 45,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657566675,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 46,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657567349,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 47,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657580409,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 48,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657584226,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 49,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657627485,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 50,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657630480,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 51,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657632771,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 52,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657635040,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 53,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657645793,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 54,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657654133,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 55,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657664118,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 56,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657664444,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 57,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657666297,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 58,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657666807,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 59,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657667216,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 60,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657671446,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 61,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657673617,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 62,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657714017,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 63,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657716815,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 64,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657718656,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 65,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657730914,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 66,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657734273,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 67,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657736632,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 68,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657752438,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 69,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657752623,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 70,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657753225,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 71,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657753357,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 72,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657753899,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 73,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657755322,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 74,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657800195,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 75,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657801288,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 76,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657801798,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 77,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657804895,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 78,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657807992,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 79,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657808806,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 80,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657824247,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 81,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657824466,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 82,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657827376,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 83,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657829260,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 84,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657829978,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 85,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657839276,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 86,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657840511,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 87,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657843052,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 88,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657884883,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 89,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657893817,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 90,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657894582,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 91,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657907233,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 92,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657907533,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 93,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657915652,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 94,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657981034,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 95,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657982721,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 96,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657984845,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 97,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657986440,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 98,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657987701,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 99,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657993661,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 100,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658069905,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 101,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658069906,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 102,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658070799,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 103,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658071203,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 104,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658073024,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 105,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658319240,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 106,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658319622,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 107,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658326008,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 108,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658333370,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 109,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658334272,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 110,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658334787,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 111,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658335060,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 112,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658339280,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 113,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658405101,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 114,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658406557,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 115,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658409760,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 116,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658409780,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 117,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658427676,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 118,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658427890,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 119,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658428424,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 120,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658428758,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 121,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658498592,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 122,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658508220,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 123,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658508880,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 124,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658509969,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 125,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658510920,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 126,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658515779,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 127,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658516193,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 128,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658527148,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 129,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658527539,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 130,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658527624,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 131,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658587126,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 132,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658587726,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 133,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658589459,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 134,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658591479,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 135,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658591836,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 136,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658592977,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 137,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658593042,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 138,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658593928,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 139,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658671795,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 140,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658672853,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 141,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658676839,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 142,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658676880,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 143,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658677533,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 144,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658772011,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 145,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658772114,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 146,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658781336,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 147,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658792309,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 148,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658839404,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 149,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658946147,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 150,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658949272,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 151,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658949494,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 152,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658949593,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 153,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658949661,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 154,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658952316,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 155,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658952555,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 156,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658952625,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 157,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658952784,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 158,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658953473,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 159,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658954011,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 160,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658955753,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 161,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658964011,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 162,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658966061,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 163,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659008478,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 164,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659014137,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 165,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659014546,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 166,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659015131,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 167,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659015646,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 168,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659016593,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 169,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659018537,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 170,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659019143,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 171,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659019630,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 172,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659024831,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 173,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659025939,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 174,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659026663,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 175,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659031296,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 176,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659031633,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 177,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659032866,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 178,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659033279,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 179,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659033908,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 180,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659034853,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 181,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659035415,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 182,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659035870,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 183,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659038259,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 184,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659046542,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 185,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659047279,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 186,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659048037,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 187,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659050191,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 188,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659050299,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 189,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659728118,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 190,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659728842,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 191,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659729808,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 192,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659731328,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 193,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659731648,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 194,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659732124,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 195,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659732577,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 196,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659733383,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 197,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659801382,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 198,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659802879,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 199,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659803160,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 200,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659803823,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 201,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659805176,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 202,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659806217,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 203,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659807642,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 204,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659822336,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 205,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659823513,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 206,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659875204,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 207,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659877233,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 208,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659880907,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 209,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659881608,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 210,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659882088,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 211,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659959844,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 212,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659960656,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 213,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659961530,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 214,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659962034,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 215,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659962839,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 216,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659963832,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 217,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659964853,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 218,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659965746,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 219,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659981042,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 220,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659982856,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 221,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659984470,
      "sbg:revisionNotes": ""
    }
  ],
  "sbg:image_url": null,
  "sbg:appVersion": [
    "v1.2"
  ],
  "id": "https://cavatica-api.sbgenomics.com/v2/apps/taylordm/taylor-urbs-r03-kf-cardiac/find-variants/221/raw/",
  "sbg:id": "taylordm/taylor-urbs-r03-kf-cardiac/find-variants/221",
  "sbg:revision": 221,
  "sbg:revisionNotes": "",
  "sbg:modifiedOn": 1659984470,
  "sbg:modifiedBy": "stearb2",
  "sbg:createdOn": 1657049578,
  "sbg:createdBy": "stearb2",
  "sbg:project": "taylordm/taylor-urbs-r03-kf-cardiac",
  "sbg:sbgMaintained": false,
  "sbg:validationErrors": [],
  "sbg:contributors": [
    "stearb2"
  ],
  "sbg:latestRevision": 221,
  "sbg:publisher": "sbg",
  "sbg:content_hash": "a99060bc42409af028ca80ccac6a10e1129dbee9f316806b7c6d107b77b8ac383",
  "sbg:workflowLanguage": "CWL"
}
