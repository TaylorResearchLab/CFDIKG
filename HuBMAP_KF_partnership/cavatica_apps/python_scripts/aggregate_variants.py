import glob
import argparse
from argparse import RawTextHelpFormatter
import pyspark
import sys
import os
import time
import pandas as pd
import numpy as np
from collections import Counter
from pyspark.sql import SparkSession
from pyspark import SparkConf
from pyspark.sql.functions import col,collect_list, concat, lit, when, monotonically_increasing_id, concat_ws,broadcast 
import pyspark.sql.functions as F

spark = SparkSession.builder.master("local[*]").appName("aggregate_variants").getOrCreate()


parser = argparse.ArgumentParser( description = 'Script to filter parquet files. \n\
MUST BE RUN WITH spark-submit. For example: \n\
    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \n\
    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \n\
    --driver-memory 60G asd_parquet_filter.py',
    formatter_class=RawTextHelpFormatter)
    
parser.add_argument('--input_patient_variants')
parser.add_argument('--input_gene_lengths')
parser.add_argument('--input_file_ids')

args = parser.parse_args()

input_patient_variants = args.input_patient_variants
gene_lengths = args.input_gene_lengths
#file_ids = args.input_file_ids

print('Sleeping for 1 min.'); time.sleep(60)

gene_lengths = spark.read.parquet(gene_lengths)
all_gene_names = gene_lengths.select(col('name2').alias('symbol')).drop_duplicates(['symbol'])
all_gene_names_df = all_gene_names.toPandas()

#annotation_tables = glob.glob('/sbgenomics/project-files/KUTD_GF_*_gene*')
#annotation_tables = glob.glob('/sbgenomics/project-files/gene_Burden_Table_CHD_BS_*')
#file_ids = pd.read_csv(file_ids).values
#file_ids = [i[0] for i in file_ids]
#print(file_ids)
#sys.exit()

#input_patient_variants_dir + 
#gene_score_row_list = []

#for n,file in enumerate(annotation_tables):
df = spark.read.parquet(input_patient_variants)

#if file.startswith('KUTD_'): 
#    file_id = file.split('/')[-1].replace('KUTD_','').replace('_geneBurdenTable.parquet','')
#elif file.startswith('gene_burden_Table_CHD_'):
#    file_id = file.split('/')[-1].split('.')[0].replace('gene_Burden_Table_CHD_','')

#print(n,file_id)

file_id = input_patient_variants.split('/')[-1].split('.')[0].replace('gene_Burden_Table_CHD_','')

# drop duplicate genes. we have multiple variants in the same gene here, but 
# for now all we want is the overall CADD score for the gene.
patient_genes = df.select('symbol','normed_CADD_score').drop_duplicates(['symbol'])
joined = all_gene_names.join(patient_genes,'symbol','left')

gene_score_col = joined.na.fill(value=0,subset=["normed_CADD_score"]).sort('symbol').select(col('normed_CADD_score').alias(file_id))
    
    
#gene_score_row_list.append(gene_score_col.toPandas().T.values[0])
#pandas_df = pd.DataFrame(gene_score_row_list,columns=[i[0] for i in list(all_gene_names_df.values)],
#                            index=)
#pandas_df_reduced = pandas_df.loc[:, (pandas_df.sum(axis=0) != 0)]

print(file_id)


gene_score_col.toPandas().to_csv(f'column_{file_id}_CHD_gene_score_matrix.csv',index=False)

