"""
Script to filter a parquet file using a BED file
"""
import argparse
from argparse import RawTextHelpFormatter
import pyspark
import glow

parser = argparse.ArgumentParser(
        description = 'Script to filter parquet files. \n\
MUST BE RUN WITH spark-submit. For example: \n\
    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \n\
    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \n\
    --driver-memory 60G asd_parquet_filter.py',
    formatter_class=RawTextHelpFormatter)


parser.add_argument('--input_parquet', help='Parquet File to filter')
parser.add_argument('--input_bed', help='Bed file to use for filtering Parquet Files')
parser.add_argument('--output_basename',help='String to use as basename for output file [e.g.] task ID')


args = parser.parse_args()

input_parquet = args.input_parquet
input_bed = args.input_bed_file


# Create spark session
spark = (pyspark.sql.SparkSession.builder.appName("asd_filter").getOrCreate())

# Register glow
spark = glow.register(spark)

# Read in parquet file
parquet_df = spark.read.option('validationStringency','lenient')\
                        .format('parquet')\
                        .load(input_parquet)


#parquet_df = parquet_df.withColumn("start", df["start"]+1)


# Get biospecimen name ie 'BS_123456', for saving 
bs_name = parquet_df.withColumn('bs_id',parquet_df.genotypes.getItem(0).getItem('0')).select('bs_id').take(1)[0][0]

# Read in BED file
bed = spark.read.option("delimiter", ",")\
                .option("header","true")\
                .csv(input_bed)

# Filter variants 
filtered_df = df.join(bed, 
                      (df['contigName'] == bed['chrom']) &\
                      (df['start'] >= bed['chromStart']) &\
                      (df['end'] <= bed['chromEnd']) )

# Write to parquet
filtered_df.write.format("parquet").save(args.output_basename + 'asd_filtered_' +bs_name +'.parquet')
