Tetralogy of Fallot MP phenotypes :
--------------------------------- 

MP:0010402 - ventricular septal defect

MP:0000273 - overriding aortic valve

MP:0000276 - heart right ventricle hypertrophy

MP:0006128 - pulmonary valve stenosis




----------------
 TET_genes.csv | :
----------------

All genes associated with the 4 Tet Phenotypes.

Cypher Query:  --> 195 ms.

with ['MP:0010402','MP:0000273','MP:0000276','MP:0006128'] as phenos
match (P_code:Code)<-[:CODE]-(mp_concept:Concept)-[:phenotype_has_associated_gene]->(hcop_concept:Concept)-[:CODE]->(mouse_gene:Code)
where P_code.CODE in phenos and mouse_gene.SAB = 'HGNC_HCOP' and P_code.SAB = 'MP'
match (hcop_concept)-[:has_human_ortholog]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code) where human_gene.SAB = 'HGNC'
with hgnc_concept,human_gene
match (gene_symbol:Term)<-[:PREF_TERM]-(hgnc_concept)-[:CODE]->(gl_code:Code) where gl_code.SAB = 'GENE_LOCATION'
with distinct human_gene,gl_code, gene_symbol
match (gstart:Term)<-[:gene_start_position]-(gl_code)-[:gene_end_position]->(gend:Term)
match (gl_code)-[:on_chromosome]->(gchrom:Term)
return distinct split(gene_symbol.name,' gene')[0] as symbol,gstart.name as start,gend.name as end,gchrom.name as chrom,human_gene.CODE as hgnc_id




----------------
 TET_eQTLs.csv | :
----------------

eQTLs (pvals < .05) associated with the 4 Tet phenotypes from genes that are expressed in the heart 


Cypher Query:

with ['MP:0010402','MP:0000273','MP:0000276','MP:0006128'] as phenos
match (P_code:Code )-[:CODE]-(mp_concept:Concept)-[:phenotype_has_associated_gene]-(hcop_concept:Concept)-[:CODE]->(mouse_gene:Code)
where P_code.CODE in phenos and P_code.SAB = 'MP' and mouse_gene.SAB = 'HGNC_HCOP'
match (hcop_concept)-[:has_human_ortholog]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code) where human_gene.SAB = 'HGNC'
with hgnc_concept,human_gene
match (gene_symbol:Term)<-[:PREF_TERM]-(hgnc_concept)-[:CODE]->(gl_code:Code) where gl_code.SAB = 'GENE_LOCATION'
with distinct human_gene,gl_code, gene_symbol
match (gstart:Term)<-[:gene_start_position]-(gl_code)-[r:gene_end_position]->(gend:Term)
match (gl_code)-[:on_chromosome]->(gchrom:Term)
with *
match (human_gene)<-[:CODE]-(hgnc_concept)-[:gene_has_eqtl]->(gtex_concept:Concept)-[:eqtl_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code)
where uberon_code.CODE in ['0006566','0006631'] and uberon_code.SAB = 'UBERON'
with *
match (gtex_concept)-[:CODE]->(gtex_code:Code)-[:p_value]->(gtex_term:Term)
where gtex_term.upperbound < .05 and gtex_code.SAB = 'GTEX_EQTL'
match (eqtl_loc_term:Term)<-[:eqtl_location]-(gtex_code)-[:rs_id_dbSNP151_GRCh38p7]->(rs_id_term:Term)
with * 
return distinct split(gene_symbol.name,' gene')[0] as symbol,rs_id_term.name as rsid, eqtl_loc_term.name as eqtl_location, gstart.name as start,gend.name as end,gchrom.name as chrom,human_gene.CODE as hgnc_id,gtex_term.upperbound as pval_upperbound, gtex_term.lowerbound as pval_lowerbound


-------------
Tet_TPM.csv | :
-------------

All genes associated with the 4 Tet phenotypes that are expressed in the heart at 10 or greater TPM.


Cypher Query:

