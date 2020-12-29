All UMLS Code nodes have exactly 3 attributes (CODE, CodeID, SAB)

For example a HGNC Code nodes attributes look like this:  CODE:'HGNC:787' 
                                                          CodeID:'HGNC HGNC:787'  
                                                          SAB:'HGNC'    
                                                          (plus a mandatory ID <id>:13381814)

and a HPO Code node looks like:     CODE:'HP:0001928' 
                                    CodeID: 'HPO HP:0001928' 
                                    SAB:'HPO'                             
                                    (plus a mandatory ID <id>:13355342)


Do we want to follow this form exactly? If so, where will we put the additional node information like MGI ID, ENSEMBL ID etc,
Model them as Terms? Or as additional Codes? Or just as attributes on the original nodes?


Maybe just keep them as attributes on the original nodes for now. 

##change merges to match when needed

##########################################################################
##### STEP 1: Loading/connecting homologous genes (with hgnc ids) ########  HGNC Code nodes <-[:Homologous]->  Mouse gene Code nodes
##########################################################################  

 We should model mouse genes as Code nodes because human genes are Code nodes (HGNC Code nodes)
Create new Code nodes representing (homologous) mouse genes

// Create Index on the node types we want to connect with a :MOUSE_HOMOLOG relationship
CREATE INDEX FOR (t:Code) ON (t.gene_id);
CREATE INDEX FOR (c:Code) ON (c.CODE);

// This query does (after changing from create to merge): Added 22295 labels, created 22295 nodes, set 111475 properties
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///hgnc_2_mouse_homologs.csv" AS row
MERGE (t:Code {gene_id: row.mouse_symbol, gene_name:row.mouse_symbol, SUI:row.SUI, MGI:row.mgi_id, SAB: 'HGNC HCOP' } )   

// Connect HGNC Code nodes to its corresponding mouse gene Code node with a :MOUSE_HOMOLOG relationship
// This query does: Added 66754 labels, created 66754 nodes, set 133508 properties, created 66754 relationships
:auto USING PERIODIC COMMIT 10000 
LOAD CSV WITH HEADERS FROM "file:///hgnc_2_mouse_homologs.csv" AS row
MATCH (n:Code {SAB:'HGNC', CODE:row.hgnc_id})
MERGE (n)-[:MOUSE_HOMOLOG]->(t:Code {gene_id:row.mouse_symbol, SAB:'HGNC HPOC' })

#  Maybe change gene_id attribute to CODE in mouse gene nodes, to better match HGNC nodes
# Why is this query creating so many nodes????
# make sure each query is adding the right number of new nodes
# make sure attribute signatures match for nodes of the same type 

#  check things look good: MATCH (n:Code {SAB:'HGNC'})-[m:MOUSE_HOMOLOG]->(t:Code) RETURN n,m,t limit 5



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
# match (n:Code {SAB:'HPO'}) return count(n) # 14,586 HPO Code nodes
# match (n:Code {SAB:'HPO'})--(C:Concept) return count(n) # 16,270 
------------------------------------------------------------------


// Create MP Code nodes. Shouldnt there be multiple genes per phenotype here? Unless I unraveled the genes column in Python (have to check on this),
// We might want to make the name of the phenotype into Term nodes
// This query does: Added 60172 labels, created 60172 nodes, set 299110 properties
:auto USING PERIODIC COMMIT 10000 
LOAD CSV WITH HEADERS FROM "file:///geno2pheno_mapping.csv" AS row
MERGE (mp:Code {name: row.mp_term_name, CODE: row.mp_term_id, parameter_name:row.parameter_name,gene_id:row.marker_symbol, SAB:'MP'})

#### change create to merge???,,, null value in row 14?
##### with merge (and  no null vals anymore), Added 36478 labels, created 36478 nodes, set 182390 properties,,, looks better!


// Connect MP nodes to mouse gene Term nodes
// This query does: Added 12016 labels, created 12016 nodes, set 12016 properties, created 6008 relationships
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///geno2pheno_mapping.csv" AS row
MERGE (t:Code {gene_id:row.marker_symbol})-[:HAS_PHENOTYPE]->(mp:Code {gene_id:row.marker_symbol, SAB:'HGNC HPOC'}) # added in the SAB specification here, still needs testing
                                                                                       
                                                                                       
##########################################################
###### STEP 3: Connect HPO and MP Concept nodes ##########  HPO Concept nodes <-[pheno_crosswalk]-> MP Concept nodes 
############## with Tiffanys mappings ####################                              
##########################################################      

