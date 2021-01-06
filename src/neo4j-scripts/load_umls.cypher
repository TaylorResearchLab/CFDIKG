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



####### Create index and unique constraints
// After UMLS import script is run, run these...
CREATE CONSTRAINT ON (n:Semantic) ASSERT n.TUI IS UNIQUE;
CREATE CONSTRAINT ON (n:Semantic) ASSERT n.STN IS UNIQUE;
CREATE CONSTRAINT ON (n:Semantic) ASSERT n.DEF IS UNIQUE;
CREATE CONSTRAINT ON (n:Semantic) ASSERT n.name IS UNIQUE;
CREATE CONSTRAINT ON (n:Concept) ASSERT n.CUI IS UNIQUE;
CREATE CONSTRAINT ON (n:Code) ASSERT n.CodeID IS UNIQUE;
CREATE INDEX FOR (n:Code) ON (n.SAB);
CREATE INDEX FOR (n:Code) ON (n.CODE);
CREATE CONSTRAINT ON (n:Term) ASSERT n.SUI IS UNIQUE;
CREATE INDEX FOR (n:Term) ON (n.name);
CREATE CONSTRAINT ON (n:Definition) ASSERT n.ATUI IS UNIQUE;
CREATE INDEX FOR (n:Definition) ON (n.SAB);
CREATE INDEX FOR (n:Definition) ON (n.DEF);
CREATE CONSTRAINT ON (n:NDC) ASSERT n.ATUI IS UNIQUE;
CREATE CONSTRAINT ON (n:NDC) ASSERT n.NDC IS UNIQUE;
CALL db.index.fulltext.createNodeIndex("Term_name",["Term"],["name"]);

##########################################################################
##### STEP 1: Loading/connecting homologous genes (with hgnc ids) ########  HGNC Code nodes <-[:Homologous]->  Mouse gene Code nodes
##########################################################################  

 We should model mouse genes as Code nodes because human genes are Code nodes (HGNC Code nodes)
Create new Code nodes representing (homologous) mouse genes

// Create Index on the node types we want to connect with a :MOUSE_HOMOLOG relationship
__________________________________________
# CREATE INDEX FOR (c:Code) ON (c.CODE); // already handled by chucks indexing
# CREATE CONSTRAINT Code_CODE ON (c:Code) ASSERT c.CODE IS UNIQUE // cant do this... MATCH (s:Code) WHERE s.CODE = '0' RETURN s 

//  First load in the NODES_GENES.csv and create all mouse gene Concept nodes and all mouse gene Code nodes
// Added 54780 labels, created 54780 nodes, set 109560 properties, completed after 7277 ms  # ~27k concept and ~27k code nodes
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///NODES_GENES.csv" AS row
CREATE (mg_concepts:Concept {CUI: row.`Concept ID`})
CREATE (mg_codes:Code {CODEID: row.CODEID, CODE:row.Gene, SAB: 'HGNC HCOP'}) // gene_name:row.mouse_symbol,  MGI:row.mgi_id,

// Connect mouse gene Concepts to Codes
// Added 27390 labels, created 27390 nodes, set 27390 properties, created 27390 relationships,
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///NODES_GENES.csv" AS row
MATCH (mg_concepts:Concept {CUI: row.`Concept ID`})
MERGE (mg_concepts)-[:CODE]->(mg_codes:Code {CODEID: row.CODEID}) 

// Connect HGNC Code nodes to its corresponding mouse gene Code node with a :MOUSE_HOMOLOG relationship
// Created 66753 relationships,gene-gene relationships are not always 1-to-1 which is why there are more relationships created than there are mouse gene nodes.
:auto USING PERIODIC COMMIT 10000 
LOAD CSV WITH HEADERS FROM "file:///hgnc_2_mouse_homologs.csv" AS row
MATCH (n:Code {SAB:'HGNC', CODE:row.hgnc_id})
MATCH (t:Code {SAB:'HGNC HCOP', CODE:row.mouse_symbol})
CREATE (n)-[:MOUSE_HOMOLOG]->(t)
_________________________________________
# make sure each query is adding the right number of new nodes
# make sure attribute signatures match for nodes of the same type 
# see how many HGNC and HGNC HCOP nodes there are before and after query
#  check things look good: MATCH (n:Code {SAB:'HGNC'})-[m:MOUSE_HOMOLOG]->(t:Code) RETURN n,m,t limit 5

# RECHECK THESE QUERIES

LOAD CSV WITH HEADERS FROM "file:///hgnc_2_mouse_homologs.csv" AS row
MATCH (n:Code {SAB:'HGNC', CODE:row.hgnc_id})
RETURN count(n)
# 66,754 HGNC nodes

MATCH (n:Code {SAB:'HGNC'}) RETURN count(n)
# 41,638 HNGC nodes

LOAD CSV WITH HEADERS FROM "file:///hgnc_2_mouse_homologs.csv" AS row
MATCH (n:Code {SAB:'HGNC HCOP', CODE:row.mouse_symbol})
RETURN count(n)
# 66,848 mouse_gene nodes

MATCH (n:Code {SAB:'HGNC HCOP'})
RETURN count(n)
# 22,295 mouse_gene nodes


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

