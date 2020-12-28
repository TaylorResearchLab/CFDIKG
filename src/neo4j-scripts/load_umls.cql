###############################################################
##### Loading in homologies (with hgnc ids) ################### HGNC Code nodes ----->  Homologous Mouse gene Term nodes
###############################################################

// Create new Term nodes representing (homologous) mouse genes 
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///hgnc_2_mouse_homologs.csv" AS row
CREATE (t:Term {gene_id: row.mouse_symbol, gene_name:row.mouse_symbol, SUI:row.SUI, MGI:row.mgi_id } )   

# Should we make mouse genes Term nodes? what kind of nodes are Human genes? --Concepts and Codes (HGNC)

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
##### Loading in genotype-phenotype data ###################### 
############################################################### 

HPO terms are modeled at the Code level, with a corresponding Concept node. There are also several Term nodes 
(varying names of the Code node) off of the HPO Code nodes like usual.  We should model the MP terms as Concept
nodes just like the HPO terms. Do we have the Term nodes to add to the MP Code nodes?
       
The HPO Concept nodes in the UMLS KG are connected to eachother like a normal ontology would be. Right now, our
MP terms are not modeled like a traditional ontology. Instead, we have MP <--> genes/genotypes and MP <--> HPO
connections, which are both mostly one-to-one mappings (but there are one-to-many mappings in both).

In the geno2pheno_mappings.csv file, we do have the columns 'MP_term' and 'top_MP_term', which could be used to
connect the MP term nodes in a simplistic way. Otherwise, maybe we can import MP.owl (and have all the nodes be 
Code nodes, attached to their Concept nodes, like the other ontologies in the UMLS KG) and just connect the 
corresponding HPO terms and the genes/genotypes afterwards.

Should we connect every MP code node to a MP concepts node...or just the top level MP nodes?
Are all HPO Code nodes attached to a HPO Concept node, or are just the top level HPO codes attached to Concept nodes?
match (n:Code {SAB:'HPO'}) return count(n) # 14,586 HPO Code nodes
match (n:Code {SAB:'HPO'})--(C:Concept) return count(n) # 16,270    , can't differentiate the Concept nodes so theres no way to tell what Concept node belongs to a HPO Code node
       
 
// Create MP Code nodes
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///geno2pheno_mapping.csv" AS row
CREATE (mp:Code {name: row.mp_term_name, mp_term_id: row.mp_term_id, parameter_name:row.parameter_name,gene_id:row.marker_symbol})

CREATE INDEX FOR (mp:Code) ON (mp.gene_id);

// Connect MP nodes to mouse gene Term nodes
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///geno2pheno_mapping.csv" AS row
MATCH (mp:Code {gene_id:row.marker_symbol}), (t:Term {gene_id:row.marker_symbol})
MERGE (t)-[:HAS_PHENOTYPE]->(mp)
                                                                                       
                                                                                       
######################################################
###### Connect HPO and MP Concept nodes ##############
#######  with Tiffanys mappings ######################                                
######################################################      

# First mint new MP terms if MP terms in Tiffanys mappings are not present
                                              
MATCH HPO Concept nodes to MP Concept nodes    
                                              
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///tiffs_mappings_ravel.csv" AS row    
                                              
MERGE                                                                    # CREATE/MERGE HPO terms in my list first because 
MATCH (hpo:Concept {ID: row.HP_ID}), (mp:Concept {ID: row.HP_ID}),       # We need to line up HPO terms in UMLS and HPO terms in tiffs file                                    
MERGE (hpo:Concept)-[r]                                             
                                              
                                              
                                              
 
                                         
                                              
                                              
Do we need human genotype to phenotype (HPO terms to human gene/genotype connections)?                                             
                                              
                                              
                                              
                                              
                                              
