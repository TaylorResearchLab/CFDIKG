# Steps for building Petagraph
- are we going to make a distinction between the pure 'UMLS' graph and the graph that jonathan creates by adding several ontologies on top of the UMLS graph?
- should we just store all the datasets zipped on the cloud somewhere so they wont have to download it themselves?

#### Petagraph uses the UMLS Knowledge Graph (UMLS-KG) as its base graph. We then ingest ontologies and datasets on top of this graph. We do this by taking each dataset, extracting the relevant data and formating it into CSV files that Neo4j can understand. The UMLS-KG is  already in this specialized format so we simply add each datasets CSVs to the UMLS-KG CSVs. We use the bulk data import command ```neo4j-admin import``` to load the CSVs into a Neo4j instance. Documentation on this tool and the specific CSV format that Neo4j requires can be found [here](https://neo4j.com/developer/guide-import-csv/#batch-importer).

## 1. Human - Mouse Ortholog Relationships
#### Navigate to [HGNC's Ortholog Prediction Tool](https://www.genenames.org/tools/hcop/), scroll to the bottom and under 'Bulk Downloads' select  'Mouse' from the first drop down tab and '15 column' from the second drop down tab. Download this dataset and place it in the 

## 2.

