##############################################################
###### STEP 2.0: Load Mammalian Phenotype Ontology ###########
##############################################################

##############################################################
############## STEP 2.0.0 Load MP terms and their ############
######## heirarchy as Code nodes with 'SCO' relationships ####
##############################################################

-Must add MP_term  and Parent_terms to the NODES_MP_TERMS.csv file eventually?
-Term/definition nodes to add to the MP Code nodes

#### Create MP Concept and Code nodes 
//  Added 28482 labels, created 28482 nodes, set 56964 properties 
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///NODES_mp_ont.csv" AS row
MERGE (mp_Code:Code {CODE: row.MP_term, CodeID: row.CodeID,SAB: 'MP'})  
MERGE (mp_Concept:Concept {CUI: row.CUI})

#### Connect MP Concept and Code nodes 
// Created 14241 relationships
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///NODES_mp_ont.csv" AS row
MATCH  (mp_Code:Code {CodeID: row.CodeID})
MATCH  (mp_Concept:Concept {CUI: row.CUI})
MERGE (mp_Concept)-[:CODE]->(mp_Code)


#### Load MP heirachy 
// Added 33064 labels, created 33064 nodes, set 33064 properties, created 16532 relationships, c
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///child2parent_mp_ont.csv" AS row
MATCH  (mp:Code {CODE: row.MP_term})
MATCH  (mp_parents:Code {CODE: row.Parent_terms})
MERGE (mp)-[:SCO]->(mp_parents)

##############################################################
############ STEP 2.0.1 Load names/labels and synonyms #######
################# of MP Terms as Term nodes  #################
##############################################################

----Add the master list of terms with corresponding MP_terms and SUIs

# is there a unique constraint on SUI?

# Create Term nodes
//  Added 39582 labels, created 39582 nodes, set 79164 properties, 
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///TERMS_mp_ont.csv" AS row
MERGE (t:Term {Name: row.Term, SUI: row.SUI })  

# Connnect MP Code nodes to their Term nodes      should be 39721 rels
// Created 99011 relationships
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///TERMS_mp_ont.csv" AS row
MATCH (mp:Code {CODE: row.MP_term})
MATCH (term:Term {SUI: row.SUI})
MERGE (mp)-[:TERM]->(term)

------Connect preferred_label Term nodes to MP Concept


##############################################################
############ STEP 2.0.2 Load definitions #####################  
##############################################################   ATUI

# Create all definition nodes
// Added 14241 labels, created 14241 nodes,
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///DEFs_mp_onto.csv" AS row
CREATE (c:Definitions {DEF: row.Definition })

ATUI:AT254763528
DEF:Shlukování suspendovaného materiálu (buněk, bakterií), které je výsledkem působení aglutininů.
SAB:MSHCZE


# Connect Definition nodes to Concept nodes 
//
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///TERMS_mp_ont.csv" AS row
MATCH (c:Concept {CUI: row.CUI})
MATCH (d:Definition {DEF: row.Definition})
MERGE (c)-[:DEF]->(d)


------Connect MP Concept or Code nodes??? to Def nodes
