cwlVersion: v1.0
class: CommandLineTool
id: pyspark-asd-parquet-filter
doc: 'Tool to filter a parquet file using a bed file'
requirements:
  - class: ShellCommandRequirement
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: asd_parquet_filter.py
        entry:
          $include: ./asd_parquet_filter.py

  - class: DockerRequirement
    dockerPull: 'pgc-images.sbgenomics.com/d3b-bixu/pyspark:3.1.2'
  - class: ResourceRequirement
    ramMin: ${ return inputs.ram * 1000 }
    coresMin: $(inputs.cpu)

baseCommand: [spark-submit]

arguments:
  - position: 0
    shellQuote: false
    valueFrom: >-
      --packages io.projectglow:glow-spark3_2.12:1.1.2
      --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec
      --driver-memory $(inputs.ram)G 
      asd_parquet_filter.py

inputs:
  input_parquet: { type: 'File', inputBinding: { prefix: "--input_parquet" }, doc: "Parquet to filter" }
  input_bed: { type: 'File', inputBinding: { prefix: "--input_bed" }, doc: "BED file to use to filter" }
  output_basename: { type: 'string', inputBinding: { prefix: "--output_basename" }, doc: "Output prefix of dirname for parquet files" }

  # Resource Control
  cpu: { type: 'int?', default: 36, doc: "CPU cores to allocate to this task" }
  ram: { type: 'int?', default: 60, doc: "GB of RAM to allocate to this task" }

outputs:
  parquet_file:
    type: 'File'
    outputBinding:
      glob: $(inputs.output_basename).parquet
    doc: "Filtered parquet file"
