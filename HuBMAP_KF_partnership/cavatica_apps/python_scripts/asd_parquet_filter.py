"""
Script to filter a parquet file using a BED file
"""
import argparse
from argparse import RawTextHelpFormatter
import pyspark
import sys
import os
import time
import pandas as pd
#import pyranges as pr
import numpy as np
from collections import Counter
from pyspark.sql.functions import col,collect_list, concat, lit, when, monotonically_increasing_id, concat_ws,broadcast 
import pyspark.sql.functions as F
#from pyspark.sql.types import StructType,StructField, StringType,IntegerType, FloatType, BooleanType, ArrayType
#import scipy.sparse as ss
import logging

parser = argparse.ArgumentParser( description = 'Script to filter parquet files. \n\
MUST BE RUN WITH spark-submit. For example: \n\
    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \n\
    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \n\
    --driver-memory 60G asd_parquet_filter.py',
    formatter_class=RawTextHelpFormatter)

parser.add_argument('--input_parquet', help='Parquet File to filter')
parser.add_argument('--input_bed', help='Bed file to use for filtering Parquet Files')
#parser.add_argument('--input_repeat_bed', help='Bed file to use for excluding genes in Parquet Files')
parser.add_argument('--input_snp_cadd_scores')
parser.add_argument('--input_ALL_snp_cadd_scores')

parser.add_argument('--input_indel_cadd_scores')
parser.add_argument('--input_ALL_indel_cadd_scores')

parser.add_argument('--input_eqtls')
parser.add_argument('--input_high_impact')
parser.add_argument('--input_eqtls_high_impact')
parser.add_argument('--input_fake_df_join')
parser.add_argument('--input_cadd_snp_chr1')
parser.add_argument('--input_fake_df_scored')
parser.add_argument('--input_eqtls_high_impact_scored')

args = parser.parse_args()

input_parquet = args.input_parquet
input_bed = args.input_bed
#input_repeat_bed =  args.input_repeat_bed
input_snp_cadd_scores = args.input_snp_cadd_scores
#input_ALL_snp_cadd_scores = args.input_ALL_snp_cadd_scores
input_indel_cadd_scores = args.input_indel_cadd_scores
#input_ALL_indel_cadd_scores = args.input_ALL_indel_cadd_scores
#input_eqtls = args.input_eqtls
#input_high_impact = args.input_high_impact
#input_eqtls_high_impact = args.input_eqtls_high_impact
#input_fake_df_join = args.input_fake_df_join
#input_cadd_snp_chr1 = args.input_cadd_snp_chr1
#input_fake_df_scored = args.input_fake_df_scored
input_eqtls_high_impact_scored = args.input_eqtls_high_impact_scored

spark = pyspark.sql.SparkSession.builder.appName("gene_burden_app").getOrCreate()