# There are multiple HPO nodes with the same name, each connected to a different MP term. None of the HPO term nodes  are the actual HGNC nodes
                                             
// First mint new MP terms if MP terms in Tiffanys mappings are not present, using MERGE (index is already set)
// Do the same thing with the HPO terms. 
// This query is creating only 551 new nodes, bc there are 602 unique MP terms in Tiffs list and only 51 of them overlap with the MP terms list from STEP 2
// Split these 2 lines apart to see exactly how many new nodes have been created by each query.
// This query does: Added 551 labels, created 551 nodes, set 1102 properties                                            
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM  "file:///tiffs_mappings_ravel.csv" AS row                                              
MERGE (hpo:Code {SAB:'HPO',CODE:row.HP_ID})
MERGE (mp:Code {SAB: 'MP', CODE: row.MPO_URI})        
   
// Connect HPO Concept nodes to MP Concept nodes  
// This query does: Added 2442 labels, created 2442 nodes, set 2442 properties, created 1221 relationships,
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///tiffs_mappings_ravel.csv" AS row     
MERGE (hpo:Code {CODE: row.HP_ID})-[r:pheno_crosswalk]->(mp:Code {CODE: row.MPO_URI})                                        

// change this CREATE to MERGE,, after using merge were still creating 2438 nodes, why??
                                                     
                                                     
// check if every HP term we're importing is already in UMLS, use in list[] statement                                        
                                                                            
                                                                         
 Do we need/have human genotype to phenotype (HPO terms to human gene/genotype connections)?  
 --This is the point of building the graph because comprehensive data of this type does not exist  
   at least for congenital heart disease, structural birth defects, etc.
 
 
 
 #####################################
 ###### STEP 4. Add GTEx data ########
 #####################################
 ...
 
 #####################################
 ######  STEP 5. Add MSigDB data #####
 #####################################
 ... Gene to pathways
 
 #####################################
 ##### STEP 6. Add Gene-Gene and #####
 #### Protein-Protein Interaction ####
 #####################################
 ...
 
 
 
 
 
 #####################################
 ##########  Using the graph #########
 #####################################
 
BASIC QUESTION: Starting with a Kids First HPO term, can we query the graph with the following pattern to identify relevant human genes?
GENERAL PATTERN:   (HPO_term)--(MP_term)--(Mouse_gene_list)--(Human_gene_list)



// Query using a single HPO term, ie. HP:0001234
_____________________________________________________________________
MATCH (kf_hpo:Code {CODE: "HP:0001234"})-[hpo2mp:pheno_crosswalk]-(mp:Code {SAB: "MP"})-[pheno2gene:HAS_PHENOTYPE]-(mouse_genes:Code {SAB:"HGNC HCOP"})
-[homolog:MOUSE_HOMOLOG]-(human_genes:Code {SAB: "HGNC"})
RETURN kf_hpo,hpo2mp,mp, pheno2gene, mouse_genes, homolog,human_genes
_____________________________________________________________________


// Starting with a list of Kids First HPO terms
// All you have to do is remove the CODE: "HP:0001234" in the first kf_hpo node and replace it with SAB: "HPO"
// and then specify that the kf_hpo.CODE value is in your  list of Kids First HPO terms
_____________________________________________________________________
kf_hpo_list = []
MATCH (kf_hpo:Code {SAB: "HPO")-[hpo2mp:pheno_crosswalk]-(mp:Code {SAB: "MP"})-[pheno2gene:HAS_PHENOTYPE]-(mouse_genes:Code {SAB:"HGNC HCOP"})
-[homolog:HOMOLOGOUS]-(human_genes:Code {SAB: "HGNC"})
WHERE kf_hpo.CODE in kf_hpo_list
RETURN kf_hpo,hpo2mp,mp, pheno2gene, mouse_genes, homolog,human_genes

_____________________________________________________________________

// should make all relationships in all capital letters
                                              
                                              
