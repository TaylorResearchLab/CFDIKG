Optimize the ASD queries


---------------
ASD_genes.csv | :   originally took 19.11 minutes (1147118  ms) --> 363 ms
---------------

All genes associated with ASD (MP_00110403) and its child phenotypes.

New Cypher Query:

WITH 'MP:0010403' AS parent    
MATCH (P_code:Code {CODE:parent,SAB:'MP'})<-[:CODE]-(P_concept:Concept)<-[:SCO *1.. {SAB:'MP'}]-(C_concept:Concept)
WITH  collect(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms WITH collect(DISTINCT uterms) AS phenos
MATCH (mp_concept:Concept)-[:phenotype_has_associated_gene {SAB:'IMPC'}]->(hcop_concept:Concept)-[:has_human_ortholog {SAB:'HGNC__HGNC_HCOP'}]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB: 'HGNC'})
WHERE mp_concept.CUI IN phenos WITH hgnc_concept,human_gene
MATCH (hgnc_concept)-[:CODE]->(gl_code:Code {SAB:'GENE_LOCATION'})
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
WITH DISTINCT human_gene,gl_code,gene_symbol
MATCH (gl_code)-[:gene_start_position]->(gstart:Term)
MATCH (gl_code)-[:gene_end_position]->(gend:Term)
MATCH (gl_code)-[:on_chromosome]->(gchrom:Term)
MATCH (gl_code)-[:strand]->(strand:Term)
RETURN DISTINCT split(gene_symbol.name,' gene')[0] AS symbol,gstart.name AS start_pos,gend.name as end_pos,gchrom.name AS chrom,strand.name as strand,human_gene.CODE AS hgnc_id 




---------------
ASD_eQTLs.csv | :  originally --> 4179 ms
---------------

All of the eQTLs from ASD (MP_00110403) and its child phenotypes that are expressed in the heart and have a p-value upperbound less than .05 


Cypher Query:

WITH 'MP:0010403' AS parent
MATCH (P_code:Code {CODE:parent,SAB:'MP'})<-[:CODE]-(P_concept:Concept)<-[:SCO *1..{SAB:'MP'}]-(C_concept:Concept)
WITH  collect(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms WITH collect(distinct uterms) AS phenos
MATCH (mp_concept)-[:phenotype_has_associated_gene {SAB:'IMPC'}]->(hcop_concept:Concept)-[:has_human_ortholog {SAB:'HGNC__HGNC_HCOP'}]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB: 'HGNC'})
WHERE mp_concept.CUI IN phenos WITH hgnc_concept,human_gene
MATCH (hgnc_concept)-[:CODE]->(gl_code:Code {SAB:'GENE_LOCATION'})
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
with distinct human_gene,gl_code, gene_symbol
MATCH (gl_code)-[:gene_start_position]->(gstart:Term)
MATCH (gl_code)-[:gene_end_position]->(gend:Term)
MATCH (gl_code)-[:on_chromosome]->(gchrom:Term) WITH *
MATCH (human_gene)-[:CODE]-(hgnc_concept)-[:gene_has_eqtl]->(gtex_concept:Concept)-[:eqtl_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code {SAB:'UBERON'})
WHERE uberon_code.CODE IN ['0006566','0006631'] WITH *
MATCH (gtex_concept)-[:CODE]->(gtex_code:Code {SAB:'GTEX_EQTL'})-[:p_value]->(gtex_term:Term)
WHERE gtex_term.upperbound < .05
MATCH (eqtl_loc_term:Term)<-[:eqtl_location]-(gtex_code)-[:rs_id_dbSNP151_GRCh38p7]->(rs_id_term:Term) WITH * 
RETURN DISTINCT SPLIT(gene_symbol.name,' gene')[0] AS symbol,rs_id_term.name AS rsid, eqtl_loc_term.name AS eqtl_location, gstart.name AS start,gend.name AS end,gchrom.name AS chrom,human_gene.CODE AS hgnc_id,gtex_term.upperbound AS pval_upperbound, gtex_term.lowerbound AS pval_lowerbound








-------------
ASD_TPM.csv | :
-------------

