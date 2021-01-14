##############################################################
###### STEP 2.0: Load Mammalian Phenotype Ontology ###########
##############################################################

##############################################################
############## STEP 2.0.0 Load MP terms and their ############
######## heirarchy as Code nodes with 'SCO' relationships ####
##############################################################

-Must add MP_term  and Parent_terms to the NODES_MP_TERMS.csv file eventually?
-Term/definition nodes to add to the MP Code nodes

// Added 13116 labels, created 13116 nodes, set 39348 properties
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///NODES_mp_ont.csv" AS row
MERGE (mp_Code:Code {CODE: row.MP_terms, CODEID: row.CODEID,SAB: 'MP'})  
MERGE (mp_Concept:Concept {CUI: row.CUI})


// Created 16531 relationships
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///mp_graph.csv" AS row
MATCH  (mp:Code {CODE: row.MP_term})
MATCH  (mp_parents:Code {CODE: row.Parent_terms})
MERGE (mp)-[:SCO]->(mp_parents)

##############################################################
############ STEP 2.0.1 Load names/labels and synonyms #######
################# of MP Terms as Term nodes  #################
##############################################################

----Add the master list of terms with corresponding MP_terms and SUIs

# is there a unique constraint on SUI?

//  Added 39582 labels, created 39582 nodes, set 79164 properties, 
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///TERMS_mp_ont.csv" AS row
MERGE (t:Term {Name: row.Term, SUI: row.SUI })  

---Connnect MP Code nodes to their Term nodes

// Created 31058 relationships
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///TERMS_mp_ont.csv" AS row
MATCH (mp:Code {CODE: row.MP_term})
MATCH (term:Term {SUI: row.SUI})
MERGE (mp)-[:TERM]->(term)

------Connect preferred_label Term nodes to MP Concept


##############################################################
############ STEP 2.0.2 Load definitions #####################  
##############################################################

------Create all definition nodes



------Connect MP Concept or Code nodes??? to Def nodes
