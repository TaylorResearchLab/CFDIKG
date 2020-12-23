
// Create new Term nodes representing (homologous) mouse genes 
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///hgnc_2_mouse_homologs.csv" AS row
CREATE (t:Term {gene_id: row.mouse_symbol, gene_name:row.mouse_symbol, SUI:row.SUI, MGI:row.mgi_id } )

// Create Index on the node types we want to connect with a :MOUSE_HOMOLOG relationship, so the next query doesnt take forever
CREATE INDEX FOR (t:Term) ON (t.gene_id);
CREATE INDEX FOR (c:Code) ON (c.CODE);

// Connect HGNC Code nodes to its corresponding mouse gene Term node with a :MOUSE_HOMOLOG relationship
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///hgnc_2_mouse_homologs.csv" AS row
MERGE (n:Code {SAB:'HGNC', CODE:row.hgnc_id})-[:MOUSE_HOMOLOG]->(t:Term {gene_id:row.mouse_symbol})
match (n:Code {SAB:'HGNC'})-[m:MOUSE_HOMOLOG]->(t:Term) RETURN n,m,t limit 5


// Load in genotype-phenotype data 
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
