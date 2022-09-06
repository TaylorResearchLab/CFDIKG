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
from pyspark.sql import SparkSession
from pyspark import SparkConf
from pyspark.sql.functions import col,collect_list, concat, lit, when, monotonically_increasing_id, concat_ws,broadcast 
import pyspark.sql.functions as F
#from pyspark.sql.types import StructType,StructField, StringType,IntegerType, FloatType, BooleanType, ArrayType
#import scipy.sparse as ss
import logging

'''
import  traceback # logging, sys,
logger = logging.getLogger('logger')
fh = logging.FileHandler('test.log')
logger.addHandler(fh)
def exc_handler(exctype, value, tb):
    logger.exception(''.join(traceback.format_exception(exctype, value, tb)))
sys.excepthook = exc_handler'''

parser = argparse.ArgumentParser( description = 'Script to filter parquet files. \n\
MUST BE RUN WITH spark-submit. For example: \n\
    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \n\
    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \n\
    --driver-memory 60G asd_parquet_filter.py',
    formatter_class=RawTextHelpFormatter)
    
parser.add_argument('--input_unique_variant_set', help='set of variants/locations to search genotypes for')
parser.add_argument('--input_gvcf_parquet', help='Parquet VCF File')
parser.add_argument('--input_bed', help='Bed file to use for filtering Parquet Files')
args = parser.parse_args()
input_unique_variant_set = args.input_unique_variant_set
input_gvcf_parquet = args.input_gvcf_parquet
input_bed = args.input_bed

spark = SparkSession.builder.master("local[*]").appName("Find_Variants").getOrCreate()

#bs_name = str(input_gvcf_parquet).split('/')[-1].split('.')[0]

#time.sleep(20)
#print(spark.sparkContext.getConf().getAll())
'''
time.sleep(30)
print(os.cpu_count())
executor_count = len(spark.sparkContext._jsc.sc().statusTracker().getExecutorInfos()) - 1
print(executor_count)
cores_per_executor = int(spark.sparkContext.getConf().get('spark.executor.cores','1'))
print(cores_per_executor)'''

print('Sleeping for 1 min.'); time.sleep(30)


length_chr_15=101991189 
nb_buckets = 100
length_bucket = length_chr_15 // nb_buckets

# This will just be a vector of unique_variant_locations
variants = spark.read.parquet(input_unique_variant_set)
variants = variants.withColumn('unique_location',concat(col("chromosome"),
                            lit(":"),col("start"),lit(":"),col("end")))

df = spark.read.parquet(input_gvcf_parquet)

df = df.select(col('contigName').alias('chromosome'),'start','end',col('referenceAllele').alias('reference'),
            col('alternateAlleles').alias('alternate'),'qual','INFO_DP', 'splitFromMultiAllelic','genotypes') \
        .withColumn('alternate',F.explode('alternate')) \
        .withColumn('chromosome',F.regexp_replace(col("chromosome"), "[chr,]", "") ) \
        .withColumn("start", df["start"]+1) \
        .withColumn('unique_variant_id',concat(col("chromosome"), lit(":"),col("start"),lit(':'),col('reference'),lit(':'),col('alternate'))) \
        .withColumn('unique_location',concat(col("chromosome"), lit(":"),col("start"),lit(":"),col("end"))) \
        .withColumn('bucket', F.floor(col('end') / length_bucket))

variants_noneqtl = variants#.where(col('eqtl_boolean') == 0)

df = df.repartition(1000, "chromosome", "bucket")

df = df.where(~ ((df.splitFromMultiAllelic == 'true') & (df.alternate == '<NON_REF>') ))


variants_noneqtl = variants_noneqtl.select(col('chromosome').alias('var_chrom'),
                                    col('start').alias('var_start'), F.floor(col('start') / length_bucket).alias('var_bucket'), col('end').alias('var_end'),col('unique_variant_id').alias('var_unique_variant_id'))


print('starting join...'); 

variants_noneqtl = variants_noneqtl.repartition(1000, "var_chrom", "var_bucket")

df_join = df.join(variants_noneqtl, 
              (df['chromosome'] == variants_noneqtl['var_chrom']) &\
              (df['bucket'] == variants_noneqtl['var_bucket']) &\
              (df['start'] <= variants_noneqtl['var_start']) &\
              (df['end'] >= variants_noneqtl['var_start']),'right' ) 
              
#print(df.count())

df_join = df_join.repartition(10,  "var_bucket")

df_join = df_join.withColumn('calls', df_join.genotypes.getItem(0).getItem('6'))
df_join = df_join.withColumn('calls_str',concat(df_join.calls.getItem(0), lit(":"), df_join.calls.getItem(1) ))
df_join = df_join.withColumn('AdditiveGenotype',when(df_join.calls_str.contains('-')  ,-9)\
                      .otherwise(df_join.calls.getItem(0) + df_join.calls.getItem(1)))

