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
      "id": "ram",
      "type": "int?",
      "default": 80
    },
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
      "id": "input_gene_lengths",
      "type": "Directory?",
      "inputBinding": {
        "prefix": "--input_gene_lengths",
        "shellQuote": false,
        "position": 0
      }
    },
    {
      "id": "input_file_ids",
      "type": "File?",
      "inputBinding": {
        "prefix": "--input_file_ids",
        "shellQuote": false,
        "position": 0
      }
    }
  ],
  "outputs": [
    {
      "id": "output_matrix",
      "type": "File?",
      "outputBinding": {
        "glob": "*.csv"
      }
    }
  ],
  "label": "aggregate_variants",
  "arguments": [
    {
      "prefix": "",
      "shellQuote": false,
      "position": 0,
      "valueFrom": "--driver-memory $(inputs.ram)G  aggregate_variants.py"
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
          "entryname": "aggregate_variants.py",
          "entry": "import glob\nimport argparse\nfrom argparse import RawTextHelpFormatter\nimport pyspark\nimport sys\nimport os\nimport time\nimport pandas as pd\nimport numpy as np\nfrom collections import Counter\nfrom pyspark.sql import SparkSession\nfrom pyspark import SparkConf\nfrom pyspark.sql.functions import col,collect_list, concat, lit, when, monotonically_increasing_id, concat_ws,broadcast \nimport pyspark.sql.functions as F\n\nspark = SparkSession.builder.master(\"local[*]\").appName(\"aggregate_variants\").getOrCreate()\n\n\nparser = argparse.ArgumentParser( description = 'Script to filter parquet files. \\n\\\nMUST BE RUN WITH spark-submit. For example: \\n\\\n    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \\n\\\n    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \\n\\\n    --driver-memory 60G asd_parquet_filter.py',\n    formatter_class=RawTextHelpFormatter)\n    \nparser.add_argument('--input_patient_variants')\nparser.add_argument('--input_gene_lengths')\nparser.add_argument('--input_file_ids')\n\nargs = parser.parse_args()\n\ninput_patient_variants = args.input_patient_variants\ngene_lengths = args.input_gene_lengths\n#file_ids = args.input_file_ids\n\nprint('Sleeping for 1 min.'); time.sleep(60)\n\ngene_lengths = spark.read.parquet(gene_lengths)\nall_gene_names = gene_lengths.select(col('name2').alias('symbol')).drop_duplicates(['symbol'])\nall_gene_names_df = all_gene_names.toPandas()\n\n#annotation_tables = glob.glob('/sbgenomics/project-files/KUTD_GF_*_gene*')\n#annotation_tables = glob.glob('/sbgenomics/project-files/gene_Burden_Table_CHD_BS_*')\n#file_ids = pd.read_csv(file_ids).values\n#file_ids = [i[0] for i in file_ids]\n#print(file_ids)\n#sys.exit()\n\n#input_patient_variants_dir + \n#gene_score_row_list = []\n\n#for n,file in enumerate(annotation_tables):\ndf = spark.read.parquet(input_patient_variants)\n\n#if file.startswith('KUTD_'): \n#    file_id = file.split('/')[-1].replace('KUTD_','').replace('_geneBurdenTable.parquet','')\n#elif file.startswith('gene_burden_Table_CHD_'):\n#    file_id = file.split('/')[-1].split('.')[0].replace('gene_Burden_Table_CHD_','')\n\n#print(n,file_id)\n\nfile_id = input_patient_variants.split('/')[-1].split('.')[0].replace('gene_Burden_Table_CHD_','')\n\n# drop duplicate genes. we have multiple variants in the same gene here, but \n# for now all we want is the overall CADD score for the gene.\npatient_genes = df.select('symbol','normed_CADD_score').drop_duplicates(['symbol'])\njoined = all_gene_names.join(patient_genes,'symbol','left')\n\ngene_score_col = joined.na.fill(value=0,subset=[\"normed_CADD_score\"]).sort('symbol').select(col('normed_CADD_score').alias(file_id))\n    \n    \n#gene_score_row_list.append(gene_score_col.toPandas().T.values[0])\n#pandas_df = pd.DataFrame(gene_score_row_list,columns=[i[0] for i in list(all_gene_names_df.values)],\n#                            index=)\n#pandas_df_reduced = pandas_df.loc[:, (pandas_df.sum(axis=0) != 0)]\n\nprint(file_id)\n\n\ngene_score_col.toPandas().to_csv(f'column_{file_id}_CHD_gene_score_matrix.csv',index=False)\n\n\n\n\n\n\n\n",
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
      "sbg:modifiedOn": 1659186832,
      "sbg:revisionNotes": null
    },
    {
      "sbg:revision": 1,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659191650,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 2,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659192266,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 3,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659192739,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 4,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659193064,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 5,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659193641,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 6,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659199868,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 7,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659199908,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 8,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659200137,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 9,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659200612,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 10,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659201167,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 11,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659286214,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 12,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659286672,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 13,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659287673,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 14,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659288058,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 15,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659288582,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 16,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1659289039,
      "sbg:revisionNotes": ""
    }
  ],
  "sbg:image_url": null,
  "sbg:appVersion": [
    "v1.2"
  ],
  "id": "https://cavatica-api.sbgenomics.com/v2/apps/taylordm/taylor-urbs-r03-kf-cardiac/aggregate-variants/16/raw/",
  "sbg:id": "taylordm/taylor-urbs-r03-kf-cardiac/aggregate-variants/16",
  "sbg:revision": 16,
  "sbg:revisionNotes": "",
  "sbg:modifiedOn": 1659289039,
  "sbg:modifiedBy": "stearb2",
  "sbg:createdOn": 1659186832,
  "sbg:createdBy": "stearb2",
  "sbg:project": "taylordm/taylor-urbs-r03-kf-cardiac",
  "sbg:sbgMaintained": false,
  "sbg:validationErrors": [],
  "sbg:contributors": [
    "stearb2"
  ],
  "sbg:latestRevision": 16,
  "sbg:publisher": "sbg",
  "sbg:content_hash": "abd786b4a4d5c0bf4352f196cfd54662cfff617e6d8aaa1714c9ea56571122fe6",
  "sbg:workflowLanguage": "CWL"
}
