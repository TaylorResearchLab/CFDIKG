# .cypher or .cyp are the preferred file extensions for cypher files

##### To get all distinct node labels:
MATCH (n) RETURN distinct labels(n)

#### Get total number of nodes for each node label
CALL apoc.meta.stats() YIELD labels
RETURN labels;

### View general schema 
CALL db.schema.visualization

### Deleting (and detaching) all nodes/relationships from a very large database  
# Must use apoc.periodic.iterate() instead of the regular query MATCH(n) DETACH DELETE n, to avoid JavaHeap Space error.
# https://stackoverflow.com/questions/51171928/difference-between-apoc-periodic-iterate-and-apoc-periodic-commit-when-deleting/51172771
CALL apoc.periodic.iterate(         
    "MATCH (n) RETURN n",
    "DETACH DELETE n",
    {batchSize:1000}) YIELD batches, total RETURN batches, total 

## Or When deleting the entire graph database, by far the best way is to simply stop the database, 
## rename/delete the graph store (data/graph.db (pre v3.x) or data/databases/graph.db (3.x forward) 
## or similar) directory, and start the database. This will build a fresh, empty database for you.

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

### get nodes that have a specific/certain property/attribute (use not exists for inverse)
match (n:Term) where exists (n.gene_id) delete n

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


####### Load nico's phenotype data
LOAD CSV WITH HEADERS FROM 
"file:///Users/stearb/downloads/upheno_mapping_all.csv" AS row 
with  row
create(x:label_x {phenotype:row.label_x})
create(y:label_y {phenotype:row.label_y})
with x,y
create (x)-[:CROSS_PHENOTYPE]->(y)
create (y)-[:X_PHENOTYPE]->(x)



#### Get stats/statistics/summary of connections in graph
MATCH (n) WHERE rand() <= 0.1
WITH labels(n) as labels, size(keys(n)) as props, size((n)--()) as degree
RETURN
DISTINCT labels,
count(*) AS NumofNodes,
avg(props) AS AvgNumOfPropPerNode,
min(props) AS MinNumPropPerNode,
max(props) AS MaxNumPropPerNode,
avg(degree) AS AvgNumOfRelationships,
min(degree) AS MinNumOfRelationships,
max(degree) AS MaxNumOfRelationships

###############################################################
##### Loading in homologies 2nd version (with hgnc ids) #######
###############################################################

// Create new Term nodes representing (homologous) mouse genes 
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///hgnc_2_mouse_homologs.csv" AS row
CREATE (t:Term {gene_id: row.mouse_symbol, gene_name:row.mouse_symbol, SUI:row.SUI, MGI:row.mgi_id } )

~~~ neo4j-admin import --nodes=Term="import/ADMIN-IMPORT-hgnc_2_mouse_homologs.csv"


// Create Index on the node types we want to connect with a :MOUSE_HOMOLOG relationship, so the next query doesnt take forever
CREATE INDEX FOR (t:Term) ON (t.gene_id);
CREATE INDEX FOR (c:Code) ON (c.CODE);

// Connect HGNC Code nodes to its corresponding mouse gene Term node with a :MOUSE_HOMOLOG relationship
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///hgnc_2_mouse_homologs.csv" AS row
MERGE (n:Code {SAB:'HGNC', CODE:row.hgnc_id})-[:MOUSE_HOMOLOG]->(t:Term {gene_id:row.mouse_symbol})

match (n:Code {SAB:'HGNC'})-[m:MOUSE_HOMOLOG]->(t:Term) RETURN n,m,t limit 5

###############################################################
##### Loading in genotype-phenotype data #######
###############################################################

:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///geno2pheno_mapping.csv" AS row
CREATE (mp:MP {name: row.mp_term_name, mp_term_id: row.mp_term_id, parameter_name:row.parameter_name,gene_id:row.marker_symbol})

CREATE INDEX FOR (mp:MP) ON (mp.gene_id);

// Connect MP nodes to mouse gene Term nodes, must make MP nodes of type :Concept/:Code?
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///geno2pheno_mapping.csv" AS row
MATCH (mp:MP {gene_id:row.marker_symbol}), (t:Term {gene_id:row.marker_symbol})
MERGE (t)-[:HAS_PHENOTYPE]->(mp)


###############################################################
##### Loading IMPC triples/turtle or .owl files with neosemantics plugin #######
###############################################################

## From https://archive.monarchinitiative.org/202011/rdf/

CREATE CONSTRAINT n10s_unique_uri ON (r:Resource) ASSERT r.uri IS UNIQUE;
CALL n10s.graphconfig.init();
CALL n10s.onto.import.fetch("file:///Users/stearb/desktop/R03_local/data/impc.ttl",
                        "Turtle",{addResourceLabels : TRUE})

## Must delete Resource node if you want to reimport RDF/Triples/Turtle data with neosemantics
MATCH (resource:Resource) DETACH DELETE resource;