# 'var_chrom','var_start','var_end','var_unique_variant_id','unique_location'
df_join = df_join.drop('calls','calls_str')           

# Create Participant ID column (should just be one participant per file)
#df_join = df_join.withColumn('participant_id', df_join.genotypes.getItem(0).getItem('0'))
df_join = df_join.withColumn('INFO_DP',df_join.genotypes.getItem(0).getItem('10'))
df_join = df_join.withColumn('qual',df_join.genotypes.getItem(0).getItem('1'))
df_join = df_join.withColumn('PL',df_join.genotypes.getItem(0).getItem('9'))

df_join = df_join.withColumn('AdditiveGenotype',when((df_join.INFO_DP < 15) | (df_join.qual < 25) ,-9)\
                      .otherwise(df_join.AdditiveGenotype))
                      
df_join = df_join.where(~ ((df_join.splitFromMultiAllelic == 'true') & (df_join.alternate == '<NON_REF>') ))
#df_join = df_join.drop(*("splitFromMultiAllelic")).dropDuplicates(['unique_variant_id','AdditiveGenotype'])

df_join = df_join.withColumn('PL_00',df_join.PL.getItem(0)).withColumn('PL_01',df_join.PL.getItem(1)).withColumn('PL_11',df_join.PL.getItem(2))

