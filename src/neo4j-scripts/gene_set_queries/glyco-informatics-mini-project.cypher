
##################################################################################################################################################
## Very similair to the ASD/ToF queries, except we dont return all the gene code annotations (start/end pos., strand, chrom,),
## and we only care about whether or not the gene code has a relationship with either a 'Glycosyltransferase' or a 'Glycan' Term.
## The goal is to generate a gene set for every HPO term (or aa family of HPO Terms) in the list (from Deanne) and see how many of the genes 
## in each list make proteins that act as a Glycosyltransferase or Glycan.
##################################################################################################################################################


# 1.) start with HPO term and convert directly to its corresponding MP term 
# 2.) collect all child nodes one level down recursively of this MP term and add the child terms 
        together with the parent term to create a list of phenotype
# 3.) find all mouse genes associated with these phenotypes and convert to their 
        corresponding human orthologs, and get the actual gene symbols
# 4.) optionally match all genes 


// 1
WITH  'HP:0001631' AS parent_hpo
MATCH (co1:Code {CODE:parent_hpo})<-[:CODE]-(c1:Concept)-[a]-(c2:Concept)-[:CODE]->(P_code:Code {SAB:'MP'})
// 2
MATCH (P_code)<-[:CODE]-(P_concept:Concept)<-[:isa  *1.. {SAB:'MP'}]-(C_concept:Concept)
WITH  collect(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms WITH collect(DISTINCT uterms) AS phenos
MATCH (mp_concept:Concept)-[r:CODE]->(mp_code:Code)
WHERE mp_concept.CUI in phenos
// 3
MATCH (mp_concept:Concept)-[s]->(hgnc_hcop_Concept:Concept)-[:has_mouse_ortholog]-(hgnc_concept:Concept)-[:CODE]-(human_gene:Code {SAB:'HGNC'}) 
WITH hgnc_concept,human_gene
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
WITH DISTINCT human_gene,gene_symbol
// 4
OPTIONAL MATCH  (human_gene)-[q]-(gly:Term)
WHERE gly.name IN ['Glycosyltransferase','Glycan']
RETURN DISTINCT split(gene_symbol.name,' gene')[0] AS symbol,human_gene.CODE AS hgnc_id, gly.name AS protein_type 




find total # of glycosyltransferases out of all genes as % and then compare that as baseline to our findings.




















WITH 'HP:0001631' AS parent    
MATCH (P_code:Code {CODE:parent,SAB:'HPO'})<-[:CODE]-(P_concept:Concept)<-[:isa  *1.. {SAB:'HPO'}]-(C_concept:Concept)
WITH  collect(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms WITH collect(DISTINCT uterms) AS phenos
MATCH (hpo_concept:Concept)-[r:phenotype_associated_with_gene]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB: 'HGNC'})
WHERE hpo_concept.CUI IN phenos 
WITH hgnc_concept,human_gene
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
WITH DISTINCT human_gene,gene_symbol
MATCH (human_gene)-[q]-(gly:Term)
WHERE gly.name IN ['Glycosyltransferase','Glycan']
RETURN DISTINCT split(gene_symbol.name,' gene')[0] AS symbol,human_gene.CODE AS hgnc_id, gly.name AS protein_type  
