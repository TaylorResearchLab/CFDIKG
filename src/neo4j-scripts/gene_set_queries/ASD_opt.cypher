Optimize the ASD queries


---------------
ASD_genes.csv | :   originally took 19.11 minutes (1147118  ms) --> 363 ms
---------------

All genes associated with ASD (MP_00110403) and its child phenotypes.

New Cypher Query:

WITH 'MP:0010403' AS parent    
MATCH (P_code:Code {CODE:parent,SAB:'MP'})<-[:CODE]-(P_concept:Concept)<-[:SCO *1.. {SAB:'MP'}]-(C_concept:Concept)
WITH  collect(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms
WITH collect(DISTINCT uterms) AS phenos
MATCH (mp_concept:Concept)-[:phenotype_has_associated_gene {SAB:'IMPC'}]->(hcop_concept:Concept)-[:has_human_ortholog {SAB:'HGNC__HGNC_HCOP'}]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB: 'HGNC'})
WHERE mp_concept.CUI IN phenos
WITH hgnc_concept,human_gene
MATCH (hgnc_concept)-[:CODE]->(gl_code:Code {SAB:'GENE_LOCATION'})
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
WITH DISTINCT human_gene,gl_code,gene_symbol
MATCH (gl_code)-[:gene_start_position]->(gstart:Term)
MATCH (gl_code)-[:gene_end_position]->(gend:Term)
MATCH (gl_code)-[:on_chromosome]->(gchrom:Term)
RETURN DISTINCT split(gene_symbol.name,' gene')[0] AS symbol,gstart.name AS start_pos,gend.name as end_pos,gchrom.name AS chrom,human_gene.CODE AS hgnc_id 





---------------
ASD_eQTLs.csv | :  originally --> 4179 ms
---------------

All of the eQTLs from ASD (MP_00110403) and its child phenotypes that are expressed in the heart and have a p-value upperbound less than .05 


Cypher Query:

WITH 'MP:0010403' AS parent
MATCH (P_code:Code {CODE:parent,SAB:'MP'})<-[:CODE]-(P_concept:Concept)<-[:SCO *1..{SAB:'MP'}]-(C_concept:Concept)
WITH  collect(C_concept.CUI) + P_concept.CUI AS terms unwind terms AS uterms
WITH collect(distinct uterms) AS phenos
MATCH (mp_concept)-[:phenotype_has_associated_gene {SAB:'IMPC'}]->(hcop_concept:Concept)-[:has_human_ortholog {SAB:'HGNC__HGNC_HCOP'}]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB: 'HGNC'})
WHERE mp_concept.CUI IN phenos
WITH hgnc_concept,human_gene
MATCH (hgnc_concept)-[:CODE]->(gl_code:Code {SAB:'GENE_LOCATION'})
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
with distinct human_gene,gl_code, gene_symbol
MATCH (gl_code)-[:gene_start_position]->(gstart:Term)
MATCH (gl_code)-[:gene_end_position]->(gend:Term)
MATCH (gl_code)-[:on_chromosome]->(gchrom:Term)
WITH *
MATCH (human_gene)-[:CODE]-(hgnc_concept)-[:gene_has_eqtl]->(gtex_concept:Concept)-[:eqtl_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code {SAB:'UBERON'})
WHERE uberon_code.CODE IN ['0006566','0006631']
WITH *
MATCH (gtex_concept)-[:CODE]->(gtex_code:Code {SAB:'GTEX_EQTL'})-[:p_value]->(gtex_term:Term)
WHERE gtex_term.upperbound < .05
MATCH (eqtl_loc_term:Term)<-[:eqtl_location]-(gtex_code)-[:rs_id_dbSNP151_GRCh38p7]->(rs_id_term:Term)
WITH * 
RETURN DISTINCT SPLIT(gene_symbol.name,' gene')[0] AS symbol,rs_id_term.name AS rsid, eqtl_loc_term.name AS eqtl_location, gstart.name AS start,gend.name AS end,gchrom.name AS chrom,human_gene.CODE AS hgnc_id,gtex_term.upperbound AS pval_upperbound, gtex_term.lowerbound AS pval_lowerbound








-------------
ASD_TPM.csv | :
-------------