with ['MP:0010402','MP:0000273','MP:0000276','MP:0006128'] as tet_phenos
match (a:Code)-[:CODE]-(mp_concept:Concept)-[:disease_has_associated_gene]->(hcop_concept:Concept)-[:CODE]->(mouse_gene:Code)
where a.CODE in tet_phenos and a.SAB = 'MP' and mouse_gene.SAB = 'HGNC_HCOP'
match (hcop_concept)-[:has_human_ortholog]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code) where human_gene.SAB = 'HGNC'
with * 
match (gene_symbol:Term)<-[:PREF_TERM]-(hgnc_concept)
with hgnc_concept,human_gene, gene_symbol
match (human_gene)<-[:CODE]-(hgnc_concept)-[:gene_has_median_expression]->(gtex_concept:Concept)-[:median_expression_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code)
where uberon_code.SAB = 'UBERON' and uberon_code.CODE in ['0006566','0006631']    
with *
match (gtex_concept)-[:CODE]->(gtex_code:Code)-[:TPM]->(gtex_term:Term)
where gtex_code.SAB = 'GTEX_EXP' and gtex_term.lowerbound > 10
with *
match (hgnc_concept)-[:CODE]->(gl_code:Code) where gl_code.SAB = 'GENE_LOCATION'
with distinct human_gene,gl_code, gene_symbol
match (gstart:Term)<-[:gene_start_position]-(gl_code)-[r:gene_end_position]->(gend:Term)
match (gl_code)-[:on_chromosome]->(gchrom:Term)
return distinct split(gene_symbol.name,' gene')[0] as symbol,gstart.name as start,gend.name as end,gchrom.name as chrom,human_gene.CODE as hgnc_id




-------------------
TET_cell_types.csv | :
-------------------

Cardiac celltype (Asp) and gene log2fc levels associated with the 4 Tet phenotypes that are expressed in the heart at 10 TPM or greater.


Cypher Query:  --> 21230 ms.

with ['MP:0010402','MP:0000273','MP:0000276','MP:0006128'] as tet_phenos
match (a:Code)-[:CODE]-(mp_concept:Concept)-[:disease_has_associated_gene]->(hcop_concept:Concept)-[:CODE]-(mouse_gene:Code)
where a.CODE in tet_phenos and a.SAB = 'MP' and mouse_gene.SAB = 'HGNC_HCOP'
match (hcop_concept)-[:has_human_ortholog]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code) where human_gene.SAB = 'HGNC'
With *
match (gene_symbol:Term)<-[:PREF_TERM]-(hgnc_concept)
with hgnc_concept,human_gene, gene_symbol
match (human_gene)<-[:CODE]-(hgnc_concept)-[:gene_has_median_expression]->(gtex_concept:Concept)-[:median_expression_in_tissue]->(uberon_concept:Concept)-[:CODE]->(uberon_code:Code)
where uberon_code.SAB = 'UBERON' and uberon_code.CODE in ['0006566','0006631']    // INSERT UBERON TISSUE CODES 
with *
match (gtex_concept)-[:CODE]->(gtex_code:Code)-[:TPM]->(gtex_term:Term)
where gtex_code.SAB = 'GTEX_EXP' and gtex_term.lowerbound > 10   
with *
//######################## including this part returns less genes
match (hgnc_concept)-[:CODE]->(gl_code:Code) where gl_code.SAB = 'GENE_LOCATION'
with distinct human_gene,gl_code, gene_symbol
match (gstart:Term)<-[:gene_start_position]-(gl_code)-[r:gene_end_position]->(gend:Term)
match (gl_code)-[:on_chromosome]->(gchrom:Term)
With *
//#######################
match (human_gene_2:Code)<-[:CODE]-(b:Concept)-[:has_single_cell_expression]->(c:Concept)-[:CODE]->(d:Code)-[:log2fc]->(t:Term) 
where human_gene_2.SAB = 'HGNC' and d.SAB = 'scHeart PMID: 31835037'
match (d)-[:p_value]->(t2:Term)
with *, collect(human_gene.CODE) as gene_list
where human_gene_2.CODE in gene_list
return split(gene_symbol.name,' gene')[0] as symbol, gstart.name as start,gend.name as end,gchrom.name as chrom,d.CODE as celltype_gene,t.name as log2fc, t2.lowerbound as pval_lowerbound, t2.upperbound as pval_upperbound 
