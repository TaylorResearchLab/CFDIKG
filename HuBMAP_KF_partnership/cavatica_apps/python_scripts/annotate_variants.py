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


parser = argparse.ArgumentParser( description = 'Script to filter parquet files. \n\
MUST BE RUN WITH spark-submit. For example: \n\
    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \n\
    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \n\
    --driver-memory 60G asd_parquet_filter.py',
    formatter_class=RawTextHelpFormatter)
    
parser.add_argument('--input_patient_variants')
parser.add_argument('--input_variant_annotation_map')
parser.add_argument('--input_gene_lengths')

args = parser.parse_args()

input_patient_variants = args.input_patient_variants
input_variant_annotation_map = args.input_variant_annotation_map
gene_lengths = args.input_gene_lengths


spark = SparkSession.builder.master("local[*]").appName("annotate_variants").getOrCreate()

print('Sleeping for 1 min.'); time.sleep(60)

chd_BS_scored_vars = spark.read.parquet(input_patient_variants)

genome_bed = spark.read.parquet(gene_lengths)

t_csq_select = spark.read.parquet(input_variant_annotation_map)


no_genes = chd_BS_scored_vars.where(col('symbol') == '')
has_genes = chd_BS_scored_vars.where(~(col('symbol') == ''))

t_csq_select = t_csq_select.withColumn('unique_variant_id',concat(col("chromosome"), lit(":"),
                                                   col("start"),lit(':'),col('reference'),
                                                   lit(':'),col('alternate')))

j = t_csq_select.select('unique_variant_id','rsID','symbol').join(F.broadcast(no_genes.drop('symbol','rsID')),['unique_variant_id'],'right')


j = j.drop_duplicates(['unique_variant_id'])

cols = [ 'chromosome','start', 'end', 'reference', 'alternate', 'unique_variant_id', 'qual',
             'INFO_DP', 'splitFromMultiAllelic', 'genotypes', 'symbol', 'rsID', 'cadd_score', 'eqtl_boolean']
             
chd_BS_scored_vars_mapped = j.select(cols).union(has_genes.select(cols))

chd_BS_scored_vars_wgenes  = chd_BS_scored_vars_mapped.where(col('symbol').isNotNull())



df_join = chd_BS_scored_vars_wgenes

df_join = df_join.withColumn('calls', df_join.genotypes.getItem(0).getItem('6'))
df_join = df_join.withColumn('calls_str',concat(df_join.calls.getItem(0), lit(":"), df_join.calls.getItem(1) ))
df_join = df_join.withColumn('AdditiveGenotype',when(df_join.calls_str.contains('-')  ,-9)\
                      .otherwise(df_join.calls.getItem(0) + df_join.calls.getItem(1)))

# Create Participant ID column (should just be one participant per file)
df_join = df_join.withColumn('participant_id', df_join.genotypes.getItem(0).getItem('0'))
df_join = df_join.withColumn('INFO_DP',df_join.genotypes.getItem(0).getItem('10'))
df_join = df_join.withColumn('qual',df_join.genotypes.getItem(0).getItem('1'))
df_join = df_join.withColumn('PL',df_join.genotypes.getItem(0).getItem('9'))

df_join = df_join.withColumn('AdditiveGenotype',when((df_join.INFO_DP < 15) | (df_join.qual < 25) ,-9)\
                      .otherwise(df_join.AdditiveGenotype))
df_join = df_join.where(~ ((df_join.splitFromMultiAllelic == 'true') & (df_join.alternate == '<NON_REF>') ))

#df_join = df_join.sort(['chromosome','start'])
#df_join = df_join.drop(*("splitFromMultiAllelic")).dropDuplicates(['unique_variant_id','AdditiveGenotype'])

df_join = df_join.withColumn('PL_00',df_join.PL.getItem(0)).withColumn('PL_01',df_join.PL.getItem(1)).withColumn('PL_11',df_join.PL.getItem(2))

df_join = df_join.withColumn('AdditiveGenotype',when((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\
                                           (col('AdditiveGenotype') == 0 ),-9).otherwise(df_join.AdditiveGenotype))
                                           
df_join = df_join.withColumn('AdditiveGenotype',when(((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\
                     (df_join.PL_11 == 0)) & (col('AdditiveGenotype') == 0 ) ,-9).otherwise(df_join.AdditiveGenotype))

df_join = df_join.drop(*("PL","PL_00","PL_01","PL_11"))




chd_BS_scored_vars_wgenes = df_join.select('chromosome','start','end','reference','alternate',
                             'unique_variant_id','symbol','rsID','cadd_score','eqtl_boolean','AdditiveGenotype')
                             
# get the frequency of each gene
df = chd_BS_scored_vars_wgenes.toPandas()
df['cadd_score'] = df['cadd_score'].astype(np.float64)

symbol_freqs = dict(Counter(df['symbol']))
symbol_freq_df = pd.DataFrame.from_dict(symbol_freqs,orient='index',columns=['frequency']) 
symbol_freq_df.index.name = 'symbol'                                                
                                                
                                                
gene_scores = df[['symbol','cadd_score']].groupby('symbol').sum()
df_genes = gene_scores.join(symbol_freq_df).sort_values('cadd_score',ascending=False)
df_genes['symbol'] = df_genes.index
df_genes = df_genes.reset_index(drop=True)
df_genes['cadd_score_gene_agg'] = df_genes['cadd_score']
df_genes.drop('cadd_score',axis=1,inplace=True)

rejoin = df_genes.merge(df,on='symbol',how='right')

df_genes = rejoin

genome_bed = genome_bed.withColumn('symbol',col('name2')).drop('name2')
genome_bed_select = genome_bed.select(['chrom','txStart','txEnd','cdsStart','cdsEnd','symbol'])
genome_bed_noDups = genome_bed_select.dropDuplicates(['symbol'])

genome_bed_noDups = genome_bed_noDups.withColumn('txDiff',col('txEnd') - col('txStart'))


df_Gene_spark = spark.createDataFrame(df_genes)   # How did CADD_score get so many decimals?

normed = genome_bed_noDups.select(['symbol','txDiff']).join(df_Gene_spark,['symbol'])

normed = normed.withColumn('normed_CADD_score', F.round(1000*(col('cadd_score_gene_agg')/col('txDiff')),3 )).drop('hgvsc','hgvsg','strand')

#  Get rid of MicroRNA's (starts with MIR) microRNAs and Small nucleolar RNAs (snoRNAs)
normed_filter = normed.where(~ (col('symbol').startswith('MIR')) | ((col('symbol').startswith('SNO'))) )

normed_filter = normed_filter.withColumn('cadd_score_gene_agg',F.round(col('cadd_score_gene_agg'),3)).drop('reference','alternate','start','txDiff')


# CHD_BS_0302Y3N5_scored_variants.parquet or KUTD_GF_0ZR9EDHK_scored_variants.parquet
file_name = str(input_patient_variants).split('/')[-1].split('.')[0]

# For CHD cohort
if file_name.startswith('CHD_BS') and file_name.endswith('_scored_variants'):
    bs_name = file_name.replace('_scored_variants','')
    SAVE_PATH = f'gene_Burden_Table_{bs_name}.parquet'
# For KUTD cohort    
elif file_name.startswith('KUTD_GF') and file_name.endswith('_scored_variants'): 
    kutd_name = file_name.replace('_scored_variants','') 
    SAVE_PATH = f'{kutd_name}_geneBurdenTable.parquet'


normed_filter.repartition(10).write\
      .mode('overwrite')\
      .partitionBy("chromosome")\
       .parquet(SAVE_PATH)

