

##########################################################################
##### STEP 1: Loading/connecting homologous genes (with hgnc ids) ########  HGNC Code nodes <--[:Homologous]-->  Mouse gene Code nodes
##########################################################################  
// We should model mouse genes as Code nodes because human genes are Code nodes (HGNC Code nodes)

// Create new Code nodes representing (homologous) mouse genes, this query creates 66,848 new nodes
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///hgnc_2_mouse_homologs.csv" AS row
CREATE (t:Code {gene_id: row.mouse_symbol, gene_name:row.mouse_symbol, SUI:row.SUI, MGI:row.mgi_id, SAB: 'HGNC HCOP' } )   


// Create Index on the node types we want to connect with a :MOUSE_HOMOLOG relationship, so the next query doesnt take forever
CREATE INDEX FOR (t:Code) ON (t.gene_id);
CREATE INDEX FOR (c:Code) ON (c.CODE);

// Connect HGNC Code nodes to its corresponding mouse gene Code node with a :MOUSE_HOMOLOG relationship
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///hgnc_2_mouse_homologs.csv" AS row
MERGE (n:Code {SAB:'HGNC', CODE:row.hgnc_id})-[:MOUSE_HOMOLOG]->(t:Code {gene_id:row.mouse_symbol, })
MATCH (n:Code {SAB:'HGNC'})-[m:MOUSE_HOMOLOG]->(t:Code) RETURN n,m,t limit 5

############################################################### 
##### STEP 2: Loading in genotype-phenotype data ##############
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
------------------------------------------------------------------

// Create MP Code nodes. Shouldnt there be multiple gene per phenotype here?, We need to make the name of the phenotype into Term nodes
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///geno2pheno_mapping.csv" AS row
CREATE (mp:Code {name: row.mp_term_name, CODE: row.mp_term_id, parameter_name:row.parameter_name,gene_id:row.marker_symbol, SAB:'MP'})

CREATE INDEX FOR (mp:Code) ON (mp.CODE);

// Connect MP nodes to mouse gene Term nodes
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///geno2pheno_mapping.csv" AS row
MATCH (mp:Code {gene_id:row.marker_symbol}), (t:Term {gene_id:row.marker_symbol})
MERGE (t)-[:HAS_PHENOTYPE]->(mp)
                                                                                       
                                                                                       
##########################################################
###### STEP 3: Connect HPO and MP Concept nodes ##########   MATCH HPO Concept nodes to MP Concept nodes 
############## with Tiffanys mappings ####################                              
##########################################################      

                                             
// First mint new MP terms if MP terms in Tiffanys mappings are not present, using MERGE (index is already set)
// Do the same thing with the HPO terms.    
                                              
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///tiffs_mappings_ravel.csv" AS row                                              
MERGE (n:Code {SAB:'HPO',CODE:row.HP_ID})
MERGE (n:Code {SAB: 'MP', CODE: row.MPO_URI})       // This is creating 551 new nodes, bc there are 602 unique MP 
                                                    // terms in Tiffs list and only 51 of them overlap with the MP terms list from STEP 2
       
CREATE INDEX FOR (hpo:Code) ON (hpo.CODE);  // This was already done in step 1
CREATE INDEX FOR (mp:Code) ON (mp.CODE);    // this was already done in step 2       

// Connect HPO Concept nodes to MP Concept nodes       
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///tiffs_mappings_ravel.csv" AS row     
MATCH (hpo:Code {CODE: row.HP_ID}), (mp:Code {CODE: row.MPO_URI}),                                        
CREATE (hpo)-[r:pheno_crosswalk]->(mp)                
                                      

                                                     
# check if every HP term were importing is already in UMLS, use in list[] statement                                        
                                                                            
                                      
                                      
                                         
 Do we need human genotype to phenotype (HPO terms to human gene/genotype connections)?                                             
                                              
                                              
                                              
                                              
                                              
