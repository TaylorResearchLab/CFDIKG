# Steps for building Petagraph

#### Petagraph uses the UMLS Knowledge Graph (UMLS-KG) as its base graph (are we going to make a distinction between pure UMLS graph and the graph that jonathan creates by adding several ontologies on top of the UMLS graph?). We then ingest ontologies and datasets on top of this graph. We do this by taking each dataset and extracting the relevant data and formating it into CSV files that Neo4j can understand. The UMLS-KG is  already in this specialized format so we simply add each datasets CSVs to the UMLS-KG CSVs.

## 1. Human - Mouse Ortholog Relationships
#### Navigate to [HGNC's Ortholog Prediction Tool](https://www.genenames.org/tools/hcop/), scroll to the bottom and under 'Bulk Downloads' select  'Mouse' from the first drop down menu option and '15 column' from the second drop down menu option. Download this dataset. 

# should we just store all the datasets on the cloud somewere so they wont have to download it themselves?


