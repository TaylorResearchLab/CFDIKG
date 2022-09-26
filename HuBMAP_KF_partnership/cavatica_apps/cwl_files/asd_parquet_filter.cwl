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
            "id": "input_parquet",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_parquet",
                "shellQuote": true,
                "position": 0
            },
            "doc": "Parquet to filter"
        },
        {
            "loadListing": "deep_listing",
            "id": "input_bed",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_bed",
                "shellQuote": true,
                "position": 0
            },
            "doc": "BED file to use to filter"
        },
        {
            "id": "cpu",
            "type": "int?",
            "doc": "CPU cores to allocate to this task",
            "default": 40
        },
        {
            "id": "ram",
            "type": "int?",
            "doc": "GB of RAM to allocate to this task",
            "default": 80
        },
        {
            "loadListing": "deep_listing",
            "id": "input_snp_cadd_scores",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_snp_cadd_scores",
                "shellQuote": false,
                "position": 0
            },
            "label": "cadd snp scores"
        },
        {
            "loadListing": "deep_listing",
            "id": "input_indel_cadd_scores",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_indel_cadd_scores",
                "shellQuote": false,
                "position": 0
            }
        },
        {
            "loadListing": "deep_listing",
            "id": "input_ALL_indel_cadd_scores",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_ALL_indel_cadd_scores",
                "shellQuote": false,
                "position": 0
            }
        },
        {
            "loadListing": "deep_listing",
            "id": "input_ALL_snp_cadd_scores",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_ALL_snp_cadd_scores",
                "shellQuote": false,
                "position": 0
            }
        },
        {
            "loadListing": "deep_listing",
            "id": "input_eqtls_high_impact",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_eqtls_high_impact",
                "shellQuote": false,
                "position": 0
            }
        },
        {
            "loadListing": "deep_listing",
            "id": "input_fake_df_join",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_fake_df_join",
                "shellQuote": false,
                "position": 0
            }
        },
        {
            "loadListing": "deep_listing",
            "id": "input_cadd_snp_chr1",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_cadd_snp_chr1",
                "shellQuote": false,
                "position": 0
            }
        },
        {
            "loadListing": "deep_listing",
            "id": "input_fake_df_scored",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_fake_df_scored",
                "shellQuote": false,
                "position": 0
            }
        },
        {
            "loadListing": "deep_listing",
            "id": "input_eqtls_high_impact_scored",
            "type": "Directory?",
            "inputBinding": {
                "prefix": "--input_eqtls_high_impact_scored",
                "shellQuote": false,
                "position": 0
            }
        }
    ],
    "outputs": [
        {
            "id": "parquet_file",
            "doc": "Filtered parquet file",
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
        }
    ],
    "doc": "Tool to filter a parquet file using a bed file",
    "label": "asd_parquet_filter",
    "arguments": [
        {
            "prefix": "",
            "shellQuote": false,
            "position": 0,
            "valueFrom": "--driver-memory $(inputs.ram)G  asd_parquet_filter.py"
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
            "ramMin": "${ return inputs.ram * 1000 }",
            "coresMin": "$(inputs.cpu)"
        },
        {
            "class": "DockerRequirement",
            "dockerPull": "pgc-images.sbgenomics.com/stearb2/bens-docker-repository:latest"
        },
        {
            "class": "InitialWorkDirRequirement",
            "listing": [
                {
                    "entryname": "asd_parquet_filter.py",
                    "entry": "\"\"\"\nScript to filter a parquet file using a BED file\n\"\"\"\nimport argparse\nfrom argparse import RawTextHelpFormatter\nimport pyspark\nimport sys\nimport os\nimport time\nimport pandas as pd\n#import pyranges as pr\nimport numpy as np\nfrom collections import Counter\nfrom pyspark.sql.functions import col,collect_list, concat, lit, when, monotonically_increasing_id, concat_ws,broadcast \nimport pyspark.sql.functions as F\n#from pyspark.sql.types import StructType,StructField, StringType,IntegerType, FloatType, BooleanType, ArrayType\n#import scipy.sparse as ss\nimport logging\n\nparser = argparse.ArgumentParser( description = 'Script to filter parquet files. \\n\\\nMUST BE RUN WITH spark-submit. For example: \\n\\\n    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \\n\\\n    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \\n\\\n    --driver-memory 60G asd_parquet_filter.py',\n    formatter_class=RawTextHelpFormatter)\n\nparser.add_argument('--input_parquet', help='Parquet File to filter')\nparser.add_argument('--input_bed', help='Bed file to use for filtering Parquet Files')\n#parser.add_argument('--input_repeat_bed', help='Bed file to use for excluding genes in Parquet Files')\nparser.add_argument('--input_snp_cadd_scores')\nparser.add_argument('--input_ALL_snp_cadd_scores')\n\nparser.add_argument('--input_indel_cadd_scores')\nparser.add_argument('--input_ALL_indel_cadd_scores')\n\nparser.add_argument('--input_eqtls')\nparser.add_argument('--input_high_impact')\nparser.add_argument('--input_eqtls_high_impact')\nparser.add_argument('--input_fake_df_join')\nparser.add_argument('--input_cadd_snp_chr1')\nparser.add_argument('--input_fake_df_scored')\nparser.add_argument('--input_eqtls_high_impact_scored')\n\nargs = parser.parse_args()\n\ninput_parquet = args.input_parquet\ninput_bed = args.input_bed\n#input_repeat_bed =  args.input_repeat_bed\ninput_snp_cadd_scores = args.input_snp_cadd_scores\n#input_ALL_snp_cadd_scores = args.input_ALL_snp_cadd_scores\ninput_indel_cadd_scores = args.input_indel_cadd_scores\n#input_ALL_indel_cadd_scores = args.input_ALL_indel_cadd_scores\n#input_eqtls = args.input_eqtls\n#input_high_impact = args.input_high_impact\n#input_eqtls_high_impact = args.input_eqtls_high_impact\n#input_fake_df_join = args.input_fake_df_join\n#input_cadd_snp_chr1 = args.input_cadd_snp_chr1\n#input_fake_df_scored = args.input_fake_df_scored\ninput_eqtls_high_impact_scored = args.input_eqtls_high_impact_scored\n\nspark = pyspark.sql.SparkSession.builder.appName(\"gene_burden_app\").getOrCreate()\n\nlogging.basicConfig(filename='out_log.txt', level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s %(message)s')\nlogger=logging.getLogger(__name__)\n\n#print('Sleeping for 30 seconds'); time.sleep(30)\n\n#with open('stats.txt', 'w') as f:\n#    f.write(str(input_parquet).split('/')[-1].split('.')[0])\n    \n#try:\n\n######################################################\n#########  Read and format input data   ##############\n######################################################\n#t0_read_data = time.time()\n\n#print('Reading participant parquet file...', file=sys.stderr); #time.sleep(5)\ndf = spark.read.parquet(input_parquet)\n\n#df_multiallelic = df.where(col('splitFromMultiAllelic') == 'false').count()\n\ndf = df.select(col('contigName').alias('chromosome'),'start','end',col('referenceAllele').alias('reference'),\n                        col('alternateAlleles').alias('alternate'),'qual','INFO_DP', 'splitFromMultiAllelic',\n                                'genotypes').withColumn('alternate',F.explode('alternate')).withColumn('chromosome',F.regexp_replace(col(\"chromosome\"), \"[chr,]\", \"\") )                    \ndf = df.withColumn(\"start\", df[\"start\"]+1) #df_count = df.count() \n\ndf = df.withColumn('unique_variant_id',concat(col(\"chromosome\"), lit(\":\"),\n                    col(\"start\"),lit(':'),col('reference'),lit(':'),col('alternate'))) \n\n#print('\\n\\n\\nRepartitioning gVCF parquet file...\\n\\n\\n', file=sys.stderr)\n#df=  df.repartitionByRange(200, \"chromosome\", \"start\")\n#print(whole_genome_bed.rdd.mapPartitionsWithIndex(lambda x,it: [(x,sum(1 for _ in it))]).collect())\n\n#print('Read in CADD SNPs (scores greater than 20)...'); time.sleep(2)\ncadd_scores_gt20 = spark.read.option(\"header\",\"true\").parquet(input_snp_cadd_scores)\ncadd_scores_gt20 = cadd_scores_gt20.withColumn(\"start\", col('start').cast('int'))\n\n#print('Read in CADD SNPs (scores greater than 20)...'); time.sleep(2)\ncadd_indels = spark.read.option(\"header\",\"true\").parquet(input_indel_cadd_scores)\ncadd_indels = cadd_indels.withColumn(\"start\", col('start').cast('int'))\n\n#print('Reading in all indels...'); time.sleep(2)\n#cadd_ALL_indels = spark.read.option(\"header\",\"true\").parquet(input_ALL_indel_cadd_scores); \n\n#print('Reading eQTLs/highImpct dataset...'); time.sleep(2)\n#eqtls_high_impact = spark.read.option(\"header\",\"true\").parquet(input_eqtls_high_impact); \neqtl_highImpact_scored = spark.read.option(\"header\",\"true\").parquet(input_eqtls_high_impact_scored);\n#eqtlhiImpactLen = eqtl_highImpact_scored.count()\n\n#print('Reading BED...', file=sys.stderr); time.sleep(2)\nwhole_genome_bed = spark.read.option(\"header\",\"true\").parquet(input_bed)\n\ndf_noNonRef = df.where(~ (col('alternate') == '<NON_REF>')) # only need to get CADD scores for this df\n#df_NonRef = df_join.where( (col('alternate') == '<NON_REF>')) # will add this back on later!\n#dfNoNonRefLen = df_noNonRef.count()\n#t_elapsed_read_data = time.time() - t0_read_data\n\n#df_noNonRef_multiallelic = df_noNonRef.where(col('splitFromMultiAllelic') == 'false').count()\ndf_noNonRef = df_noNonRef.repartition(20,'chromosome','start')\ndf_noNonRef.cache()\n\nwhole_genome_bed = whole_genome_bed.coalesce(1)\nwhole_genome_bed.cache()\n\n####### Filter patient gVCF by BED file  #############\nBED_JOIN_TYPE = 'leftsemi'\n#t0 = time.time(); print('\\n\\n\\Filtering by BED file...\\n\\n', file=sys.stderr); time.sleep(3)\ndf_join = df_noNonRef.join(broadcast(whole_genome_bed), \n              (df_noNonRef['chromosome'] == whole_genome_bed['chromosome_bed']) &\\\n              (df_noNonRef['start'] >= whole_genome_bed['start_bed']) &\\\n              (df_noNonRef['end'] <= whole_genome_bed['end_bed']),BED_JOIN_TYPE )\n    \n#print(df_join.count()); time.sleep(120)\n#df_join_multiallelic = df_join.where(col('splitFromMultiAllelic') == 'false').count()\n  \n#df_join_len = df_join.count()\n#elapsed_bed_join = time.time() - t0\n#print('Finished BED filtering in '+str(elapsed_bed_join/60)+' minutes\\n'); \n\n#df_join.repartitionByRange(50, \"chromosome\", \"start\").write\\\n#  .mode('overwrite').partitionBy(\"chromosome\").parquet('df_bed_leftsemi.parquet')     \n\n# LOAD FILTERED BED IN HERE WHEN TESTING\n#df_join = spark.read.option(\"header\",\"true\").parquet(input_fake_df_join)\n#print(df.rdd.getNumPartitions());print(whole_genome_bed.rdd.getNumPartitions())\n\n######################################################\n####### Compute Joins to Find CADD scores ############\n######################################################\n\ndf_snps = df_join.where((F.length(\"reference\") == 1) & (F.length(\"alternate\") == 1))                    \ndf_indels = df_join.where(~ ((F.length(\"reference\") == 1) & (F.length(\"alternate\") == 1)))\n\nresult_snps = df_snps.join(cadd_scores_gt20.select('unique_variant_id','cadd_score'), [\"unique_variant_id\"], \"inner\")\nresult_indels = df_indels.join(cadd_indels.select('unique_variant_id','cadd_score'),[\"unique_variant_id\"], \"inner\")\n\n#print('combining gt20 dfs...'); time.sleep(4)\nresults_gt20 = result_snps.union(result_indels) # #assert result_snps.columns == result_indels.columns\nresults_gt20 = results_gt20.select(result_snps.columns+[lit('').alias(\"symbol\"),lit('').alias(\"rsID\"),lit(0).alias('eqtl_boolean')])\n'''\nprint(f'Length of df_snps: {df_snps.count()}')\nprint(f'Length of caddd matched snps: {result_snps.count()}')\nprint(f'Length of df_indels: {df_indels.count()}')\n#print(f'Length of caddd matched indels: {result_indels.count()}')\ntime.sleep(40)\n\nprint('checking results from gt20...'); time.sleep(4)\nresults_gt20_chr15 = list(results_gt20.where(col('chromosome') == '15').toPandas()['unique_variant_id'])\ndf_join_chr15 = list(df_join.where(col('chromosome') == '15').toPandas()['unique_variant_id'])\n\nflag_gt20 = 0\nif(set(results_gt20_chr15).issubset(set(df_join_chr15))):\n    print('Results gt20 is subset!'); time.sleep(20)\n    flag_gt20 = 1'''\n\n\n#assert result_indels.count() < df_indels.count()\n#assert df_snps.count() == result_snps.count()\n\n#snps_multi = result_snps.where(col('splitFromMultiAllelic') == 'false').count()\n#indels_multi = result_indels.where(col('splitFromMultiAllelic') == 'false').count()\n\n#df_join.write.mode('overwrite').partitionBy(\"chromosome\").parquet(\"june20_gvcf_filtered.parquet\")\n\n##########################################################\n### Compute CADD scores for eQTLs/High Impact Variants ###\n##########################################################\n#print('eqtl/hiImpact join...'); time.sleep(4)\neqtl_highImpact_scored_BS = df_join.join(\n    eqtl_highImpact_scored.select('unique_variant_id','rsID','symbol','cadd_score','eqtl_boolean'),\n    ['unique_variant_id'],\n    'inner') #     df_join.unique_variant_id == eqtl_highImpact_scored.unique_variant_id,\n\n'''\nprint(f'eqtl/hiImpact cadd scored df is {eqtl_highImpact_scored_BS.count()} rows long.')\ntime.sleep(20)\n\neqtl_highImpact_scored_BS_chr15 = list(eqtl_highImpact_scored_BS.where(col('chromosome') == '15').toPandas()['unique_variant_id'])\n\nflag_eqtl = 0 \nif(set(eqtl_highImpact_scored_BS_chr15).issubset(set(df_join_chr15))):\n    print('Results eqtl/hiImpact is subset!'); time.sleep(20)\n    flag_eqtl = 1'''\n\n#print(eqtl_highImpact_scored_BS.columns)\n#print(results_gt20.columns)\n#time.sleep(20)\n\nc = ['chromosome', 'start', 'end', 'reference', 'alternate', 'unique_variant_id','qual', 'INFO_DP', 'splitFromMultiAllelic', 'genotypes', 'symbol', 'rsID','cadd_score','eqtl_boolean']\n\n#print('combining dfs...'); time.sleep(4)\ndf_scored = results_gt20.select(c).union(eqtl_highImpact_scored_BS.select(c))\n#df_scored.count()\n\n'''\ndf_scored_chr15 = list(df_scored.where(col('chromosome') == '15').toPandas()['unique_variant_id'])\nflag_both = 0 \nif(set(df_scored_chr15).issubset(set(df_join_chr15))):\n    print('Results eqtl/hiImpact is subset!'); time.sleep(20)\n    flag_both = 1'''\n    \n'''\nwith open('stats.txt', 'w') as f:\n    f.write(f'len df_snps {df_snps.count()}\\n')\n    f.write(f'len df_indels {df_indels.count()}\\n')\n    f.write(f'len snp results {result_snps.count()}\\n')\n    f.write(f'len indel results {result_indels.count()}\\n')\n    f.write(f'len eqtl/hiImpact results {eqtl_highImpact_scored_BS.count()}\\n')\n    f.write(f'eqtl_hiImpact cols: {eqtl_highImpact_scored_BS.columns}\\n')\n    f.write(f'results_gt20 cols: {results_gt20.columns}\\n')\n    #f.write(f'flag_gt20 = {flag_gt20}\\n')\n    #f.write(f'flag_eqtl = {flag_eqtl}\\n')\n    #f.write(f'flag_both = {flag_both}\\n')'''\n\n\n# we have duplicate 'unique_variant_id's bc some genes map to multiple genes in the eqtl dataframe\n# for now just choose one and drop the rest\ndf_scored_dedup = df_scored.dropDuplicates(['unique_variant_id']) \n\n\nVCF_FILE_ID = str(input_parquet).split('/')[-1].split('.')[0]\n# For CHD cohort\nif VCF_FILE_ID.startswith('BS_'):\n    bs_name = VCF_FILE_ID\n    SAVE_STRING = f'CHD_{bs_name}_scored_variants.parquet'\n# For KUTD cohort    \nelif VCF_FILE_ID.startswith('GF_'): \n    kutd_name = VCF_FILE_ID.replace('_KUTD','') \n    SAVE_STRING = f'KUTD_{kutd_name}_scored_variants.parquet'\n\n\n#dedup_multi = df_scored_dedup.where(col('splitFromMultiAllelic') == 'false').count()\n#t0 = time.time() \n#df_scored_dedup\n\ndf_scored_dedup.repartitionByRange(30, \"chromosome\", \"start\").write.mode('overwrite').partitionBy(\"chromosome\").parquet(SAVE_STRING)  \n\n\n#except:\n#logging.exception('')\n\n\n",
                    "writable": false
                }
            ]
        },
        {
            "class": "InlineJavascriptRequirement"
        }
    ],
    "sbg:projectName": "Taylor_Urbs_R03_KF_Cardiac",
    "sbg:revisionsInfo": [
        {
            "sbg:revision": 0,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655472454,
            "sbg:revisionNotes": "Copy of taylordm/taylor-urbs-r03-kf-cardiac/asd_parquet_filter/97"
        },
        {
            "sbg:revision": 1,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655493278,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 2,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655494472,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 3,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655494476,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 4,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655494530,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 5,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655495333,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 6,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655560329,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 7,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655561905,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 8,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655563264,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 9,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655564532,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 10,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655567144,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 11,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655568570,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 12,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655645649,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 13,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655646816,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 14,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655648199,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 15,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655649632,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 16,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655650478,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 17,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655652808,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 18,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655654010,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 19,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655678596,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 20,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655679272,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 21,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655680149,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 22,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655682078,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 23,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655738797,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 24,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655739948,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 25,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655740392,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 26,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655745802,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 27,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655746414,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 28,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655746800,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 29,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655747989,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 30,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655749117,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 31,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655751505,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 32,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655753692,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 33,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655754386,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 34,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655758265,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 35,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655759643,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 36,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655768293,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 37,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655769693,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 38,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655811562,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 39,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655814951,
            "sbg:revisionNotes": "fix dup cols after join"
        },
        {
            "sbg:revision": 40,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655837749,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 41,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655839332,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 42,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655839902,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 43,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655842942,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 44,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655843511,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 45,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655850655,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 46,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655851415,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 47,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655852040,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 48,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655899669,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 49,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655900713,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 50,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655901292,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 51,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655901910,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 52,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655907872,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 53,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655909605,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 54,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655909775,
            "sbg:revisionNotes": "a"
        },
        {
            "sbg:revision": 55,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655910707,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 56,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655911488,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 57,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655916861,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 58,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655918367,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 59,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655918428,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 60,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655919318,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 61,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655920784,
            "sbg:revisionNotes": "as"
        },
        {
            "sbg:revision": 62,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655930294,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 63,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655931824,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 64,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655934146,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 65,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655939683,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 66,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655942528,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 67,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655945923,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 68,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655995371,
            "sbg:revisionNotes": "aa"
        },
        {
            "sbg:revision": 69,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1655998144,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 70,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656000246,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 71,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656001718,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 72,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656010444,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 73,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656012920,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 74,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656012997,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 75,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656013406,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 76,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656014067,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 77,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656014964,
            "sbg:revisionNotes": "aa"
        },
        {
            "sbg:revision": 78,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656028872,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 79,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656030862,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 80,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656071637,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 81,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656074779,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 82,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656075619,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 83,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656076206,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 84,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656076725,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 85,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656078465,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 86,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656079203,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 87,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656082170,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 88,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656083266,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 89,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656083895,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 90,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656091446,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 91,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656093118,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 92,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656094275,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 93,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656095681,
            "sbg:revisionNotes": "aa"
        },
        {
            "sbg:revision": 94,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656097718,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 95,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656098568,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 96,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656099247,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 97,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656119194,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 98,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656175507,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 99,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656176679,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 100,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656177808,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 101,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656179159,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 102,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656181710,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 103,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656182890,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 104,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656196410,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 105,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656197140,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 106,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656197957,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 107,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656198649,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 108,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656253500,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 109,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656254549,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 110,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656256573,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 111,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656256685,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 112,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656257433,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 113,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656261645,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 114,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656261885,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 115,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656270933,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 116,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656280483,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 117,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656281506,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 118,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656285694,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 119,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656286977,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 120,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656287210,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 121,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656288924,
            "sbg:revisionNotes": "aa"
        },
        {
            "sbg:revision": 122,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656331663,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 123,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656332940,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 124,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656335672,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 125,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656337529,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 126,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656339860,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 127,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656343039,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 128,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656346638,
            "sbg:revisionNotes": "a"
        },
        {
            "sbg:revision": 129,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656350378,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 130,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656350430,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 131,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656350983,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 132,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656351622,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 133,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656352388,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 134,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656353114,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 135,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656354531,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 136,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656354975,
            "sbg:revisionNotes": "a"
        },
        {
            "sbg:revision": 137,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656355703,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 138,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656356748,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 139,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656357916,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 140,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656359482,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 141,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656360543,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 142,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656368839,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 143,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656422713,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 144,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656422877,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 145,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656424246,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 146,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656426719,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 147,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656428723,
            "sbg:revisionNotes": "a"
        },
        {
            "sbg:revision": 148,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656437354,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 149,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656445865,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 150,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656447198,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 151,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656447687,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 152,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656458039,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 153,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656458715,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 154,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656458789,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 155,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656459265,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 156,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656460193,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 157,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656461037,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 158,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656506515,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 159,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656511531,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 160,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656516144,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 161,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656519802,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 162,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656520520,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 163,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656520666,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 164,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656594662,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 165,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656597976,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 166,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656604075,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 167,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656605164,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 168,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656614793,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 169,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656617735,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 170,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656620357,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 171,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656632585,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 172,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656634335,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 173,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656635369,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 174,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656636517,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 175,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656675848,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 176,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656677419,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 177,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656680553,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 178,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656682132,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 179,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656683348,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 180,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656683668,
            "sbg:revisionNotes": "a"
        },
        {
            "sbg:revision": 181,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656700624,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 182,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656719808,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 183,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656776582,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 184,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656863072,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 185,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656863210,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 186,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656863713,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 187,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656869543,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 188,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656870037,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 189,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1656879880,
            "sbg:revisionNotes": "a"
        },
        {
            "sbg:revision": 190,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657022768,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 191,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657022770,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 192,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657024746,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 193,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657026086,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 194,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657027495,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 195,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657030909,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 196,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657038746,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 197,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657044044,
            "sbg:revisionNotes": "a"
        },
        {
            "sbg:revision": 198,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657045300,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 199,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657046515,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 200,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657049243,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 201,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657059737,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 202,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657108891,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 203,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657111771,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 204,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657119075,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 205,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657119420,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 206,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657120228,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 207,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657127186,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 208,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657127796,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 209,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657128622,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 210,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657130592,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 211,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657130986,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 212,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657195415,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 213,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657198204,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 214,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657283589,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 215,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657287351,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 216,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657289685,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 217,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657294329,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 218,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657632246,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 219,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657633657,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 220,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1657715132,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 221,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658149823,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 222,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658151126,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 223,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658151822,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 224,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658153170,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 225,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658153514,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 226,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658154092,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 227,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658159450,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 228,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658159528,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 229,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658160007,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 230,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658160715,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 231,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658161453,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 232,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658165042,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 233,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658166505,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 234,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658169702,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 235,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658171719,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 236,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658172735,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 237,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658174960,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 238,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658188077,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 239,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658230913,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 240,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658247171,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 241,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658248176,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 242,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658249536,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 243,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658257844,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 244,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658259845,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 245,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658326579,
            "sbg:revisionNotes": "a"
        },
        {
            "sbg:revision": 246,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658332342,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 247,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658333672,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 248,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658340828,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 249,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658429293,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 250,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658497718,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 251,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658498656,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 252,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658499569,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 253,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658500256,
            "sbg:revisionNotes": "A"
        },
        {
            "sbg:revision": 254,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658501771,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 255,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658502804,
            "sbg:revisionNotes": ""
        },
        {
            "sbg:revision": 256,
            "sbg:modifiedBy": "stearb2",
            "sbg:modifiedOn": 1658503969,
            "sbg:revisionNotes": ""
        }
    ],
    "sbg:image_url": null,
    "sbg:appVersion": [
        "v1.2"
    ],
    "id": "https://cavatica-api.sbgenomics.com/v2/apps/taylordm/taylor-urbs-r03-kf-cardiac/whole-genome-parquet-filter/256/raw/",
    "sbg:id": "taylordm/taylor-urbs-r03-kf-cardiac/whole-genome-parquet-filter/256",
    "sbg:revision": 256,
    "sbg:revisionNotes": "",
    "sbg:modifiedOn": 1658503969,
    "sbg:modifiedBy": "stearb2",
    "sbg:createdOn": 1655472454,
    "sbg:createdBy": "stearb2",
    "sbg:project": "taylordm/taylor-urbs-r03-kf-cardiac",
    "sbg:sbgMaintained": false,
    "sbg:validationErrors": [],
    "sbg:contributors": [
        "stearb2"
    ],
    "sbg:latestRevision": 256,
    "sbg:publisher": "sbg",
    "sbg:content_hash": "a9220f3041881fbc7d9c6df5d933a34a3849550b592f433254da4938d3ba6e34c",
    "sbg:workflowLanguage": "CWL"
}
