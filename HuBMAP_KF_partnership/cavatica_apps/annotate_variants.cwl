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
      "id": "input_patient_variants",
      "type": "Directory?",
      "inputBinding": {
        "prefix": "--input_patient_variants",
        "shellQuote": false,
        "position": 0
      }
    },
    {
      "loadListing": "deep_listing",
      "id": "input_variant_annotation_map",
      "type": "Directory?",
      "inputBinding": {
        "prefix": "--input_variant_annotation_map",
        "shellQuote": false,
        "position": 0
      }
    },
    {
      "id": "cpu",
      "type": "int?",
      "default": 25
    },
    {
      "loadListing": "deep_listing",
      "id": "input_gene_lengths",
      "type": "Directory?",
      "inputBinding": {
        "prefix": "--input_gene_lengths",
        "shellQuote": false,
        "position": 0
      }
    },
    {
      "id": "ram",
      "type": "int?",
      "default": 80
    }
  ],
  "outputs": [
    {
      "id": "output_geneBurdenTable",
      "type": "Directory?",
      "outputBinding": {
        "glob": "*.parquet",
        "loadListing": "deep_listing"
      }
    }
  ],
  "label": "annotate_variants",
  "arguments": [
    {
      "prefix": "",
      "shellQuote": false,
      "position": 0,
      "valueFrom": "--driver-memory $(inputs.ram)G  annotate_variants.py"
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
      "class": "DockerRequirement",
      "dockerPull": "pgc-images.sbgenomics.com/stearb2/bens-docker-repository:latest"
    },
    {
      "class": "InitialWorkDirRequirement",
      "listing": [
        {
          "entryname": "annotate_variants.py",
          "entry": "import argparse\nfrom argparse import RawTextHelpFormatter\nimport pyspark\nimport sys\nimport os\nimport time\nimport pandas as pd\nimport numpy as np\nfrom collections import Counter\nfrom pyspark.sql import SparkSession\nfrom pyspark import SparkConf\nfrom pyspark.sql.functions import col,collect_list, concat, lit, when, monotonically_increasing_id, concat_ws,broadcast \nimport pyspark.sql.functions as F\n\n\nparser = argparse.ArgumentParser( description = 'Script to filter parquet files. \\n\\\nMUST BE RUN WITH spark-submit. For example: \\n\\\n    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \\n\\\n    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \\n\\\n    --driver-memory 60G asd_parquet_filter.py',\n    formatter_class=RawTextHelpFormatter)\n    \nparser.add_argument('--input_patient_variants')\nparser.add_argument('--input_variant_annotation_map')\nparser.add_argument('--input_gene_lengths')\n\nargs = parser.parse_args()\n\ninput_patient_variants = args.input_patient_variants\ninput_variant_annotation_map = args.input_variant_annotation_map\ngene_lengths = args.input_gene_lengths\n\n\nspark = SparkSession.builder.master(\"local[*]\").appName(\"annotate_variants\").getOrCreate()\n\nprint('Sleeping for 1 min.'); time.sleep(60)\n\nchd_BS_scored_vars = spark.read.parquet(input_patient_variants)\n\ngenome_bed = spark.read.parquet(gene_lengths)\n\nt_csq_select = spark.read.parquet(input_variant_annotation_map)\n\n\nno_genes = chd_BS_scored_vars.where(col('symbol') == '')\nhas_genes = chd_BS_scored_vars.where(~(col('symbol') == ''))\n\nt_csq_select = t_csq_select.withColumn('unique_variant_id',concat(col(\"chromosome\"), lit(\":\"),\n                                                   col(\"start\"),lit(':'),col('reference'),\n                                                   lit(':'),col('alternate')))\n\nj = t_csq_select.select('unique_variant_id','rsID','symbol').join(F.broadcast(no_genes.drop('symbol','rsID')),['unique_variant_id'],'right')\n\n\nj = j.drop_duplicates(['unique_variant_id'])\n\ncols = [ 'chromosome','start', 'end', 'reference', 'alternate', 'unique_variant_id', 'qual',\n             'INFO_DP', 'splitFromMultiAllelic', 'genotypes', 'symbol', 'rsID', 'cadd_score', 'eqtl_boolean']\n             \nchd_BS_scored_vars_mapped = j.select(cols).union(has_genes.select(cols))\n\nchd_BS_scored_vars_wgenes  = chd_BS_scored_vars_mapped.where(col('symbol').isNotNull())\n\n\n\ndf_join = chd_BS_scored_vars_wgenes\n\ndf_join = df_join.withColumn('calls', df_join.genotypes.getItem(0).getItem('6'))\ndf_join = df_join.withColumn('calls_str',concat(df_join.calls.getItem(0), lit(\":\"), df_join.calls.getItem(1) ))\ndf_join = df_join.withColumn('AdditiveGenotype',when(df_join.calls_str.contains('-')  ,-9)\\\n                      .otherwise(df_join.calls.getItem(0) + df_join.calls.getItem(1)))\n\n# Create Participant ID column (should just be one participant per file)\ndf_join = df_join.withColumn('participant_id', df_join.genotypes.getItem(0).getItem('0'))\ndf_join = df_join.withColumn('INFO_DP',df_join.genotypes.getItem(0).getItem('10'))\ndf_join = df_join.withColumn('qual',df_join.genotypes.getItem(0).getItem('1'))\ndf_join = df_join.withColumn('PL',df_join.genotypes.getItem(0).getItem('9'))\n\ndf_join = df_join.withColumn('AdditiveGenotype',when((df_join.INFO_DP < 15) | (df_join.qual < 25) ,-9)\\\n                      .otherwise(df_join.AdditiveGenotype))\ndf_join = df_join.where(~ ((df_join.splitFromMultiAllelic == 'true') & (df_join.alternate == '<NON_REF>') ))\n\n#df_join = df_join.sort(['chromosome','start'])\n#df_join = df_join.drop(*(\"splitFromMultiAllelic\")).dropDuplicates(['unique_variant_id','AdditiveGenotype'])\n\ndf_join = df_join.withColumn('PL_00',df_join.PL.getItem(0)).withColumn('PL_01',df_join.PL.getItem(1)).withColumn('PL_11',df_join.PL.getItem(2))\n\ndf_join = df_join.withColumn('AdditiveGenotype',when((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\\\n                                           (col('AdditiveGenotype') == 0 ),-9).otherwise(df_join.AdditiveGenotype))\n                                           \ndf_join = df_join.withColumn('AdditiveGenotype',when(((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\\\n                     (df_join.PL_11 == 0)) & (col('AdditiveGenotype') == 0 ) ,-9).otherwise(df_join.AdditiveGenotype))\n\ndf_join = df_join.drop(*(\"PL\",\"PL_00\",\"PL_01\",\"PL_11\"))\n\n\n\n\nchd_BS_scored_vars_wgenes = df_join.select('chromosome','start','end','reference','alternate',\n                             'unique_variant_id','symbol','rsID','cadd_score','eqtl_boolean','AdditiveGenotype')\n                             \n# get the frequency of each gene\ndf = chd_BS_scored_vars_wgenes.toPandas()\ndf['cadd_score'] = df['cadd_score'].astype(np.float64)\n\nsymbol_freqs = dict(Counter(df['symbol']))\nsymbol_freq_df = pd.DataFrame.from_dict(symbol_freqs,orient='index',columns=['frequency']) \nsymbol_freq_df.index.name = 'symbol'                                                \n                                                \n                                                \ngene_scores = df[['symbol','cadd_score']].groupby('symbol').sum()\ndf_genes = gene_scores.join(symbol_freq_df).sort_values('cadd_score',ascending=False)\ndf_genes['symbol'] = df_genes.index\ndf_genes = df_genes.reset_index(drop=True)\ndf_genes['cadd_score_gene_agg'] = df_genes['cadd_score']\ndf_genes.drop('cadd_score',axis=1,inplace=True)\n\nrejoin = df_genes.merge(df,on='symbol',how='right')\n\ndf_genes = rejoin\n\ngenome_bed = genome_bed.withColumn('symbol',col('name2')).drop('name2')\ngenome_bed_select = genome_bed.select(['chrom','txStart','txEnd','cdsStart','cdsEnd','symbol'])\ngenome_bed_noDups = genome_bed_select.dropDuplicates(['symbol'])\n\ngenome_bed_noDups = genome_bed_noDups.withColumn('txDiff',col('txEnd') - col('txStart'))\n\n\ndf_Gene_spark = spark.createDataFrame(df_genes)   # How did CADD_score get so many decimals?\n\nnormed = genome_bed_noDups.select(['symbol','txDiff']).join(df_Gene_spark,['symbol'])\n\nnormed = normed.withColumn('normed_CADD_score', F.round(1000*(col('cadd_score_gene_agg')/col('txDiff')),3 )).drop('hgvsc','hgvsg','strand')\n\n#  Get rid of MicroRNA's (starts with MIR) microRNAs and Small nucleolar RNAs (snoRNAs)\nnormed_filter = normed.where(~ (col('symbol').startswith('MIR')) | ((col('symbol').startswith('SNO'))) )\n\nnormed_filter = normed_filter.withColumn('cadd_score_gene_agg',F.round(col('cadd_score_gene_agg'),3)).drop('reference','alternate','start','txDiff')\n\n\n# CHD_BS_0302Y3N5_scored_variants.parquet or KUTD_GF_0ZR9EDHK_scored_variants.parquet\nfile_name = str(input_patient_variants).split('/')[-1].split('.')[0]\n\n# For CHD cohort\nif file_name.startswith('CHD_BS') and file_name.endswith('_scored_variants'):\n    bs_name = file_name.replace('_scored_variants','')\n    SAVE_PATH = f'gene_Burden_Table_{bs_name}.parquet'\n# For KUTD cohort    \nelif file_name.startswith('KUTD_GF') and file_name.endswith('_scored_variants'): \n    kutd_name = file_name.replace('_scored_variants','') \n    SAVE_PATH = f'{kutd_name}_geneBurdenTable.parquet'\n\n\nnormed_filter.repartition(10).write\\\n      .mode('overwrite')\\\n      .partitionBy(\"chromosome\")\\\n       .parquet(SAVE_PATH)\n\n\n\n\n\n\n\n\n",
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
      "sbg:modifiedOn": 1658923592,
      "sbg:revisionNotes": null
    },
    {
      "sbg:revision": 1,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658925024,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 2,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658927413,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 3,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658931792,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 4,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658932007,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 5,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658932353,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 6,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658940542,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 7,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658940783,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 8,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658940881,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 9,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658941356,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 10,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658946538,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 11,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658947152,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 12,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658947599,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 13,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658947736,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 14,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658947765,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 15,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659095503,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 16,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659097800,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 17,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659098274,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 18,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659100448,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 19,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659100941,
      "sbg:revisionNotes": ""
    }
  ],
  "sbg:image_url": null,
  "sbg:appVersion": [
    "v1.2"
  ],
  "id": "https://cavatica-api.sbgenomics.com/v2/apps/taylordm/taylor-urbs-r03-kf-cardiac/annotate-variants/19/raw/",
  "sbg:id": "taylordm/taylor-urbs-r03-kf-cardiac/annotate-variants/19",
  "sbg:revision": 19,
  "sbg:revisionNotes": "",
  "sbg:modifiedOn": 1659100941,
  "sbg:modifiedBy": "stearb2",
  "sbg:createdOn": 1658923592,
  "sbg:createdBy": "stearb2",
  "sbg:project": "taylordm/taylor-urbs-r03-kf-cardiac",
  "sbg:sbgMaintained": false,
  "sbg:validationErrors": [],
  "sbg:contributors": [
    "stearb2"
  ],
  "sbg:latestRevision": 19,
  "sbg:publisher": "sbg",
  "sbg:content_hash": "a8a35e4d6f44e2b8964473a0bb2e74166bf77b04b5a98617e402708144f1a3126",
  "sbg:workflowLanguage": "CWL"
}
