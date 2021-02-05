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
//MATCH (n:Term) WHERE size((n)--())=0 DELETE (n)

##########################################################################
##### STEP 1: Loading/connecting homologous genes (with hgnc ids) ########  HGNC Code nodes <-[:Homologous]->  Mouse gene Code nodes
##########################################################################  

 We should model mouse genes as Code nodes because human genes are Code nodes (HGNC Code nodes)
Create new Code nodes representing (homologous) mouse genes

# CREATE CONSTRAINT Code_CODE ON (c:Code) ASSERT c.CODE IS UNIQUE // cant do this... MATCH (s:Code) WHERE s.CODE = '0' RETURN s 
### Number of HGNC Code nodes in UMLS before we add our homolog mappings: 41,638 HGNC Nodes
### after we had in the homologue mappings and there are still 41,638 HGNC code Nodes
### Number of relationships between human and mouse gene nodes 66,753
### Number of HGNC HCOP Code nodes: 27390


_________NEW FILES___________

# Create mouse gene Concept nodes
//  Added 22256 labels, created 22256 nodes, set 22256 properties, 
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///CUI_mouse.csv" AS row
MERGE (mg_concepts:Concept {CUI: row.CUI_mouse})

# Create mouse gene Code nodes
// Added 22256 labels, created 22256 nodes, set 66768 properties
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///CODE_mouse.csv" AS row
MERGE (mg_codes:Code {CodeID: row.CodeID_mouse,CODE: row.CODE_mouse, SAB: 'HGNC HCOP'}) // gene_name:row.mouse_symbol,  MGI:row.mgi_id,

# Connect mouse gene Concept node to their Code node 
// Added 22256 labels, created 22256 nodes, set 22256 properties, created 22256 relationships
:auto USING PERIODIC COMMIT 10000 
LOAD CSV WITH HEADERS FROM "file:///CUI-CODE.csv" AS row
MATCH (mg_concepts:Concept {CUI: row.CUI_mouse})
MERGE (mg_concepts)-[:CODE]->(mg_codes:Code {CodeID: row.CODE_mouse}) 

# Connect mouse gene CUI to human gene CUI
// Created 66754 relationships
:auto USING PERIODIC COMMIT 10000 
LOAD CSV WITH HEADERS FROM "file:///CUI-CUI.csv" AS row
MATCH (human_gene:Concept {CUI: row.CUI_human})
MATCH (mouse_gene:Concept {CUI: row.CUI_mouse})
MERGE (human_gene)-[:ortholog]->(mouse_gene) 


__________________________________________
__________________________________________

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
MERGE (mg_concepts)-[:CODE]->(mg_codes:Code {CodeID: row.CodeID}) 

#### Connect HGNC concept notes to mouse gene concept nodes instead of out the code to code level ########

// Connect HGNC Code nodes to its corresponding mouse gene Code node with a :mouse_homolog relationship
// Created 66753 relationships,gene-gene relationships are not always 1-to-1 which is why there are more relationships created than there are mouse gene nodes.
:auto USING PERIODIC COMMIT 10000 
LOAD CSV WITH HEADERS FROM "file:///orthologs.csv" AS row
MATCH (n:Code {SAB:'HGNC', CODE:row.hgnc_id})
MATCH (t:Code {SAB:'HGNC HCOP', CODE:row.mouse_symbol})
CREATE (n)-[:mouse_homolog]->(t)

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


##############################################################
###### STEP 2.0: Load Mammalian Phenotype Ontology ###########
##############################################################
-Must add MP_term  and Parent_terms to the NODES_MP_TERMS.csv file eventually?
-Term/definition nodes to add to the MP Code nodes

# Create MP nodes
// Added 13116 labels, created 13116 nodes, set 39348 properties
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///NODES_mp_ont.csv" AS row
MERGE (mp:Code {CODE: row.MP_terms, CODEID: row.CODEID,SAB: 'MP'})  

// Created 16531 relationships
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///mp_graph.csv" AS row
MATCH  (mp:Code {CODE: row.MP_term})
MATCH  (mp_parents:Code {CODE: row.Parent_terms})
MERGE (mp)-[:SCO]->(mp_parents)


############################################################### 
######## STEP 2.1: Load genotype-phenotype data ###############
############################################################### 
   Are all HPO Code nodes attached to a HPO Concept node, or are just the top level HPO codes attached to Concept nodes?
# match (n:Code {SAB:'HPO'}) return count(n) # 14,586 HPO Code nodes
# match (n:Code {SAB:'HPO'})--(C:Concept) return count(n) # 16,270 

____________ NEW FILES ____________

# Load mouse_gene and mp_term Code nodes
//  Added 27688 labels, created 27688 nodes, set 83064 properties,
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///CODEs_genotype.csv" AS row
CREATE (mp_codes:Code {CodeID: row.CodeID, CODE:row.CODE, SAB: row.SAB}) 

# Load in mouse_gene and mp_term Concept nodes
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///CUIs_genotype.csv.csv" AS row
Create (concepts:Concept {CUI: row.CUI})

