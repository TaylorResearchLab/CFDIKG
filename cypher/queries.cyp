# .cypher or .cyp are the preferred file extensions for cypher files

### Deleting (and detaching) all nodes/relationships from a very large database  
# Must use apoc.periodic.iterate() instead of the regular query MATCH(n) DETACH DELETE n, to avoid JavaHeap Space error.
# https://stackoverflow.com/questions/51171928/difference-between-apoc-periodic-iterate-and-apoc-periodic-commit-when-deleting/51172771
CALL apoc.periodic.iterate(         
    "MATCH (n) RETURN n",
    "DETACH DELETE n",
    {batchSize:1000}) YIELD batches, total RETURN batches, total 

##### Loading human-mouse homologous Gene IDs and creating a :HOMOLOGOUS relation to and from both lists
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///homologous_genes.csv" AS row
 MERGE (h:Human_gene {gene_id: row.Human})
 MERGE (m:Mouse_gene {gene_id: row.Mouse})
 MERGE (h)-[:HOMOLOGOUS]->(m)
 MERGE (m)-[:HOMOLOGOUS_mouse]->(h)


#### Loadng a human gene list with multiple properties #####
LOAD CSV WITH HEADERS FROM 
"file:///Users/stearb/desktop/neo4j_data/mygene_human_select_fields.csv" AS row 
with  row
CREATE (h:Human_gene {gene_id: row.symbol, gene_name:row.name, ensembl_gene_id:row.`ensembl.gene`,
ensembl_protein_id:row.`ensembl.protein`, gene_type:toUPPER(row.`ensembl.type_of_gene`)})
set h.MIM = CASE row.MIM when null then false else toInteger(row.MIM) END


### Dealing with missing/empty fields in the dataset in specific columns ####
LOAD CSV WITH HEADERS FROM "file:///Users/stearb/downloads/mygene_human_select_fields-2.csv" AS row 
with  row
MERGE (h:Human_gene {gene_id: row.symbol, gene_name:row.name, ensembl_gene_id:row.`ensembl.gene`,
ensembl_protein_id:row.`ensembl.protein`, 
gene_type:row.`ensembl.type_of_gene`})
set h.MIM = CASE row.MIM when null then false else row.MIM END    <--- use CASE to make empty fields == false

#### Use Neosemantics to stream in RDF file  
CALL n10s.rdf.stream.fetch("https://github.com/neo4j-labs/neosemantics/raw/3.5/docs/rdf/vw.owl","Turtle",{}) 
yield subject as s, predicate  as p, object as o

### Set unique constraint on a node property
CREATE CONSTRAINT gene_id_constraint ON (h:Human_gene) ASSERT h.gene_id IS UNIQUE;

### Create index 
CREATE INDEX ON :Album(Name)

### Drop all index and constraints #####
CALL apoc.schema.assert({}, {})

#### Look at all indexes and constraints ###
:schema


#### Preview the headers of your dataset
load csv with headers from 'file:///test.csv' as row with row limit 1 return keys(row);

#### To load a url with a space in it, replace the space with %20, (the url encoding)

#### If you get this error, 'Couldn't load the external resource at:  ....'
# comment out the dbms.directories.import=import line in the settings, so you can import data outside the import folder
# or uncomment dbms.security.allow_csv_import_from_file_urls=true
# or change  dbms.security.allow_csv_import_from_file_urls=D
# or sudo chown neo4j:adm <csv file location> to give permission
# ****  or just change the filepath to your local directory where the data is kept, don't put the data into neo4j desktop import/ folder 


#### To load data with column headers that have spaces, use backticks `row.Gene Symbols` to refer to them.

#### Use 'is not null' to skip lines that have empty values
# with row where row.Gene is not null




# Match all human nodes who's Gene ID starts with A and ends with 1
match (n:Human_gene)
where n.gene_id starts with 'A' AND n.gene_id ends with '1'
return n

###### Building gene homology graph model, with extra fields #####
//  import gene2gene homology
LOAD CSV WITH HEADERS FROM 
"file:///Users/stearb/desktop/neo4j_data/homologs_12.csv" AS row
 MERGE (h:Human_gene {gene_id: row.Human})
 MERGE (m:Mouse_gene {gene_id: row.Mouse})
 MERGE (h)-[:HOMOLOGOUS]->(m)
 MERGE (m)-[:HOMOLOGOUS_mouse]->(h)

// Update human gene nodes  with extra fields
LOAD CSV WITH HEADERS FROM 
"file:///Users/stearb/desktop/neo4j_data/mygene_human_select_fields.csv" AS row
 match (h:Human_gene {gene_id: row.symbol})
set h.gene_name=row.name, h.ensembl_gene_id=row.`ensembl.gene`,
h.ensembl_protein_id= row.`ensembl.protein`, h.gene_type=toUPPER(row.`ensembl.type_of_gene`)

// Update mouse gene nodes  with extra fields


###### Get homogolous genes  #########
## First, get list of genes ####
match (n:Human_gene)
where n.gene_id starts with 'AA'
with n
match (n)-[h:HOMOLOGOUS]-(hn)
return n.gene_id  as gid, type(h) as relationship, hn.gene_id  as mouse_gid


##### Use list to match nodes ######
match (h:Human_gene)  
where  h.gene_id in ["AAAS","AACS","AADAC","AADACL2","AADACL3","AADACL4"]
return h.ensembl_gene_id





##### Loading in the cars/owners/boats dataset #######