All of the genes from ASD (MP_00110403) and its child phenotypes that are expressed in the heart at 10 TPM or higher.


Cypher Query: --> 892 ms.

with 'MP:0010403' as parent   
match (b:Code {CODE:parent,SAB:'MP'})<-[:CODE]-(a:Concept)<-[:SCO *1..]-(n:Concept)-[:CODE]->(m:Code {SAB:'MP'}) 
with  collect(n.CUI) + a.CUI as terms unwind terms as uterms
with collect(distinct uterms) as phenos
match (mp_concept)-[:phenotype_has_associated_gene]-(hcop_concept:Concept)-[:CODE]->(mouse_gene:Code {SAB:'HGNC_HCOP'})
where mp_concept.CUI in phenos
match (hcop_concept)-[:has_human_ortholog]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB: 'HGNC'})
With *
match (gene_symbol:Term)<-[:PREF_TERM]-(hgnc_concept)
with hgnc_concept,human_gene, gene_symbol
match (hgnc_concept)-[:CODE]->(gl_code:Code {SAB:'GENE_LOCATION'})
with distinct human_gene,gl_code, gene_symbol
match (gstart:Term)<-[:gene_start_position]-(gl_code)-[r:gene_end_position]->(gend:Term)
match (gl_code)-[:on_chromosome]->(gchrom:Term)
with *
match (human_gene)-[:CODE]-(hgnc_concept)-[:gene_has_median_expression]->(gtex_concept:Concept)-[:median_expression_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code {SAB:'UBERON'})
where uberon_code.CODE in ['0006566','0006631']   
with *
match (gtex_concept)-[:CODE]->(gtex_code:Code {SAB:'GTEX_EXP'})-[:TPM]-(gtex_term:Term)
where gtex_term.lowerbound > 10
return distinct split(gene_symbol.name,' gene')[0] as symbol, gstart.name as start,gend.name as end,gchrom.name as chrom,human_gene.CODE as hgnc_id








--------------------
ASD_cell_types.csv | :
--------------------

Cardiac celltype (Asp) and gene log2fc levels associated with ASD and its child phenotypes that are expressed in the heart at 10 TPM or greater.

Cypher Query: --> 3552 ms.

with 'MP:0010403' as parent   
match (b:Code {CODE:parent,SAB:'MP'})<-[:CODE]-(a:Concept)<-[:SCO *1..]-(n:Concept)-[:CODE]->(m:Code {SAB:'MP'}) 
with  collect(n.CUI) + a.CUI as terms unwind terms as uterms
with collect(distinct uterms) as phenos
match (mp_concept)-[:phenotype_has_associated_gene]-(hcop_concept:Concept)-[:CODE]->(mouse_gene:Code {SAB:'HGNC_HCOP'})
where mp_concept.CUI in phenos
match (hcop_concept)-[:has_human_ortholog]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code) where human_gene.SAB = 'HGNC'
With *
match (gene_symbol:Term)<-[:PREF_TERM]-(hgnc_concept)
with hgnc_concept,human_gene, gene_symbol
match (human_gene)<-[:CODE]-(hgnc_concept)-[:gene_has_median_expression]->(gtex_concept:Concept)-[:median_expression_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code)
where uberon_code.SAB = 'UBERON' and uberon_code.CODE in ['0006566','0006631']    
with *
match (gtex_concept)-[:CODE]->(gtex_code:Code)-[:TPM]->(gtex_term:Term)
where gtex_code.SAB = 'GTEX_EXP' and gtex_term.lowerbound > 10
match (human_gene_2:Code {SAB:'HGNC'})<-[:CODE]-(b:Concept)-[:has_single_cell_expression]->(c:Concept)-[:CODE]->(d:Code {SAB:'scHeart PMID: 31835037'})-[:log2fc]->(t:Term) 
match (d)-[:p_value]->(t2:Term)
with *, collect(human_gene.CODE) as gene_list
where human_gene_2.CODE in gene_list
return split(gene_symbol.name,' gene')[0] as symbol, d.CODE as celltype_gene,t.name as log2fc, t2.lowerbound as pval_lowerbound, t2.upperbound as pval_upperbound 