# Connect mouse_gene CUI to mp_term CUI
// Created 234042 relationships
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///CUI-CUI_genotype.csv" AS row
MATCH (mouse_gene:Concept {CUI: row.CUI_mouse_gene})
MATCH (mp_term:Concept {CUI:row.CUI_mp_term})
MERGE (mouse_gene)-[:has_phenotype]->(mp_term)

# Connect Concepts to Codes
// Created 27688 relationships, 
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///CUI-CODE_genotype.csv" AS row
MATCH (concept:Concept {CUI: row.CUI})
MATCH (code:Code {CODE: row.CODE})
MERGE (concept)-[:code]->(code)


_____________old import ________________

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
                                                                            
     
     


 #####################################
 ###### STEP 4. Add GTEx data ########
 #####################################
 
 ###### Median Gene (Transcripts Per Million) per Tissue  ######

# First create the GTEx Concept and Code nodes
// Running Concepts alone: Added 1319926 labels, created 1319926 nodes, set 1319926 properties
// Running Codes alone:  Added 1319926 labels, created 1319926 nodes, set 14519186 properties
// Running together in a clean DB: Added 3819852 labels, created 3819852 nodes, set 22919112 properties, completed after 165765 ms.
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///median_gene_TPM_GTEx.csv" AS row
MERGE (gtex_Concept:Concept {CUI: row.CUI})   
MERGE (gtex_Code:Code  {CodeID: row.CodeID, SAB: 'GTEx',transcript_id: row.`Transcript ID`, median_tpm: row.Median_TPM,top_level_tissue: row.SMTS,tissue:row.tissue, 
                                                gene_symbol:row.symbol, gene_name: row.name,locus_group: row.locus_group,locus_type:row.locus_type, location:row.location})   // what should the GTEx Code nodes CODE be?    # CODE: row.CODE                                     


# Connect the concept and code nodes
// Created 1909926 relationships
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///median_gene_TPM_GTEx.csv" AS row
MATCH (gtex_Concept:Concept {CUI: row.CUI})
MATCH (gtex_Code:Code  {CodeID: row.CodeID, SAB: 'GTEx'})   
MERGE (gtex_Concept)-[:CODE]-(gtex_Code)

# Connect GTEx Code nodes to HGNC and UBERON Code nodes
// Created 1202546 relationships,
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///median_gene_TPM_GTEx.csv" AS row
MATCH (gtex:Code {CodeID: row.CodeID})
MATCH (uberon:Code {CODE: row.SMUBRID, SAB: 'UBERON'} )
MATCH (hgnc:Code {CODE: row.hgnc_id, SAB: 'HGNC'} )    
MERGE (uberon)-[:HAS_EXPRESSION]-(gtex)
MERGE (hgnc)-[:EXPRESSED]-(gtex)
#####################################

########## eQTLs, eqtl_all_GTEx.csv #######


// Added 2415932 labels, created 2415932 nodes, set 16911524 properties
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///eqtl_all_GTEx.csv" AS row
MERGE (eqtl_Concept:Concept {CUI:row.CUI}) 
MERGE (eqtl:Code {CodeID:row.CodeID, gene_symbol:row.symbol, top_level_tissue:row.SMTS,tissue:row.tissue,
        gene_id:row.gene_id,chromosome:row.gene_chr, chromosome: row.gene_chr, 
        gene_start: row.gene_start,gene_end: row.gene_end ,pval:row.pval_true_df,variant_id:row.variant_id,
        rs_id: row.rs_id_dbSNP151_GRCh38p7, maf: row.maf, SAB: 'GTEx' }) // gene_name: row.gene_name,

 # Connect the eQTL Code and Concept nodes
 // Created 1207966 relationships,
 :auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///eqtl_all_GTEx.csv" AS row
MATCH (gtex_Concept:Concept {CUI: row.CUI})
MATCH (gtex_Code:Code  {CodeID: row.CodeID, SAB: 'GTEx'})   
MERGE (gtex_Concept)-[:CODE]-(gtex_Code)


CREATE INDEX FOR (n:Code) ON (n.rs_id);


 # Connect  eQTL Code nodes to UBERON nodes
 :auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///eqtl_all_GTEx.csv" AS row
MATCH (uberon: Code {CODE: row.SMUBRID, SAB: 'UBERON'})
MATCH (eqtl:Code {rs_id: row.rs_id_dbSNP151_GRCh38p7, SAB: 'GTEx'})
MERGE (uberon)-[:HAS_eQTL]->(eqtl)


 # Connect  eQTL Code nodes to HGNC nodes
 // Created 1002641 nodes, created 1002641 relationships  how many unique values are there?
 :auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM "file:///eqtl_all_GTEx.csv" AS row
WITH row WHERE NOT row.hgnc_id IS null
MATCH (hgnc: Code {CODE: row.hgnc_id,SAB: 'HGNC'})
MATCH (eqtl:Code {rs_id: row.rs_id_dbSNP151_GRCh38p7, SAB: 'GTEx'})
MERGE (HGNC)-[:eQTL]->(eqtl)


 
 
 
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
                                              
