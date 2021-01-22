##############################################################
###### STEP 2: Load Mammalian Phenotype Ontology ###########
##############################################################


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
MATCH  (mp_Code:Code {CodeID: row.CodeID, SAB: 'MP'})
MATCH  (mp_Concept:Concept {CUI: row.CUI})
MERGE (mp_Concept)-[:CODE]->(mp_Code)

#### Load MP heirachy   
// Created 16531 relationships,
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

# Connect preferred_label Term nodes to MP Concept with a :PREF_TERM relationship
// Created 14241 relationships
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///CUI_2_PrefTerms_mp_ont.csv" AS row
MATCH (c:Concept {CUI: row.CUI})
MATCH (term:Term {SUI: row.SUI})
MERGE (c)-[:PREF_TERM]->(term)

# Connnect MP Code nodes to their Term nodes with a :TERM relationship
// Created 39721 relationships,
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///TERMS_mp_ont.csv" AS row
MATCH (mp:Code {CODE: row.MP_term})
MATCH (term:Term {SUI: row.SUI})
MERGE (mp)-[:TERM]->(term)

---check that some codes have multiple terms.


##############################################################
############ STEP 2.0.2 Load definitions #####################  
##############################################################  

# Create all definition nodes
// MERGE: Added 3349 labels, created 3349 nodes, set 3349 properties
// CREATE: Added 13393 labels, created 13393 nodes, set 40179 properties,
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///DEFs_mp_ont.csv" AS row
MERGE (d:Definitions {DEF: row.Definitions, ATUI: row.ATUI, SAB: 'MP' })

ATUI:AT254763528


# Connect Definition nodes to Concept nodes 
// 
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///DEFs_mp_ont.csv" AS row
MATCH (c:Concept {CUI: row.CUI})
MATCH (d:Definition {DEF: row.Definition})
MERGE (c)-[:DEF]->(d)




##############################################################
######### STEP 2.0.3 Load and Connect Cross Reference ######## 
############################################################## 

# Load XREF nodes, as Code
// Added 521 labels, created 521 nodes, set 1563 properties, c
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///XREF_mp_ont.csv" AS row
MERGE (xref:Code {CODE: row.CODE, CodeID: row.CodeID, SAB: row.SAB })

# Connect them to Code/Concept nodes
// Created 686 relationships, 
:auto USING PERIODIC COMMIT 10000 LOAD CSV WITH HEADERS FROM "file:///XREF_mp_ont.csv" AS row
MATCH (xref:Code {CODE: row.CODE, CodeID: row.CodeID, SAB: row.SAB })
MATCH (c:Code {CODE: row.MP_term})
MERGE (xref)-[:CROSS_REF]->(c)




#######################################
########## Explore MP Graph ###########
#######################################
How many MP Code Nodes?
match (n:Code {SAB:'MP'}) return count(n)  # 14,241 

How many MP Concept nodes?
match (n:Concept) where n.CUI starts with 'K'  return count(n)   # 14,241