All of the genes from ASD (MP_00110403) and its child phenotypes that are expressed in the heart at 10 TPM or higher.


Cypher Query: --> 892 ms.

WITH 'MP:0010403' AS parent   
MATCH (P_code:Code {CODE:parent,SAB:'MP'})<-[:CODE]-(P_concept:Concept)<-[:SCO *1..{SAB:'MP'}]-(C_concept:Concept)
WITH COLLECT(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms WITH COLLECT(DISTINCT uterms) AS phenos
MATCH (mp_concept)-[:phenotype_has_associated_gene {SAB:'IMPC'}]-(hcop_concept:Concept)-[:has_human_ortholog {SAB:'HGNC__HGNC_HCOP'}]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB: 'HGNC'})
WHERE mp_concept.CUI IN phenos WITH *
MATCH (hgnc_concept)-[:CODE]->(gl_code:Code {SAB:'GENE_LOCATION'})
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term) WITH distinct human_gene,gl_code, gene_symbol
MATCH (gl_code)-[:gene_start_position]->(gstart:Term)
MATCH (gl_code)-[:gene_end_position]->(gend:Term)
MATCH (gl_code)-[:on_chromosome]->(gchrom:Term) WITH *
MATCH (human_gene)-[:CODE]-(hgnc_concept)-[:gene_has_median_expression]->(gtex_concept:Concept)-[:median_expression_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code {SAB:'UBERON'})
WHERE uberon_code.CODE IN ['0006566','0006631'] WITH *
MATCH (gtex_concept)-[:CODE]->(gtex_code:Code {SAB:'GTEX_EXP'})-[:TPM]-(gtex_term:Term)
WHERE gtex_term.lowerbound > 10
RETURN DISTINCT SPLIT(gene_symbol.name,' gene')[0] AS symbol, gstart.name AS start,gend.name AS end,gchrom.name AS chrom,human_gene.CODE AS hgnc_id








--------------------
ASD_cell_types.csv | :
--------------------

Cardiac celltype (Asp) and gene log2fc levels associated with ASD and its child phenotypes that are expressed in the heart at 10 TPM or greater.

Cypher Query: --> 3552 ms.

WITH 'MP:0010403' AS parent   
MATCH (P_code:Code {CODE:parent,SAB:'MP'})<-[:CODE]-(P_concept:Concept)<-[:SCO *1.. {SAB:'MP'}]-(C_concept:Concept)
WITH  COLLECT(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms WITH COLLECT(DISTINCT uterms) AS phenos
MATCH (mp_concept)-[:phenotype_has_associated_gene {SAB:'IMPC'}]-(hcop_concept:Concept)-[:has_human_ortholog {SAB:'HGNC__HGNC_HCOP'}]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB:'HGNC'}) 
WHERE mp_concept.CUI IN phenos WITH *
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
WITH hgnc_concept,human_gene, gene_symbol
MATCH (human_gene)<-[:CODE]-(hgnc_concept)-[:gene_has_median_expression]->(gtex_concept:Concept)-[:median_expression_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code)
WHERE uberon_code.SAB = 'UBERON' AND uberon_code.CODE IN ['0006566','0006631'] WITH *
MATCH (gtex_concept)-[:CODE]->(gtex_code:Code {SAB:'GTEX_EXP'})-[:TPM]->(gtex_term:Term)
WHERE gtex_term.lowerbound > 10
MATCH (human_gene:Code {SAB:'HGNC'})<-[:CODE]-(b:Concept)-[:has_single_cell_expression]->(c:Concept)-[:CODE]->(sc_code:Code {SAB:'scHeart PMID: 31835037'})-[:log2fc]->(sc_term:Term) 
MATCH (sc_code)-[:p_value]->(pval_term:Term) WITH *, collect(human_gene.CODE) AS gene_list
WHERE human_gene.CODE IN gene_list
RETURN SPLIT(gene_symbol.name,' gene')[0] AS symbol, sc_code.CODE AS celltype_gene,sc_term.name AS log2fc, pval_term.lowerbound AS pval_lowerbound, pval_term.upperbound AS pval_upperbound 









