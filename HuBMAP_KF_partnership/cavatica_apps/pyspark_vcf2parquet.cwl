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
      "id": "input_vcf",
      "type": "File",
      "inputBinding": {
        "prefix": "--input_vcf",
        "shellQuote": true,
        "position": 0
      },
      "doc": "VCF to convert"
    },
    {
      "id": "output_basename",
      "type": "string?",
      "doc": "Output prefix of dirname for parquet files. Can be skipped if `sample_id` set and you want to use that"
    },
    {
      "id": "normalize_flag",
      "type": "boolean?",
      "inputBinding": {
        "prefix": "--normalize_flag",
        "shellQuote": true,
        "position": 0
      },
      "doc": "Use if you want to normalize before output"
    },
    {
      "id": "reference_genome",
      "type": "File?",
      "inputBinding": {
        "prefix": "--reference_genome",
        "shellQuote": true,
        "position": 0
      },
      "doc": "Provide if normalizing vcf. Fasta index must also be included",
      "secondaryFiles": [
        {
          "pattern": ".fai",
          "required": true
        }
      ]
    },
    {
      "id": "cpu",
      "type": "int?",
      "doc": "CPU cores to allocate to this task",
      "default": 36
    },
    {
      "id": "ram",
      "type": "int?",
      "doc": "GB of RAM to allocate to this task",
      "default": 60
    },
    {
      "id": "input_kidney_file_map",
      "type": "File?",
      "inputBinding": {
        "prefix": "--input_kidney_file_map",
        "shellQuote": false,
        "position": 0
      }
    }
  ],
  "outputs": [
    {
      "id": "parquet_dir",
      "doc": "Resultant parquet file directory bundle",
      "type": "Directory",
      "outputBinding": {
        "glob": "*.parquet",
        "loadListing": "deep_listing"
      }
    }
  ],
  "doc": "Tool to optionally normalize and convert input vcf to parquet file",
  "label": "pyspark_vcf2parquet",
  "arguments": [
    {
      "shellQuote": false,
      "position": 0,
      "valueFrom": "--packages io.projectglow:glow-spark3_2.12:1.1.2 --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec --driver-memory $(inputs.ram)G  pyspark_vcf2parquet.py ${\n  var arg = \" --output_basename \";\n  if(inputs.output_basename === null){\n    arg += inputs.input_vcf.metadata[\"sample_id\"];\n  }\n  else{\n    arg += inputs.output_basename;\n  }\n  return arg;\n}"
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
      "dockerPull": "pgc-images.sbgenomics.com/d3b-bixu/pyspark:3.1.2"
    },
    {
      "class": "InitialWorkDirRequirement",
      "listing": [
        {
          "entryname": "pyspark_vcf2parquet.py",
          "entry": "\"\"\"\nScript to optionally normalize and convert input vcf to parquet file\n\"\"\"\nimport argparse\nfrom argparse import RawTextHelpFormatter\nimport glow\nimport pyspark\nimport time\nimport pandas as pd\n\ntime.sleep(60)\nparser = argparse.ArgumentParser(\n        description = 'Script to optionally normalize and convert input vcf to parquet file. \\n\\\nMUST BE RUN WITH spark-submit. For example: \\n\\\n    spark-submit --packages io.projectglow:glow-spark3_2.12:1.1.2 \\n\\\n    --conf spark.hadoop.io.compression.codecs=io.projectglow.sql.util.BGZFCodec \\n\\\n    --driver-memory 60G pyspark_vcf2parquet.py',\n    formatter_class=RawTextHelpFormatter)\n\nparser.add_argument('--input_vcf', \n        help='VCF to convert')\nparser.add_argument('--output_basename',\n            help='String to use as basename for output file [e.g.] task ID')\nparser.add_argument('--normalize_flag',action=\"store_true\",\n        help='Flag to normalize input vcf')\nparser.add_argument('--reference_genome', nargs='?',\n        help='Provide if normalizing vcf. Fasta index must also be included')\n        \nparser.add_argument('--input_kidney_file_map')\n\nargs = parser.parse_args()\n\n\ndef norm_vcf(vcf_df, ref_genome_path):\n    split_vcf = glow.transform(\"split_multiallelics\", vcf_df)\n    norm_vcf = glow.transform(\"normalize_variants\", split_vcf, reference_genome_path=ref_genome_path)\n    return norm_vcf\n\n\n# Create spark session\nspark = (\n    pyspark.sql.SparkSession.builder.appName(\"vcf2parquet\")\n    .getOrCreate()\n    )\n# Register so that glow functions like read vcf work with spark. Must be run in spark shell or in context described in help\nspark = glow.register(spark)\nvcf_path = args.input_vcf\n# Read in vcf, normalize if flag given\nvcf_df = spark.read.option('validationStringency','lenient').format('vcf').load(vcf_path)\nif args.normalize_flag:\n    vcf_df = norm_vcf(vcf_df, args.reference_genome)\n    \n\nmanifest = pd.read_csv(args.input_kidney_file_map)\nfile_name_map = dict(zip(manifest['File Name'], manifest['File ID']))\n    \n# Write to parquet\n#vcf_df.write.format(\"parquet\").save(args.output_basename + '.parquet')\n#vcf_df.write.format(\"parquet\").save(file_name_map[vcf_path.split('/')[-1]] + '.parquet')\n\n#vcf_df = vcf_df.withColumnRenamed(\"contigName\",\"chromosome\")\n\n\nvcf_df.repartitionByRange(60, \"contigName\", \"start\").write\\\n    .mode('overwrite').partitionBy(\"contigName\").parquet(file_name_map[vcf_path.split('/')[-1]] + '_KUTD.parquet')\n\n\n",
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
      "sbg:modifiedOn": 1646156776,
      "sbg:revisionNotes": "Copy of d3b-bixu/kf-gvcf-merge-dev/pyspark_vcf2parquet/0"
    },
    {
      "sbg:revision": 1,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1646169864,
      "sbg:revisionNotes": "change input_vcf to input_vcf_path"
    },
    {
      "sbg:revision": 2,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1646170058,
      "sbg:revisionNotes": "change code to take a folder of vcfs"
    },
    {
      "sbg:revision": 3,
      "sbg:modifiedBy": "brownm28",
      "sbg:modifiedOn": 1646423706,
      "sbg:revisionNotes": "Uploaded using sbpack v2021.10.07. \nSource: \nrepo: https://github.com/kids-first/kf-germline-workflow\nfile: tools/pyspark_vcf2parquet.cwl\ncommit: (uncommitted file)"
    },
    {
      "sbg:revision": 4,
      "sbg:modifiedBy": "brownm28",
      "sbg:modifiedOn": 1646424426,
      "sbg:revisionNotes": "Uploaded using sbpack v2021.10.07. \nSource: \nrepo: https://github.com/kids-first/kf-germline-workflow\nfile: tools/pyspark_vcf2parquet.cwl\ncommit: (uncommitted file)"
    },
    {
      "sbg:revision": 5,
      "sbg:modifiedBy": "brownm28",
      "sbg:modifiedOn": 1646425375,
      "sbg:revisionNotes": "Uploaded using sbpack v2021.10.07. \nSource: \nrepo: https://github.com/kids-first/kf-germline-workflow\nfile: tools/pyspark_vcf2parquet.cwl\ncommit: (uncommitted file)"
    },
    {
      "sbg:revision": 6,
      "sbg:modifiedBy": "brownm28",
      "sbg:modifiedOn": 1646496843,
      "sbg:revisionNotes": "Uploaded using sbpack v2021.10.07. \nSource: \nrepo: https://github.com/kids-first/kf-germline-workflow\nfile: tools/pyspark_vcf2parquet.cwl\ncommit: (uncommitted file)"
    },
    {
      "sbg:revision": 7,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657841360,
      "sbg:revisionNotes": "a"
    },
    {
      "sbg:revision": 8,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657842693,
      "sbg:revisionNotes": "add file id --> file name map file for liver vcf's"
    },
    {
      "sbg:revision": 9,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657894284,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 10,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1657902220,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 11,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658172910,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 12,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658173438,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 13,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658173809,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 14,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658174518,
      "sbg:revisionNotes": ""
    },
    {
      "sbg:revision": 15,
      "sbg:modifiedBy": "stearb2",
      "sbg:modifiedOn": 1658231653,
      "sbg:revisionNotes": ""
    }
  ],
  "sbg:image_url": null,
  "sbg:appVersion": [
    "v1.2"
  ],
  "id": "https://cavatica-api.sbgenomics.com/v2/apps/taylordm/taylor-urbs-r03-kf-cardiac/pyspark_vcf2parquet/15/raw/",
  "sbg:id": "taylordm/taylor-urbs-r03-kf-cardiac/pyspark_vcf2parquet/15",
  "sbg:revision": 15,
  "sbg:revisionNotes": "",
  "sbg:modifiedOn": 1658231653,
  "sbg:modifiedBy": "stearb2",
  "sbg:createdOn": 1646156776,
  "sbg:createdBy": "stearb2",
  "sbg:project": "taylordm/taylor-urbs-r03-kf-cardiac",
  "sbg:sbgMaintained": false,
  "sbg:validationErrors": [],
  "sbg:contributors": [
    "brownm28",
    "stearb2"
  ],
  "sbg:latestRevision": 15,
  "sbg:publisher": "sbg",
  "sbg:content_hash": "accc85d4ddb2ed5b1064391aaba208821b1b1de825a76a1614e35a5610c768256",
  "sbg:workflowLanguage": "CWL"
}