logging.basicConfig(filename='out_log.txt', level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s %(message)s')
logger=logging.getLogger(__name__)

#print('Sleeping for 30 seconds'); time.sleep(30)

#with open('stats.txt', 'w') as f:
#    f.write(str(input_parquet).split('/')[-1].split('.')[0])
    
#try:

######################################################
#########  Read and format input data   ##############
######################################################
#t0_read_data = time.time()

#print('Reading participant parquet file...', file=sys.stderr); #time.sleep(5)
df = spark.read.parquet(input_parquet)

#df_multiallelic = df.where(col('splitFromMultiAllelic') == 'false').count()

df = df.select(col('contigName').alias('chromosome'),'start','end',col('referenceAllele').alias('reference'),
                        col('alternateAlleles').alias('alternate'),'qual','INFO_DP', 'splitFromMultiAllelic',
                                'genotypes').withColumn('alternate',F.explode('alternate')).withColumn('chromosome',F.regexp_replace(col("chromosome"), "[chr,]", "") )                    
df = df.withColumn("start", df["start"]+1) #df_count = df.count() 

df = df.withColumn('unique_variant_id',concat(col("chromosome"), lit(":"),
                    col("start"),lit(':'),col('reference'),lit(':'),col('alternate'))) 

#print('\n\n\nRepartitioning gVCF parquet file...\n\n\n', file=sys.stderr)
#df=  df.repartitionByRange(200, "chromosome", "start")
#print(whole_genome_bed.rdd.mapPartitionsWithIndex(lambda x,it: [(x,sum(1 for _ in it))]).collect())

#print('Read in CADD SNPs (scores greater than 20)...'); time.sleep(2)
cadd_scores_gt20 = spark.read.option("header","true").parquet(input_snp_cadd_scores)
cadd_scores_gt20 = cadd_scores_gt20.withColumn("start", col('start').cast('int'))

#print('Read in CADD SNPs (scores greater than 20)...'); time.sleep(2)
cadd_indels = spark.read.option("header","true").parquet(input_indel_cadd_scores)
cadd_indels = cadd_indels.withColumn("start", col('start').cast('int'))

#print('Reading in all indels...'); time.sleep(2)
#cadd_ALL_indels = spark.read.option("header","true").parquet(input_ALL_indel_cadd_scores); 

#print('Reading eQTLs/highImpct dataset...'); time.sleep(2)
#eqtls_high_impact = spark.read.option("header","true").parquet(input_eqtls_high_impact); 
eqtl_highImpact_scored = spark.read.option("header","true").parquet(input_eqtls_high_impact_scored);
#eqtlhiImpactLen = eqtl_highImpact_scored.count()

#print('Reading BED...', file=sys.stderr); time.sleep(2)
whole_genome_bed = spark.read.option("header","true").parquet(input_bed)

df_noNonRef = df.where(~ (col('alternate') == '<NON_REF>')) # only need to get CADD scores for this df
#df_NonRef = df_join.where( (col('alternate') == '<NON_REF>')) # will add this back on later!
#dfNoNonRefLen = df_noNonRef.count()
#t_elapsed_read_data = time.time() - t0_read_data

#df_noNonRef_multiallelic = df_noNonRef.where(col('splitFromMultiAllelic') == 'false').count()
df_noNonRef = df_noNonRef.repartition(20,'chromosome','start')
df_noNonRef.cache()

whole_genome_bed = whole_genome_bed.coalesce(1)
whole_genome_bed.cache()

####### Filter patient gVCF by BED file  #############
BED_JOIN_TYPE = 'leftsemi'
#t0 = time.time(); print('\n\n\Filtering by BED file...\n\n', file=sys.stderr); time.sleep(3)
df_join = df_noNonRef.join(broadcast(whole_genome_bed), 
              (df_noNonRef['chromosome'] == whole_genome_bed['chromosome_bed']) &\
              (df_noNonRef['start'] >= whole_genome_bed['start_bed']) &\
              (df_noNonRef['end'] <= whole_genome_bed['end_bed']),BED_JOIN_TYPE )
    
#print(df_join.count()); time.sleep(120)
#df_join_multiallelic = df_join.where(col('splitFromMultiAllelic') == 'false').count()
  
#df_join_len = df_join.count()
#elapsed_bed_join = time.time() - t0
#print('Finished BED filtering in '+str(elapsed_bed_join/60)+' minutes\n'); 

#df_join.repartitionByRange(50, "chromosome", "start").write\
#  .mode('overwrite').partitionBy("chromosome").parquet('df_bed_leftsemi.parquet')     

# LOAD FILTERED BED IN HERE WHEN TESTING
#df_join = spark.read.option("header","true").parquet(input_fake_df_join)
#print(df.rdd.getNumPartitions());print(whole_genome_bed.rdd.getNumPartitions())

######################################################
####### Compute Joins to Find CADD scores ############
######################################################

df_snps = df_join.where((F.length("reference") == 1) & (F.length("alternate") == 1))                    
df_indels = df_join.where(~ ((F.length("reference") == 1) & (F.length("alternate") == 1)))

result_snps = df_snps.join(cadd_scores_gt20.select('unique_variant_id','cadd_score'), ["unique_variant_id"], "inner")
result_indels = df_indels.join(cadd_indels.select('unique_variant_id','cadd_score'),["unique_variant_id"], "inner")

#print('combining gt20 dfs...'); time.sleep(4)
results_gt20 = result_snps.union(result_indels) # #assert result_snps.columns == result_indels.columns
results_gt20 = results_gt20.select(result_snps.columns+[lit('').alias("symbol"),lit('').alias("rsID"),lit(0).alias('eqtl_boolean')])
'''
print(f'Length of df_snps: {df_snps.count()}')
print(f'Length of caddd matched snps: {result_snps.count()}')
print(f'Length of df_indels: {df_indels.count()}')
#print(f'Length of caddd matched indels: {result_indels.count()}')
time.sleep(40)

print('checking results from gt20...'); time.sleep(4)
results_gt20_chr15 = list(results_gt20.where(col('chromosome') == '15').toPandas()['unique_variant_id'])
df_join_chr15 = list(df_join.where(col('chromosome') == '15').toPandas()['unique_variant_id'])

flag_gt20 = 0
if(set(results_gt20_chr15).issubset(set(df_join_chr15))):
    print('Results gt20 is subset!'); time.sleep(20)
    flag_gt20 = 1'''


#assert result_indels.count() < df_indels.count()
#assert df_snps.count() == result_snps.count()

#snps_multi = result_snps.where(col('splitFromMultiAllelic') == 'false').count()
#indels_multi = result_indels.where(col('splitFromMultiAllelic') == 'false').count()

#df_join.write.mode('overwrite').partitionBy("chromosome").parquet("june20_gvcf_filtered.parquet")

##########################################################
### Compute CADD scores for eQTLs/High Impact Variants ###
##########################################################
#print('eqtl/hiImpact join...'); time.sleep(4)
eqtl_highImpact_scored_BS = df_join.join(
    eqtl_highImpact_scored.select('unique_variant_id','rsID','symbol','cadd_score','eqtl_boolean'),
    ['unique_variant_id'],
    'inner') #     df_join.unique_variant_id == eqtl_highImpact_scored.unique_variant_id,

'''
print(f'eqtl/hiImpact cadd scored df is {eqtl_highImpact_scored_BS.count()} rows long.')
time.sleep(20)

eqtl_highImpact_scored_BS_chr15 = list(eqtl_highImpact_scored_BS.where(col('chromosome') == '15').toPandas()['unique_variant_id'])

flag_eqtl = 0 
if(set(eqtl_highImpact_scored_BS_chr15).issubset(set(df_join_chr15))):
    print('Results eqtl/hiImpact is subset!'); time.sleep(20)
    flag_eqtl = 1'''

#print(eqtl_highImpact_scored_BS.columns)
#print(results_gt20.columns)
#time.sleep(20)

c = ['chromosome', 'start', 'end', 'reference', 'alternate', 'unique_variant_id','qual', 'INFO_DP', 'splitFromMultiAllelic', 'genotypes', 'symbol', 'rsID','cadd_score','eqtl_boolean']

#print('combining dfs...'); time.sleep(4)
df_scored = results_gt20.select(c).union(eqtl_highImpact_scored_BS.select(c))
#df_scored.count()

'''
df_scored_chr15 = list(df_scored.where(col('chromosome') == '15').toPandas()['unique_variant_id'])
flag_both = 0 
if(set(df_scored_chr15).issubset(set(df_join_chr15))):
    print('Results eqtl/hiImpact is subset!'); time.sleep(20)
    flag_both = 1'''
    
'''
with open('stats.txt', 'w') as f:
    f.write(f'len df_snps {df_snps.count()}\n')
    f.write(f'len df_indels {df_indels.count()}\n')
    f.write(f'len snp results {result_snps.count()}\n')
    f.write(f'len indel results {result_indels.count()}\n')
    f.write(f'len eqtl/hiImpact results {eqtl_highImpact_scored_BS.count()}\n')
    f.write(f'eqtl_hiImpact cols: {eqtl_highImpact_scored_BS.columns}\n')
    f.write(f'results_gt20 cols: {results_gt20.columns}\n')
    #f.write(f'flag_gt20 = {flag_gt20}\n')
    #f.write(f'flag_eqtl = {flag_eqtl}\n')
    #f.write(f'flag_both = {flag_both}\n')'''


# we have duplicate 'unique_variant_id's bc some genes map to multiple genes in the eqtl dataframe
# for now just choose one and drop the rest
df_scored_dedup = df_scored.dropDuplicates(['unique_variant_id']) 


VCF_FILE_ID = str(input_parquet).split('/')[-1].split('.')[0]
# For CHD cohort
if VCF_FILE_ID.startswith('BS_'):
    bs_name = VCF_FILE_ID
    SAVE_STRING = f'CHD_{bs_name}_scored_variants.parquet'
# For KUTD cohort    
elif VCF_FILE_ID.startswith('GF_'): 
    kutd_name = VCF_FILE_ID.replace('_KUTD','') 
    SAVE_STRING = f'KUTD_{kutd_name}_scored_variants.parquet'


#dedup_multi = df_scored_dedup.where(col('splitFromMultiAllelic') == 'false').count()
#t0 = time.time() 
#df_scored_dedup

df_scored_dedup.repartitionByRange(30, "chromosome", "start").write.mode('overwrite').partitionBy("chromosome").parquet(SAVE_STRING)  


#except:
#logging.exception('')