____________________________________
// Cant use the MERGE statement below unless we set a uniqueness constraint, cant put uniqueness constraint
// on Code.CODE because there are multiple UMLS Code nodes that have a CODE attribute value of '0', so make      # Make CODEID attribute !!!!!
an identical attribute mp_term_name and set constraint on that.
# CREATE CONSTRAINT Code_mp_term ON (c:Code) ASSERT c.mp_term_name IS UNIQUE

// Load in the NODES_MP_TERMS.csv and create all mouse gene Concept nodes and all mouse gene Code nodes
// Added 20660 labels, created 20660 nodes, set 41320 properties,
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///NODES_MP_TERMS.csv" AS row
CREATE (mp_concepts:Concept {CUI: row.`Concept ID`})
CREATE (mp_codes:Code {CODEID: row.CODEID, CODE:row.MP_term, SAB: 'MP'}) 

// Create connections between mouse phenotype concept and code nodes
// Added 10330 labels, created 10330 nodes, set 10330 properties, created 10330 relationships     # why is this creating 10k nodes?
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///NODES_MP_TERMS.csv" AS row
MATCH (mp_concepts:Concept {CUI: row.`Concept ID`})
MERGE (mp_concepts)-[:CODE]->(mp_codes:Code {CODEID: row.CODEID}) 


// Connect MP nodes to mouse gene Code nodes
// This query does: Created 30753 relationships
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///geno2pheno_mapping.csv" AS row
MATCH (mouse_pheno:Code {CODE: row.mp_term_id, SAB:'MP'})
MATCH (mouse_gene:Code {CODE:row.marker_symbol, SAB:'HGNC HCOP'})
MERGE (mouse_gene)-[:HAS_PHENOTYPE]->(mouse_pheno)
______________________________________                                                                             




###########################################################
############# STEP 2.5: Add Allele data (allele terms, ####
############### allele MGI accession numbers, etc.) #######
......
             
             
##########################################################
###### STEP 3: Connect HPO and MP Concept nodes ##########  HPO Concept nodes <-[pheno_crosswalk]-> MP Concept nodes 
############## with Tiffanys mappings ####################                              
##########################################################      ### Include confidence score and match type from tiffanys mappings data!!

# There are multiple HPO nodes with the same name, each connected to a different MP term. None of the HPO term nodes  are the actual HGNC nodes

// Connect HPO Concept nodes to MP Concept nodes  
// This query does: Created 1219 relationships
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///tiffs_mappings_ravel.csv" AS row  
MATCH (hpo:Code {CODE: row.HP_ID})
MATCH (mp:Code {CODE: row.MPO_URI})
MERGE (hpo)-[r:PHENO_CROSSWALK]->(mp)                            

                                                                                                  
// check if every HP term we're importing is already in UMLS. --They are bc MERGE (hpo:Code {SAB:'HPO',CODE:row.HP_ID})  # adds nothing
// ^^^This may change as we add additional HP terms  (outside of  KF)                                 
                                                                            
     
     
     
     
     
 Do we need/have human genotype to phenotype (HPO terms to human gene/genotype connections)?  
 --This is the point of building the graph because comprehensive data of this type does not exist  
   at least for congenital heart disease, structural birth defects, etc.
 
 
 Have Tiffany map all hp - mp terms for the time being until Nico et al are done?
 Import MP.owl? 
 Need Concept nodes?
 Bgee RDF data? GTEx in RDF graph form
 
 
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



// Query using a single HPO term, ie. HP:0000252
_____________________________________________________________________
MATCH (kf_hpo:Code {CODE: "HP:0000252"})-[hpo2mp:PHENO_CROSSWALK]-(mp:Code {SAB: "MP"})-[pheno2gene:HAS_PHENOTYPE]-(mouse_genes:Code {SAB:"HGNC HCOP"})
-[homolog:MOUSE_HOMOLOG]-(human_genes:Code {SAB: "HGNC"})
RETURN kf_hpo,hpo2mp,mp, pheno2gene, mouse_genes, homolog,human_genes
_____________________________________________________________________


// Starting with a list of Kids First HPO terms
// All you have to do is remove the {CODE: "HP:0000252"} in the first kf_hpo node and replace it with {SAB: "HPO"}
// and then specify that the kf_hpo.CODE value is in your  list of Kids First HPO terms
_____________________________________________________________________
kf_hpo_list = ["HP:0000252","HP:0000049","HP:0000011"]
MATCH (kf_hpo:Code {SAB: "HPO")-[hpo2mp:PHENO_CROSSWALK]-(mp:Code {SAB: "MP"})-[pheno2gene:HAS_PHENOTYPE]-(mouse_genes:Code {SAB:"HGNC HCOP"})
-[homolog:HOMOLOGOUS]-(human_genes:Code {SAB: "HGNC"})
WHERE kf_hpo.CODE in kf_hpo_list
RETURN kf_hpo,hpo2mp,mp, pheno2gene, mouse_genes, homolog,human_genes

_____________________________________________________________________



# Give each of our code nodes a 'parent'  concept node
# How to tie in allele data
# How to model GTEx data?
                                              
