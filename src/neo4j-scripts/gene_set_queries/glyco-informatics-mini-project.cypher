
From Deanne - 

We know that heart defects are related to abberations in glycosylation from earlier studies
So proteins are either not correctly glycosylated on the protein, or not glycosylated at the right time.
Generously, we've only solved 50% of cases with heart defects, by finding some kind of genetic cause. The number overall is a bit lower than that.
So there has to be something we're not checking out, not noticing.
One of those things would be checking variants that may change glycosylation sites.
For example, are there gly-eqtls -- variants that change the amount or timing of glycosylation during development
Or basic variants that change a serine or a threonine to something else?
Finding variants that change serine to threonine in uniprot data in kids first data would be fairly simple to do, 
if we had all that data integrated and maybe linked to genes we suspect are important in heart defects.
Or even just have glycosylation sites in /any/ protein, even if we don't know if it's linked to heart defects,
but find there's a likely impact to glycosylation in genes that express in early human heart development.
So our story is, we have a lot of variability in kids with heart defects. We don't know what the physiological/functional 
impart would be for the majority of those variants.
One strategy could just be to test any variants in glycotransferases. 
Second strategy is, can we test for variants changing serine/threonine amino acids in proteins with glycosylation sites,
or any amino acids around those ser/thr, in genes we know express in GTEx human heart?
Third strategy is, can we test for variants in genes that are /expressed/ in the early heart that also 
have glycosylation sites predicted? What cell types (on clustering) in early human heart seem to have the most  
proteins with glyosylation sites?
So that's pretty much the story.
Add to that is the idea that we would like to show the differences from cell type to cell type, or 
tissue to tissue, are there differences in actual glycans employed by each tissue? Or each cell type?




#################################
###### Bens Queries #############
#################################

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




# HPO --> HGNC


WITH 'HP:0001631' AS parent    
MATCH (P_code:Code {CODE:parent,SAB:'HPO'})<-[:CODE]-(P_concept:Concept)<-[:isa *1.. {SAB:'HPO'}]-(C_concept:Concept)
WITH  collect(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms WITH collect(DISTINCT uterms) AS phenos
MATCH (hpo_concept:Concept)-[s]->(hgnc_concept:Concept)-[:CODE]->(human_gene:Code {SAB: 'HGNC'})
WHERE hpo_concept.CUI IN phenos 
WITH hgnc_concept,human_gene
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
WITH DISTINCT human_gene,gene_symbol
OPTIONAL MATCH  (human_gene)-[q]-(gly:Term)
WHERE gly.name IN ['Glycosyltransferase','Glycan']
RETURN DISTINCT split(gene_symbol.name,' gene')[0] AS symbol,human_gene.CODE AS hgnc_id, gly.name AS protein_type