df_join = df_join.withColumn('AdditiveGenotype',when((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\
                                           (col('AdditiveGenotype') == 0 ),-9).otherwise(df_join.AdditiveGenotype))
                                           
df_join = df_join.withColumn('AdditiveGenotype',when(((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\
                     (df_join.PL_11 == 0)) & (col('AdditiveGenotype') == 0 ) ,-9).otherwise(df_join.AdditiveGenotype))

df_join = df_join.drop(*("PL","PL_00","PL_01","PL_11","splitFromMultiAllelic","genotypes","INFO_DP","qual"))           
df_join = df_join.na.fill(value=-9,subset=["AdditiveGenotype"])

#dfj_cnt = df_join.count()
#print(dfj_cnt)


#[i for i in df_join.columns if not i.startswith('buck')]
df_join.write.mode('overwrite').partitionBy("chromosome").parquet('jeremy_results_aug7.parquet') 
# .repartition(10,'chromosome','bucket')
# .repartitionByRange(30, "chromosome", "start")

sys.exit()
















t0 = time.time()

# This will just be a vector of unique_variant_locations
variants = spark.read.parquet(input_unique_variant_set)
variants = variants.withColumn('unique_location',concat(col("chromosome"),
                            lit(":"),col("start"),lit(":"),col("end")))\

#var_len = variants.count()   

df = spark.read.parquet(input_gvcf_parquet)

df = df.select(col('contigName').alias('chromosome'),'start','end',col('referenceAllele').alias('reference'),
            col('alternateAlleles').alias('alternate'),'qual','INFO_DP', 'splitFromMultiAllelic','genotypes')\
        .withColumn('alternate',F.explode('alternate')).withColumn('chromosome',F.regexp_replace(col("chromosome"), "[chr,]", "") ).withColumn("start", df["start"]+1)\
        .withColumn('unique_variant_id',concat(col("chromosome"),lit(":"),col("start"),lit(':'),col('reference'),lit(':'),col('alternate'))).withColumn('unique_location',concat(col("chromosome"),
                            lit(":"),col("start"),lit(":"),col("end")))
                            
tend_read = time.time() - t0            



#df = df.where(~ (col('alternate') == '<NON_REF>'))
##################################################################

#df = df.repartition(300, "chromosome", "start")
#df = df.where(col('chromosome') == '15') 
#print(df.count()); time.sleep(10)

df = df.repartitionByRange(2400, "chromosome", "start")
#print('done repartitioning...'); time.sleep(5)
#print('Number of partitions: '+str(df.rdd.getNumPartitions()))

t0  = time.time()
variants_noneqtl = variants.where(col('eqtl_boolean') == 0)

#variants_noneqtl = variants_noneqtl.repartition(30, "chromosome", "start")
#variants_noneqtl = variants_noneqtl.coalesce(1)
#assert variants_noneqtl.rdd.getNumPartitions() == 1
#vnon_cnt = variants_noneqtl.count()
#print(f'Done removing eqtl variants from search space... Non-eqtl count: {vnon_cnt}'); #time.sleep(5)
t_var_noneqtl = time.time() - t0

t0 = time.time(); 
  
#c = df_chrom.count()
#variants_noneqtl = variants_noneqtl.where(col('chromosome') == '15')  #c2 = var_chrom.count()
#vnon_cnt_dedup = var_chrom.dropDuplicates().count()
variants_noneqtl = variants_noneqtl.select(col('chromosome').alias('var_chrom'),
                                    col('start').alias('var_start'), col('end').alias('var_end'),col('unique_variant_id').alias('var_unique_variant_id'))

variants_noneqtl = variants_noneqtl.repartitionByRange(30, "var_chrom", "var_start")
#variants_noneqtl = variants_noneqtl.repartition(100, "chromosome", "start")
#variants_noneqtl = variants_noneqtl.coalesce(1)
#var_chrom1 = variants_noneqtl.where(col('var_chrom') == '1')
#var_chrom1.cache()
#variants_noneqtl.cache()    

#df_chrom1 = df.where(col('chromosome') == '1')

tend_subset = time.time() - t0;                                            

t0 = time.time();   
# search for direct matches and then drop them from each df,
'''df_join = df_chrom1.join(broadcast(var_chrom1), 
              (df_chrom1['chromosome'] == var_chrom1['var_chrom']) &\
              (df_chrom1['start'] <= var_chrom1['var_start']) &\
              (df_chrom1['end'] >= var_chrom1['var_start']),'right' )'''
              
variants_noneqtl.count()
#variants_noneqtl.cache()
df.count()

print('starting join...'); time.sleep(30)

df_join = df.join(variants_noneqtl, 
              (df['chromosome'] == variants_noneqtl['var_chrom']) &\
              (df['start'] <= variants_noneqtl['var_start']) &\
              (df['end'] >= variants_noneqtl['var_start']),'right' ) 
        
'''df_join = variants_noneqtl.join(df, 
              (df['chromosome'] == variants_noneqtl['chromosome']) &\
              (df['start'] <= variants_noneqtl['start']) &\
              (df['end'] >= variants_noneqtl['start']),'left' )'''              

dfj_cnt = df_join.count()
tend_filter = time.time() - t0;


#df_parts = df.rdd.mapPartitions(lambda it: [sum(1 for _ in it)]).collect()
#var_parts = variants_noneqtl.rdd.mapPartitions(lambda it: [sum(1 for _ in it)]).collect()
df_join_parts = df_join.rdd.mapPartitions(lambda it: [sum(1 for _ in it)]).collect()

with open('stats.txt', 'w') as f:
    f.write(f'df_JOIN max/min/mean partition size: max: {max(df_join_parts)}, min: {min(df_join_parts)}, mean: {np.mean(df_join_parts)}\n')
    f.write(f'df_JOIN num partitions is {len(df_join_parts)}')
#    f.write(f'num df partitions: {len(df_parts)}, num var partitions: {len(var_parts)}\n')
#    f.write(f'df_parts: {df_parts}\n')
#    f.write(f'var_parts: {var_parts}\n')
#    f.write(f'df max/min/mean partition size: max: {max(df_parts)}, min: {min(df_parts)}, mean: {np.mean(df_parts)}\n')
#   f.write(f'var max/min/mean partition size: max: {max(var_parts)}, min: {min(var_parts)}, mean: {np.mean(var_parts)}\n')

#with open('stats.txt', 'w') as f:
#    f.write(f' join took {tend_filter/60} minutes and df is {dfj_cnt} rows long\n')
#    f.write(f' df len: {df.count()}  and var len: {variants_noneqtl.count()}\n')
    
#df_join.write.parquet('find_variants_test_july28.parquet')
#df_join = df_join.coalesce(1)


############################
###### Post processing #####
############################
#print('\n\n\POST PROCESSING...\n\n\n'); time.sleep(20)
df_join = df_join.withColumn('calls', df_join.genotypes.getItem(0).getItem('6'))\
        .withColumn('calls_str',concat(df_join.calls.getItem(0), lit(":"), df_join.calls.getItem(1) ))\
        .withColumn('AdditiveGenotype',when(df_join.calls_str.contains('-')  ,-9)\
                  .otherwise(df_join.calls.getItem(0) + df_join.calls.getItem(1)))\
        .withColumn('participant_id', df_join.genotypes.getItem(0).getItem('0'))\
        .withColumn('INFO_DP',df_join.genotypes.getItem(0).getItem('10'))\
        .withColumn('qual',df_join.genotypes.getItem(0).getItem('1'))\
        .withColumn('PL',df_join.genotypes.getItem(0).getItem('9'))\
        .withColumn('AdditiveGenotype',when((df_join.INFO_DP < 15) | (df_join.qual < 25) ,-9)\
                  .otherwise(df_join.AdditiveGenotype))\
        .where(~ ((df_join.splitFromMultiAllelic == 'true') & (df_join.alternate == '<NON_REF>') ))\
        .withColumn('PL_00',df_join.PL.getItem(0)).withColumn('PL_01',df_join.PL.getItem(1))\
        .withColumn('PL_11',df_join.PL.getItem(2))\
        .withColumn('AdditiveGenotype',when((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\
                           (col('AdditiveGenotype') == 0 ),-9).otherwise(df_join.AdditiveGenotype))\
        .withColumn('AdditiveGenotype',when(((df_join.PL_00 == 0) & (df_join.PL_01 == 0) &\
                 (df_join.PL_11 == 0)) & (col('AdditiveGenotype') == 0 ) ,-9).otherwise(df_join.AdditiveGenotype)).drop(*("PL","PL_00","PL_01","PL_11"))

'''
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

# Maybe drop all -9's bc if its not found its -9 anyway? what % of -9's do we have?
df_cnt2 = df_join.count()
'''

#tend_post_process = time.time() - t0

#with open('stats.txt', 'w') as f:
#    f.write(f' join took {tend_filter/60} minutes and df is {dfj_cnt} rows long\n')
#    f.write(f' post process took {tend_post_process/60} minutes and df is now {df_cnt2} rows long\n')



'''
#print('\n\n\ANTI-JOIN...\n\n\n'); time.sleep(20)
t0 = time.time()
# Get list of these vars/locations and get the rows of vars that are not in this list, do anti-join
# and set these variants to -9 (missiing)
df_join = df_join.select(['chromosome','start','end','unique_location',col('unique_variant_id').alias('var_unique_variant_id') ,'AdditiveGenotype'])

unmatched_df = variants_noneqtl.join(df_join, ['var_unique_variant_id'],'left_anti')
non_matched_vars = unmatched_df.count()
df_select = df_join.select(['var_unique_variant_id','AdditiveGenotype'])

unmatched_select = unmatched_df.select(['var_unique_variant_id']).drop('AdditiveGenotype').withColumn('AdditiveGenotype',lit(-9))

df_new_genotypes = df_select.union(unmatched_select)
#df_new_cnt = df_new_genotypes.count()
tend_left_anti = time.time() - t0;

#print('\n\n\nSAVING...\n\n\n'); time.sleep(20)
t0 = time.time();    
#df_new_genotypes.repartitionByRange(30, "chromosome", "start").mode('overwrite').partitionBy("chromosome").parquet('new_genotypes_july_30p.parquet') 
#df_new_genotypes.repartition(10, "unique_variant_id").write.parquet('new_genotypes_july14.parquet')
    
    
# MUST TEST THIS
CADD_SCORED_FILE_ID = str(input_parquet).split('/')[-1].split('.')[0]
# For CHD cohort
if CADD_SCORED_FILE_ID.startswith('BS_'):
    bs_name = CADD_SCORED_FILE_ID
    SAVE_STRING = f'CHD_{bs_name}_scored_variants.parquet'
# For KUTD cohort    
elif CADD_SCORED_FILE_ID.startswith('GF_'): 
    kutd_name = CADD_SCORED_FILE_ID.replace('_KUTD','') 
    SAVE_STRING = f'KUTD_{kutd_name}_scored_variants.parquet'


df_new_genotypes.coalesce(1).write.parquet('new_genotypes_july20_reverse_join_args.parquet')
#df_new_genotypes.count()
tend_save = time.time() - t0;




with open('stats.txt', 'w') as f:
    #f.write(f'calling df.count() took {tend_subset/60} minutes\n')
    #f.write(f'Removing eqtls took {t_var_noneqtl/60} min, we now have {vnon_cnt} variants out of the {var_len} we started with.\n')
    f.write(f'Big join took {tend_filter/60} minutes')
    #f.write(f'Big JOIN of df ({c}) w/ variants ({vnon_cnt}) took {tend_filter/60} minutes and is {dfj_cnt} rows long\n')
    f.write(f'Post proccessing part took: {tend_post_process/60} min.\n')
    f.write(f'Number of unmatched variants is {non_matched_vars}\n')
    #f.write(f'Unique Variants in variants_noneqtl is {vnon_cnt_dedup}\n')
    #f.write(f'After post processing, df_join now has {df_cnt2} variants\n')
    #f.write(f'df w/ new GTs has {df_new_cnt} rows and {df_new_genotypes.dropDuplicates().count()} unique rows\n')
    f.write(f'Doing left anti join took {tend_left_anti/60} min\n')
    f.write(f'Saving took {tend_save/60} min\n\n')
   
    #f.write("Save command:     df_join.write.repartitionByRange(30, 'chromosome', 'start').mode('overwrite').partitionBy('chromosome').parquet('test_FULL_join_july_30p.parquet') ")
    #f.write(f'len of anti_join {v}')

'''


    
    
