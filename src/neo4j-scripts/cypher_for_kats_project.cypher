==============================
*  Queries for Kats project  *
==============================



1) Return edge list for all genes that  are 'coexpressed_with' eachother

LOAD CSV WITH HEADERS FROM 'file:///Group1_hgnc.csv' AS file
WITH  file WHERE file.hgnc_id IS NOT NULL
WITH file.hgnc_id AS GENE_LIST
MATCH (gene_code_1:Code)-[:CODE]-(gene_concept_1:Concept)-[r:coexpressed_with]-
(gene_concept_2:Concept)-[:CODE]-(gene_code_2:Code)
WHERE gene_code_1.SAB =  'HGNC' AND gene_code_2.SAB = 'HGNC' AND gene_code_1.CODE  IN GENE_LIST AND gene_code_2.CODE  IN GENE_LIST
RETURN DISTINCT gene_code_1.CODE AS source, type(r) AS edge, gene_code_2.CODE AS target

No resuts for any of the 5 gene groups



2)  Return edge list of all genes that share a mammalian phenotype

WITH  file WHERE file.hgnc_id IS NOT NULL
WITH file.hgnc_id AS GENE_LIST
MATCH (hcop_concept_1:Concept)-[:CODE]-(hcop_code:Code {SAB:'HGNC_HCOP'})
MATCH (hcop_concept_2:Concept)-[:CODE]-(hcop_code:Code {SAB:'HGNC_HCOP'})
MATCH (mp_code_1 {SAB:'MP'})-[:CODE]-(mp_concept_1:Concept)-[a:gene_associated_with_phenotype]-(hcop_concept_1)-[b:has_mouse_ortholog]-(gene_concept_1:Concept)-[:CODE]-(gene_code_1:Code {SAB:'HGNC'})
MATCH (mp_code_2 {SAB:'MP'})-[:CODE]-(mp_concept_2:Concept)-[c:gene_associated_with_phenotype]-(hcop_concept_2)-[d:has_mouse_ortholog]-(gene_concept_2:Concept)-[:CODE]-(gene_code_2:Code {SAB:'HGNC'})
WHERE  gene_code_1.CODE  IN GENE_LIST AND gene_code_2.CODE  IN GENE_LIST AND mp_code_1 = mp_code_2 AND gene_code_1.CODE  <> gene_code_2.CODE
RETURN DISTINCT gene_code_1.CODE AS gene_1, mp_code_1.CODE AS edge,mp_code_2.CODE AS edge2, gene_code_2.CODE AS gene_2

No results for any of the 5 gene groups



3) Return edge list of all genes that share a human phenotype

LOAD CSV WITH HEADERS FROM 'file:///Group1_hgnc.csv' AS file
WITH  file WHERE file.hgnc_id IS NOT NULL
WITH file.hgnc_id AS GENE_LIST
MATCH (hp_code_1:Code {SAB:'HPO'})-[:CODE]-(hp_concept_1:Concept)-[a:gene_associated_with_phenotype]-(gene_concept_1:Concept)-[:CODE]-(gene_code_1:Code {SAB:'HGNC'})
MATCH (hp_code_2:Code {SAB:'HPO'})-[:CODE]-(mp_concept_2:Concept)-[c:gene_associated_with_phenotype]-(gene_concept_2:Concept)-[:CODE]-(gene_code_2:Code {SAB:'HGNC'})
WHERE  gene_code_1.CODE  IN GENE_LIST AND gene_code_2.CODE  IN GENE_LIST AND hp_code_1 = hp_code_2 AND gene_code_1.CODE  <> gene_code_2.CODE
RETURN DISTINCT gene_code_1.CODE AS gene_1, hp_code_1.CODE AS edge, gene_code_2.CODE AS gene_2

No results for any of the 5 gene groups


4) Return edge list for all genes that have a chemical that up/down regulates them both


LOAD CSV WITH HEADERS FROM 'file:///Group2_hgnc.csv' AS file
WITH  file WHERE file.hgnc_id IS NOT NULL
WITH file.hgnc_id AS GENE_LIST
MATCH (ChEBI_concept_1:Concept)-[:CODE]-(ChEBI_code_1:Code {SAB:'CHEBI'})-[r:PT]-(chEBI_term:Term)
MATCH (gene_code_1:Code {SAB:'HGNC'})-[:CODE]-(gene_concept_1:Concept)-[a {SAB:'LINCS L1000'}]-(ChEBI_concept_1:Concept)-[b {SAB:'LINCS L1000'}]-(gene_concept_2:Concept)-[:CODE]-(gene_code_2:Code {SAB:'HGNC'})
WHERE gene_code_1.CODE  IN GENE_LIST AND gene_code_2.CODE  IN GENE_LIST AND  gene_code_1.CODE  <> gene_code_2.CODE 
RETURN DISTINCT gene_code_1.CODE AS gene_1, chEBI_term.name AS edge, gene_code_2.CODE AS gene_2 



5) Return edge list of genes that share a pathway

LOAD CSV WITH HEADERS FROM 'file:///Group5_hgnc.csv' AS file
WITH  file WHERE file.hgnc_id IS NOT NULL
WITH file.hgnc_id AS GENE_LIST
MATCH (msigdb_concept_1:Concept)-[:CODE]-(msigdb_code_1:Code {SAB:'MSigDB_Systematic_Name'})-[r:PT]-(msigdb_term:Term)
MATCH (gene_code_1:Code {SAB:'HGNC'})-[:CODE]-(gene_concept_1:Concept)-[a:has_signature_gene]-(msigdb_concept_1)-[b:has_signature_gene]-(gene_concept_2:Concept)-[:CODE]-(gene_code_2:Code {SAB:'HGNC'})
WHERE gene_code_1.CODE  IN GENE_LIST AND gene_code_2.CODE  IN GENE_LIST AND  gene_code_1.CODE  <> gene_code_2.CODE
RETURN DISTINCT gene_code_1.CODE AS gene_1, msigdb_term.name AS edge, gene_code_2.CODE AS gene_2 

No results for any of the 5 gene groups












