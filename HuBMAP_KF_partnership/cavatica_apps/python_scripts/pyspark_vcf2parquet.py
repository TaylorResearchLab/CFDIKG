"""
Script to optionally normalize and convert input vcf to parquet file
"""
import argparse
from argparse import RawTextHelpFormatter
import glow
import pyspark
import time
import pandas as pd

time.sleep(60)
parser = argparse.ArgumentParser(
        description = 'Script to optionally normalize and convert input vcf to parquet file. \n\
MUST BE RUN WITH spark-submit. For example: \n\
    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \n\
    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \n\
    --driver-memory 60G pyspark_vcf2parquet.py',
    formatter_class=RawTextHelpFormatter)

parser.add_argument('--input_vcf', 
        help='VCF to convert')
parser.add_argument('--output_basename',
            help='String to use as basename for output file [e.g.] task ID')
parser.add_argument('--normalize_flag',action="store_true",
        help='Flag to normalize input vcf')
parser.add_argument('--reference_genome', nargs='?',
        help='Provide if normalizing vcf. Fasta index must also be included')
        
parser.add_argument('--input_kidney_file_map')

args = parser.parse_args()


def norm_vcf(vcf_df, ref_genome_path):
    split_vcf = glow.transform("split_multiallelics", vcf_df)
    norm_vcf = glow.transform("normalize_variants", split_vcf, reference_genome_path=ref_genome_path)
    return norm_vcf


# Create spark session
spark = (
    pyspark.sql.SparkSession.builder.appName("vcf2parquet")
    .getOrCreate()
    )
# Register so that glow functions like read vcf work with spark. Must be run in spark shell or in context described in help
spark = glow.register(spark)
vcf_path = args.input_vcf
# Read in vcf, normalize if flag given
vcf_df = spark.read.option('validationStringency','lenient').format('vcf').load(vcf_path)
if args.normalize_flag:
    vcf_df = norm_vcf(vcf_df, args.reference_genome)
    

manifest = pd.read_csv(args.input_kidney_file_map)
file_name_map = dict(zip(manifest['File Name'], manifest['File ID']))
    
# Write to parquet
#vcf_df.write.format("parquet").save(args.output_basename + '.parquet')
#vcf_df.write.format("parquet").save(file_name_map[vcf_path.split('/')[-1]] + '.parquet')

#vcf_df = vcf_df.withColumnRenamed("contigName","chromosome")


vcf_df.repartitionByRange(60, "contigName", "start").write\
    .mode('overwrite').partitionBy("contigName").parquet(file_name_map[vcf_path.split('/')[-1]] + '_KUTD.parquet')

