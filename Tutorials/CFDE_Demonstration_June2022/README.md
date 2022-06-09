# June 9, 2021 CFDE Tutorial
##Building blocks of queries on a CFDE-data populated property graph

For this tutorial/demonstration we'll be using a knowledge graph we're tentatively calling "PetaGraph."

PetaGraph is populated with the HuBMAP UMLS ontology graph, with CFDE data introduced within it. 
Additional data from mouse and human will be introduced this summer, as will some changes to the schema.

Here's some numbers representing datasets in PetaGraph that are important for this demonstration:

![summary_table.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/summary_table.png)


Our goal is to eventually build a user interface (UI) to allow for queries on an integrated CFDE database, to be driven by a front-end web engine, so that users of any experience level will be able to use the interface.

For this demonstration,  we'll be showing you the queries that will operate behind the UI.



## SUPPLEMENTAL INFO

**Main Project GitHub** (updating often)

[https://github.com/TaylorResearchLab/CFDIKG](https://github.com/TaylorResearchLab/CFDIKG)

If you'd like access to the database to recreate this demonstration, please contact Deanne Taylor and Jonathan Silverstein.

<A HREF="https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/Schema_CFDIKG_5-2022.md" target="new"> May 2022 Data Source Descriptions and Schema Reference</a> (right click to open in new window)

<A HREF="https://neo4j.com/developer/cypher/guide-cypher-basics/" target="new"> Getting started with Cypher (neo4j) </a> (right click to open in new window)

<A HREF="https://smart-api.info/ui/dea4bf91545a51b3dc415ba37e2a9e4e#/" target="new"> Python queries are based on the HuBMAP SMART API found here</A> (right click to open in new window)
 
## Introduction to PetaGraph, our experimental data-enriched version of the HuBMAP/UMLS database.

PetaGraph's model operates on unified biomedical concepts.  There are multiple ways of classifying the same biomedical term, but in this model there is one central unifying concept per conceptual item, from multiple terminology systems. For example, a human gene concept from Gencode v37 can be represented by several IDs depending on the originating database, but they are all representing the same gene concept node.

### Examples to try

Queries into a neo4j database operate on Cypher, parallel to how relational databases use SQL.

The schema structures data based on the idea of concept nodes as mentioned above. Concept nodes (shown here in orange) are those unifying principles that can support connections to multiple terminology systems (with IDs as "Codes"). In the example shown below, the central orange concept ID represents "acyclovir" which can have several IDs, found in databases such as ChEMBL, CHEBI, DrugBank, PubChem etc. 
Here, we show the code node (CHEBI ID, purple), for acyclovir.  Here, a "preferred term" (brown) reports the preferred name for the drug.
A similar structure is used for items such as gene names, ontologies, and other systems, as well as experimental data. 

**Simple Example #1:**

```graphql
MATCH (a:Term)<--(b:Concept)
-->(c:Code)-[d:PT]->(a),
(f:Definition)<--(b)-->
(g:Semantic)-->(h:Semantic),
(b)-[i:isa]->(j:Concept)
WHERE b.CUI = d.CUI
AND c.SAB = i.SAB
RETURN * LIMIT 1
```

![example_dataset.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/example_dataset.png)


**Simple Example #2:**  Learn about SABs (source abbreviations). 

Let's select specific datasets by specifying the SAB (source abbreviation) property on the Code node. Here we match on a HPO Code node and its corresponding Concept node. 

Other SABs to try are: HGNC (human genes), HGNC_HCOP (mouse genes), MP (mammalian phenotype), GTEX_EXP (GTEx expression data), GTEX_EQTL (GTEx eQTL data) 

 We can control how many ‘instances’ of the pattern are returned by using the LIMIT keyword. 

```graphql
MATCH (a:Concept)-[r:CODE]->(b:Code {SAB:"HPO"}) RETURN * LIMIT 5
```

**Simple Example #3:** 

Get the preferred term of a concept

```graphql
MATCH (a:Concept{CUI:"C0001367"})-[:PREF_TERM]->(b:Term) RETURN *
```


## More Complex Queries

### Basic "Level 1" queries

1. Exploring GTEx experimental data.  

Let's look at an example of a tissue-gene pair expression data point from the GTEx project. We will select out TPM data (transcripts per million) which are used to quantify how much of a gene is expressed within a sample.

In our query, we use "Limit 1" to prevent us from returning all the GTEx TPM values in the DB.

```graphql
MATCH (gtex_cui:Concept)-[r0:CODE]-(gtex_code:Code {SAB:'GTEX_EXP'})-[:TPM]-(gtex_term:Term)
RETURN * LIMIT 1
```

![GTEx_expression_1.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/GTEx_expression_1.png)

You can see from the image where I've moused over the Code node (purple) that this node represents an Ensembl ID + a tissue descriptor. The term associated with this code node is a binned TPM value ranging between 9 and 10 which can be used to select or display TPM ranges of interest. In a future release of this knowledge graph, the numerical type values will also be shown. 

Let's add the concept node of the gene represented by this TPM value: 

```graphql
MATCH (gtex_cui:Concept)-[r0:CODE]-(gtex_code:Code {SAB:'GTEX_EXP'})-[:TPM]-(gtex_term:Term)
MATCH (gtex_cui)-[r1]-(hgnc_concept:Concept)-[r2]-(hgnc_code:Code {SAB:'HGNC'})
RETURN * LIMIT 1
```
![GTEx_expression_2.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/GTEx_expression_2.png)


Next, let's add the concept code for the tissue related to this TPM value and gene. 



```graphql
MATCH (gtex_cui:Concept)-[r0:CODE]-(gtex_code:Code {SAB:'GTEX_EXP'})-[:TPM]-(gtex_term:Term)
MATCH (gtex_cui)-[r1]-(hgnc_concept:Concept)-[r2]-(hgnc_code:Code {SAB:'HGNC'})
MATCH (gtex_cui)-[r3]-(ub_concept:Concept)-[r4]-(ub_code:Code {SAB:'UBERON'}) 
RETURN * LIMIT 1
```


This query also displays the current graph structure of all the GTEx expression concept code relations:  HGNC gene <-> TPM value <-> Uberon ID.  It can be used to help build additional queries combining GTEx data with other datasets in the knowledge graph.


2. Can we find all phenotype-gene relationships given a certain phenotype?

For instance, given a HPO (phenotype) term, can we return all linked gene names?

We can accomplish this by leveraging the HPO-to-gene links in the knowledge graph, imported from the HPO-to-gene relationship list curated by Peter Robinson's group at Jax. That list was derived from Orphanet and OMIM. 

```graphql
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoTerm:Term)-[:PT]-(hpoCode:Code {CODE: HPO_CODE})-[r1:CODE]-(hpo_concept)-[r2]-(hgnc_concept:Concept)-[r3:CODE]-(hgnc_code:Code {SAB:'HGNC'})-[:PT]-(hgnc_term:Term) 
RETURN * LIMIT 10

```

![A Concept (blue), Code (purple) and Term (green) node from HPO (left side) and HGNC (right side) and the bidirectional relationships between the two Concept nodes.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/HPO_HGNC.png)

A Concept (blue), Code (purple) and Term (green) node from HPO (left side) and HGNC (right side) and the bidirectional relationships between the two Concept nodes.


Instead of a limited graph visual,  can obtain all the genes associated with a phenotype in a table by asking for specific outputs in the RETURN statement:

```graphql
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoTerm:Term)-[:PT]-(hpoCode:Code {CODE: HPO_CODE})-[r1:CODE]-(hpo_concept)-[r2]-(hgnc_concept:Concept)-[r3:CODE]-(hgnc_code:Code {SAB:'HGNC'})-[:PT]-(hgnc_term:Term) 
RETURN hgnc_code.CODE AS HGNC_ID, hgnc_term.name AS GENE_SYMBOL

```

3. Relate mouse to human data. 

Given an HGNC (gene) name, give the mouse gene name from HCOP

```graphql
WITH 'BRCA1' as gene_name
MATCH (hgnc_term:Term {name:gene_name+' gene'})-[:MTH_ACR]-(hgnc_code:Code {SAB:'HGNC'})-[r1:CODE]-(hpo_concept)-[r2:has_human_ortholog]-(mouse_gene_concept:Concept)-[r3:CODE]-(mouse_gene_code:Code {SAB:'HGNC_HCOP'}) 
RETURN *
```

![HGNC Concept (blue), Code (purple) and Term (green) from HGNC on the left and its corresponding Mouse gene Concept and code on the right  ](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/HGNC_HCOP.png)

HGNC Concept (blue), Code (purple) and Term (green) from HGNC on the left and its corresponding Mouse gene Concept and code on the right  


How about mapping mouse to human phenotypes?  Given an HPO code, return the corresponding MP code if known

```graphql
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoTerm:Term)-[r0:PT]-(hpoCode:Code {CODE:HPO_CODE})-[r1:CODE]-(hpo_concept)-[r2:has_mouse_phenotype]-(mp_concept:Concept)-[r3:CODE]-(mp_code:Code {SAB:'MP'})-[r4:Term]-(mpTerm:Term)
RETURN *
```

![A Concept (blue), Code (purple) and Term (green) from HPO on the left and its corresponding MP Concept, Code and Term on the right.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/HPO_MP.png)

A Concept (blue), Code (purple) and Term (green) from HPO on the left and its corresponding MP Concept, Code and Term on the right.



4. Starting with a human gene, find all (drug) compounds that affect expression of that gene in a LINCs dataset (binary relationship: upregulated or downregulated). The time/dosage/cell type variables in LINCS have been collapsed. In cases of conflicts (up or down) the data includes both up and down links. In the future we can include all data from LINCs.

```graphql
//Returns a table (not a graphic view)
//LINCS L1000, all positively or negatively correlated relatioships
WITH 'A2M' AS GENE_NAME
MATCH (hgncTerm:Term {name:GENE_NAME})<-[]-(hgncCode:Code {SAB:'HGNC'})<-[r1:CODE]-(hgnc_concept:Concept)-[r2 {SAB:'LINCS L1000'}]->(ChEBI_concept:Concept)-[r3:CODE]->(ChEBICode:Code {SAB:'CHEBI'}),(ChEBI_concept:Concept)-[:PREF_TERM]->(ChEBITerm:Term)
RETURN DISTINCT hgncTerm.name AS Gene_Symbol, type(r2) AS Correlation, ChEBITerm.name AS Compound 
```

```graphql
//Returns a table (not a graphic view)
//All positively correlated relatioships in CMAP and LINCS L1000
WITH 'RAFT1' AS GENE_NAME
MATCH (hgncTerm:Term {name:GENE_NAME})<-[]-(hgncCode:Code {SAB:'HGNC'})<-[r1:CODE]-(hgnc_concept:Concept)<-[r2:positively_correlated_with_gene]-(ChEBI_concept:Concept)-[r3:CODE]->(ChEBICode:Code {SAB:'CHEBI'}),(ChEBI_concept:Concept)-[:PREF_TERM]->(ChEBITerm:Term)
RETURN DISTINCT ChEBITerm.name AS Compound, type(r2) AS Correlation, hgncTerm.name AS Gene_Symbol, r2.SAB AS Source
```

```graphql
//Returns a table (not a graphic view)
//Connectivity MAP (CMAP), all positively or negatively correlated relatioships
WITH 'RAFT1' AS GENE_NAME
MATCH (hgncTerm:Term {name:GENE_NAME})<-[]-(hgncCode:Code {SAB:'HGNC'})<-[r1:CODE]-(hgnc_concept:Concept)-[r2 {SAB:'CMAP'}]->(ChEBI_concept:Concept)-[r3:CODE]->(ChEBICode:Code {SAB:'CHEBI'}),(ChEBI_concept:Concept)-[:PREF_TERM]->(ChEBITerm:Term)
RETURN DISTINCT hgncTerm.name AS Gene_Symbol, type(r2) AS Correlation, ChEBITerm.name AS Compound
```

5. Return all non-zero GTEx expression levels  for a specific tissue type, listed by top TPM (LIMIT 100)

```graphql
WITH 'aorta' AS tissuename
MATCH (ub_term:Term {name:tissuename})-[r0:PT]-(ub_code:Code {SAB:'UBERON'})-[r1:CODE]-(ub_cui:Concept)-[r2:tissue_has_median_expression]-(gtex_exp_cui:Concept)-[r3:CODE]-(gtex_exp_code:Code {SAB:'GTEX_EXP'})-[r4]-(gtex_term:Term) 
MATCH (gtex_exp_cui)-[r5:gene_has_median_expression]-(hgnc_cui:Concept)-[r6:PREF_TERM]-(hgnc_term:Term)
WHERE gtex_term.lowerbound > 0
RETURN  ub_term.name AS tissue, hgnc_term.name AS gene_symbol ,gtex_term.name AS TPM ORDER BY TPM DESCENDING limit 100
```

6. Return a significant (adj p val < .05 or lower) GTEx eQTL for 'aorta' as a specific tissue with p<0.05. The eQTL data schema is shown as a result of the query.

```graphql
WITH 'aorta' AS tissuename
MATCH (ub_term:Term {name:tissuename})-[r0:PT]-(ub_code:Code {SAB:'UBERON'})-[r1:CODE]-(ub_cui:Concept)-[r2:tissue_has_eqtl]-(gtex_eqtl_cui:Concept)-[r3:CODE]-(gtex_eqtl_code:Code {SAB:'GTEX_EQTL'})-[r4:p_value]-(eqtl_pval:Term) 
MATCH (gtex_eqtl_cui)-[r5:gene_has_eqtl]-(hgnc_cui:Concept)-[r6:PREF_TERM]-(hgnc_term:Term)
MATCH (gtex_eqtl_code)-[:variant_id]-(eqtl_varid:Term)
WHERE eqtl_pval.upperbound < 0.05
RETURN  * LIMIT 1
```

![An UBERON Concept, Code and Term (top left), an HGNC Concept and preferred Term (top right) and GTEx eQTL Concept, Code and Terms (center). The GTEx Terms shown here represent a binned  p-value and variant ID for the eQTL](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/GTEx_eQTL.png)

An UBERON Concept, Code and Term,  an HGNC Concept and preferred Term,  and GTEx eQTL Concept, Code and Terms. The GTEx eQTL terms shown here represent a binned  p-value and variant ID for the eQTL itself.

Next,  a table of all the significant (adj p val < .05 or lower) GTEx eQTLs for a specific tissue, listed by smallest pvalue (LIMIT 100). 

```graphql
WITH 'aorta' AS tissuename
MATCH (ub_term:Term {name:tissuename})-[r0:PT]-(ub_code:Code {SAB:'UBERON'})-[r1:CODE]-(ub_cui:Concept)-[r2:tissue_has_eqtl]-(gtex_eqtl_cui:Concept)-[r3:CODE]-(gtex_eqtl_code:Code {SAB:'GTEX_EQTL'})-[r4:p_value]-(eqtl_pval:Term) 
MATCH (gtex_eqtl_cui)-[r5:gene_has_eqtl]-(hgnc_cui:Concept)-[r6:PREF_TERM]-(hgnc_term:Term)
MATCH (gtex_eqtl_code)-[:variant_id]-(eqtl_varid:Term)
WHERE eqtl_pval.upperbound < 0.05
RETURN  ub_term.name AS uberon_tissue, hgnc_term.name AS gene_symbol,eqtl_varid.name as Variant_ID, eqtl_pval.name AS Pval  
ORDER BY Pval
LIMIT 100
```

7. The query below is exactly the same as the last one above but returns additional fields related to the eQTLs in a table:

```graphql
WITH 'aorta' AS tissuename
MATCH (ub_term:Term {name:tissuename})-[r0:PT]-(ub_code:Code {SAB:'UBERON'})-[r1:CODE]-(ub_cui:Concept)-[r2:tissue_has_eqtl]-(gtex_eqtl_cui:Concept)-[r3:CODE]-(gtex_eqtl_code:Code {SAB:'GTEX_EQTL'})-[r4:p_value]-(eqtl_pval:Term) 
MATCH (gtex_eqtl_cui)-[r5:gene_has_eqtl]-(hgnc_cui:Concept)-[r6:PREF_TERM]-(hgnc_term:Term)
MATCH (gtex_eqtl_code)-[:on_chromosome]-(eqtl_chrom:Term)
MATCH (gtex_eqtl_code)-[:eqtl_location]-(eqtl_loc:Term)
MATCH (gtex_eqtl_code)-[:rs_id_dbSNP151_GRCh38p7]-(eqtl_rsid:Term)
MATCH (gtex_eqtl_code)-[:variant_id]-(eqtl_varid:Term)
MATCH (gtex_eqtl_code)-[:gene_id]-(eqtl_gene_id:Term)
WHERE eqtl_pval.upperbound < 0.05
RETURN  ub_term.name AS uberon_tissue, hgnc_term.name AS gene_symbol,
eqtl_chrom.name AS Chromosome,
eqtl_loc.name AS Location, 
eqtl_rsid.name AS rsID, 
eqtl_varid.name AS Variant_ID,
eqtl_gene_id.name AS Gene_ID,
eqtl_pval.name AS Pval  
ORDER BY Pval
LIMIT 100
```

8. Return HuBMAP clusters related to a certain gene

In this next query we limit to one cluster for demonstration purposes.
Return clusters that express BRCA1 (or any gene as you like).

```graphql
WITH 'BRCA1' AS  gene_name, .2 AS threshold
MATCH (hgnc_term:Term {name:gene_name+' gene'})-[r0:MTH_ACR]-(hgnc_code:Code {SAB:'HGNC'})-[r1:CODE]-(hgnc_cui:Concept)-[r2]-(hubmap_cui:Concept)-[r3:CODE]-(cs:Code {SAB:'HUBMAPsc'})-[r4:normed_gene_expression_per_cluster]-(hubmap_term) 
WHERE hubmap_term.lowerbound > threshold
MATCH (hubmap_cui)-[r5:hubmap_node_belongs_to_cluster]-(hmClusterCUI:Concept)-[r6:CODE]-(hmClusterCode:Code)
WITH *, split(hmClusterCode.CODE,' ') AS cluster_num
MATCH (hmClusterCUI)-[r7:cluster_of_dataset]-(hmDatasetCUI)-[r8:CODE]-(hmDatasetCode:Code)
RETURN * LIMIT 1
```


Return a table with all HuBMAP clusters/samples that express a certain gene above a defined value threshold. 

```graphql
WITH 'BRCA1' AS  gene_name, .2 AS threshold
MATCH (hgnc_term:Term {name:gene_name+' gene'})-[r0:MTH_ACR]-(hgnc_code:Code {SAB:'HGNC'})-[r1:CODE]-(hgnc_cui:Concept)-[r2]-(hubmap_cui:Concept)-[r3:CODE]-(cs:Code {SAB:'HUBMAPsc'})-[r4:normed_gene_expression_per_cluster]-(hubmap_term) 
WHERE hubmap_term.lowerbound > threshold
MATCH (hubmap_cui)-[r5:hubmap_node_belongs_to_cluster]-(hmClusterCUI:Concept)-[r6:CODE]-(hmClusterCode:Code)
WITH *, split(hmClusterCode.CODE,' ') AS cluster_num
MATCH (hmClusterCUI)-[r7:cluster_of_dataset]-(hmDatasetCUI)-[r8:CODE]-(hmDatasetCode:Code)
RETURN DISTINCT split(hgnc_term.name,' ')[0] AS gene,
      cluster_num[1]+' '+cluster_num[2] AS cluster_num, hmDatasetCode.CODE AS hubmap_dataset,hubmap_term.name AS expression ORDER BY hubmap_dataset
```

![From left to right (Concepts are orange): A tissue Concept (could be UBERON, FMA or SNOMED) , HuBMAP dataset Concept, HuBMAP cluster Concept (most datasets have between 10 and 20 clusters), HuBMAP expression Concept and a HGNC Concept.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/hubmap2.png)

From left to right (Concepts are orange): A tissue Concept (could be UBERON, FMA or SNOMED) , HuBMAP dataset Concept, HuBMAP cluster Concept (most datasets have between 10 and 20 clusters), HuBMAP expression Concept and a HGNC Concept.

 9. How many phenotypes are present for a study subject in the Kids First project?
 
 
 Return HPO codes, phenotype names and number of phenotype for each Kids First subject in the knowledge graph

```graphql
MATCH (kfCode:Code {SAB:'KF'})-[r0:CODE]-(kfCUI:Concept)-[r1:patient_has_phenotype]-(hpoCUI:Concept)-[:CODE]-(hpoCode:Code {SAB:'HPO'})-[r2:PT]-(hpoTerm:Term)
WITH kfCode, collect(DISTINCT hpoTerm.name) AS hpo_terms, collect(DISTINCT hpoCode.CODE) AS hpo_codes 
RETURN kfCode.CODE AS KF_ID,
       size(hpo_terms) AS num_phenotypes,
			 hpo_codes, hpo_terms 
	     ORDER BY num_phenotypes 
			 DESCENDING LIMIT 100
```



### Level II queries: Combining information from 2 Common Fund datasets.

10. Given a subject's Kids First ID, can we find all the HPO terms related to that subject, and then find all genes associated with those HPO terms, then  find GTEx cis-eQTLs related to those genes. 

```graphql
WITH 'PT_1J582GQE' AS KF_ID
MATCH (kfCode:Code {SAB:'KF',CODE: KF_ID})-[r0:CODE]-(kfCUI:Concept)-[r1:patient_has_phenotype]-(hpoCUI:Concept)-[r2:phenotype_associated_with_gene]-(hgncCUI:Concept)-[r3:gene_has_eqtl]-(gtexEqtlCUI:Concept)-[r4:CODE]-(gtexEqtlCode:Code)
MATCH (hpoCUI)-[r5:CODE]-(hpoCode)
MATCH (hgncCUI)-[r6:CODE]-(hgncCode {SAB:'HGNC'})-[r7:PT]-(hgncTerm:Term)
MATCH (gtexEqtlCode)-[r8:on_chromosome]-(eqtl_chrom:Term)
MATCH (gtexEqtlCode)-[r9:eqtl_location]-(eqtl_loc:Term)
MATCH (gtexEqtlCode)-[r10:p_value]-(eqtl_pval:Term)
WHERE eqtl_pval.upperbound < 1e-10
MATCH (gtexEqtlCode)-[r11:rs_id_dbSNP151_GRCh38p7]-(eqtl_rsID:Term)
RETURN * LIMIT 1
```

![Example of an HPO term related to a subject and the genes associated with that HPO term, and then the GTEx eQTL associated with a gene](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/KF_phenotype_eqtl.png)

Return a table like above with all HPO terms and associated genes, GTEx cis-EQTL Note that this query is not returning variants actually found within the subject, but rather potential locations to test for variants,  given the phenotypes associated with the subject.

```graphql
WITH 'PT_1J582GQE' AS KF_ID
MATCH (kfCode:Code {SAB:'KF',CODE: KF_ID})-[r0:CODE]-(kfCUI:Concept)-[r1:patient_has_phenotype]-(hpoCUI:Concept)-[r2:phenotype_associated_with_gene]-(hgncCUI:Concept)-[r3:gene_has_eqtl]-(gtexEqtlCUI:Concept)-[r4:CODE]-(gtexEqtlCode:Code)
MATCH (hpoCUI)-[r5:CODE]-(hpoCode)
MATCH (hgncCUI)-[r6:CODE]-(hgncCode {SAB:'HGNC'})-[r7:PT]-(hgncTerm:Term)
MATCH (gtexEqtlCode)-[r8:on_chromosome]-(eqtl_chrom:Term)
MATCH (gtexEqtlCode)-[r9:eqtl_location]-(eqtl_loc:Term)
MATCH (gtexEqtlCode)-[r10:p_value]-(eqtl_pval:Term)
WHERE eqtl_pval.upperbound < 1e-10
MATCH (gtexEqtlCode)-[r11:rs_id_dbSNP151_GRCh38p7]-(eqtl_rsID:Term)
RETURN KF_ID, hpoCode.CODE AS hpo_code, 
hgncTerm.name AS hgnc_symbol,
 eqtl_chrom.name AS eqtl_chromosome,
 eqtl_loc.name AS location,
 eqtl_rsID.name AS rsID, 
 eqtl_pval.name AS pvalue LIMIT 100
```

11. Can we identify GTEx tissues that are most likely to be affected by a specific chemical compound measured in the LINCs project?

For this query, we need to find those tissues actually expressing a gene whose expression is affected by a compound, mosapride. 

We use the LINCS dataset to find those genes that are affected by mosapride, and then we find all the tissues in GTEx with those genes TPM > a user-specified threshold. 

This is limited to 2 results for graphing purposes. The query after this one returns the full table.

```graphql
//Returns a table containing compund generic name correlated with genes with higher than threshold expression level in different tissues
WITH 'mosapride' AS COMPOUND_NAME, 5 AS MIN_EXP 
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ub_cui:Concept)-[:PREF_TERM]->(ub_term:Term),
(gtex_exp_cui:Concept)-[:CODE]->(gtex_exp_code:Code {SAB:'GTEX_EXP'})-[]->(gtex_term:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]-(hgncTerm:Term)
WHERE gtex_term.lowerbound > MIN_EXP 
RETURN * LIMIT 2
```
![GTEx tissues likely affected by a compound ](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/LINCS_mosapride_GTEx.png)

For all tissues affected by mosapride, return the full table

```graphql
//Returns a table containing compund generic name correlated with genes with higher than threshold expression level in different tissues
WITH 'mosapride' AS COMPOUND_NAME, 5 AS MIN_EXP 
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ub_cui:Concept)-[:PREF_TERM]->(ub_term:Term),
(gtex_exp_cui:Concept)-[:CODE]->(gtex_exp_code:Code {SAB:'GTEX_EXP'})-[]->(gtex_term:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]-(hgncTerm:Term)
WHERE gtex_term.lowerbound > MIN_EXP 
RETURN DISTINCT ChEBITerm.name AS Compound, hgncTerm.name AS GENE, ub_term.name AS Tissue, gtex_term.lowerbound AS Expression_Level ORDER BY Expression_Level ASCENDING
```


12. Can we find genesets ("pathways") in the MSigDB resource, that may be affected by mosapride based on data from LINCS?

Here we find an intersection between MSigDB Hallmark pathways given a target LINCS compound, by using genes associated with those entities


```graphql
//Returns the graph linkage of MSigDB hallmark pathways associated with their 
//signature genes regulated by a compound in LINCS L1000
WITH 'mosapride' AS COMPOUND_NAME
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[r2 {SAB:'MSigDB H'}]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term)
RETURN * LIMIT 1
```

![Pathways related to LINCS compounds ](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/LINCS_mosapride_MSIGDB.png)


Return a table based on the above with all pathways affected.

```graphql
//Returns a list of MSigDB hallmark pathways regulated by the given LINCS compound
WITH 'mosapride' AS COMPOUND_NAME
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[r2 {SAB:'MSigDB H'}]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term)
RETURN ChEBITerm.name AS Compound,msigdbTerm.name AS Pathway, hgncTerm.name AS Gene
```

13. Can we find a HuBMAP cluster expressing genes that are also related to a specific human phenotype?

Find all HuBMAP clusters expressing at least one gene related to a particular human phenotype (using OMIM).
Here we just use HP:0001631, Atrial Septal Defect. To gain more relationships, change the limit and check out the table ("Text") view on the left of the query interface.

```graphql
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoTerm:Term)-[r0:PT]-(hpoCode:Code {CODE:HPO_CODE})-[r1:CODE]-(hpoCUI:Concept)-[r2:phenotype_associated_with_gene]->(hgncCUI:Concept)-[r3:gene_expression_of_hubmap_study]->(hubmap_cui:Concept)-[r5:hubmap_node_belongs_to_cluster]-(hmClusterCUI:Concept)-[r6:CODE]-(hmClusterCode:Code)
MATCH (hmClusterCUI:Concept)-[r7:cluster_of_dataset]-(hmDatasetCUI:Concept)-[r8:hubmap_dataset_contains_tissue]-(tissueCUI:Concept)-[r9:CODE]-(tissueCode:Code)-[r10:PT]-(tissueTerm:Term)
RETURN * limit  1
```

![hubmap_phenoptype.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/hubmap_phenoptype.png)

	
**Level III queries**

14. There is evidence that heart defects could be related to changes in developmental programs due to dysregulation of glycosylation.  What glycans are predicted to be found on genes associated with Atrial Septal Defects?


```graphql
//Starting with HPO human phenotypes, glycans will be extracted in association with Human genes
MATCH (m:Code {CODE:'HP:0001631'})<-[:CODE]-(n:Concept)<-[r:isa*..1 {SAB:'HPO'}]-(o:Concept) WITH collect(n.CUI)+o.CUI AS T UNWIND T AS UT WITH collect(DISTINCT UT) AS PHS MATCH (q:Concept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]->(t:Concept)-[:has_product]->(u:Concept)-[:has_site]->(v:Concept)-[:binds_glycan]->(w:Concept),
(t)-[:CODE]->(:Code)-[:SYN]->(a:Term),
(u)-[:CODE]->(b:Code),(v)-[:PREF_TERM]->(c:Term),
(w)-[:CODE]->(d) WHERE q.CUI IN PHS 
RETURN * limit 1
```
![Protein_Glycan1.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/Protein_Glycan1.png)


Table return of the above query.


```graphql
//Returns a table (not a graphic view)
//Starting with HPO human phenotypes, glycans will be extracted in association with Human genes
MATCH (m:Code {CODE:'HP:0001631'})<-[:CODE]-(n:Concept)<-[r:isa*..1 {SAB:'HPO'}]-(o:Concept) WITH collect(n.CUI)+o.CUI AS T UNWIND T AS UT WITH collect(DISTINCT UT) AS PHS MATCH (q:Concept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]->(t:Concept)-[:has_product]->(u:Concept)-[:has_site]->(v:Concept)-[:binds_glycan]->(w:Concept),
(t)-[:CODE]->(:Code)-[:SYN]->(a:Term),
(u)-[:CODE]->(b:Code),(v)-[:PREF_TERM]->(c:Term),
(w)-[:CODE]->(d) WHERE q.CUI IN PHS 
RETURN DISTINCT a.name AS Gene, 
b.CODE AS UniProtKB_AC, 
c.name AS Glycosylation_Type_Site_ProteinID, 
d.CODE AS Glycan
```

15. I'm interested in finding relationships betwen human phenotypes and gene pathways/genesets. Which human phenotypes are associated with MSigDB genesets/pathways, using gene-tissue expression information in GTEx?

Find all pathways in MSigDB linked to genes expressed in GTEx tissues that are known to be linked to human phenotypes.

Returns HPO terms associated with genes and GTEx tissues MSigDB pathways associated with the genes. For the graphic, we "LIMIT 1". Table format query below will return many more.

```graphql
//Returns HPO terms associated with genes and GTEx tissues MSigDB pathways associated with the genes
MATCH (ubCode:Code {SAB:'UBERON'})-[:CODE]-(ubConcept:Concept)-[]-(hpoConcept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]-(hgncConcept:Concept)-[r1]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ubConcept:Concept)-[:PREF_TERM]->(ubTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term),
(hpoCode:Code {SAB:'HPO'})<-[:CODE]-(hpoConcept)
WHERE r1.SAB CONTAINS 'MSigDB C2'
RETURN hgncConcept,hgncCode,hgncTerm,msigdbConcept,msigdbTerm,gtex_exp_cui,ubConcept,
ubCode,ubTerm,hpoConcept,hpoCode
```

![hpo_gtex_msigdb.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/hpo_gtex_msigdb.png)



```graphql
//Returns HPO terms associated with genes and GTEx tissues MSigDB pathways associated with the genes
MATCH (ubCode:Code {SAB:'UBERON'})-[:CODE]-(ubConcept:Concept)-[]-(hpoConcept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]-(hgncConcept:Concept)-[r1]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ubConcept:Concept)-[:PREF_TERM]->(ubTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term),
(hpoCode:Code {SAB:'HPO'})<-[:CODE]-(hpoConcept)
WHERE r1.SAB CONTAINS 'MSigDB C2'
RETURN hgncConcept,hgncCode,hgncTerm,msigdbConcept,msigdbTerm,gtex_exp_cui,ubConcept, 
ubCode,ubTerm,hpoConcept,hpoCode LIMIT 100
```


16. I hypothesize that LGR6, a stem cell regulation gene, may have some relationship to heart development. How is the human phenotype of Atrial Septal Defects related to LGR6 in the knowledge graph?

Shortest path between an HPO term and a gene and return everything on the path and the path length, with and without using MSigDB. 

```graphql
//With MSigDB relatioships
WITH 'HP:0001631' AS HPO_CODE, 'HNRNPH2' AS GENE_NAME
MATCH (hpoCode:Code {CODE:HPO_CODE})<-[:CODE]-(hpoConcept:Concept), 
(hgncTerm:Term {name:GENE_NAME})<-[]-(hgncCode:Code {SAB:'HGNC'})<-[:CODE]-(hgncConcept:Concept), 
p = shortestPath((hgncConcept)-[*]->(hpoConcept))
RETURN p, hgncCode, hgncTerm, hpoCode
```

```graphql
//Without MSigDB relatioships
WITH 'HP:0001631' AS HPO_CODE, 'HNRNPH2' AS GENE_NAME
MATCH (hpoCode:Code {CODE:HPO_CODE})<-[:CODE]-(hpoConcept:Concept), 
(hgncTerm:Term {name:GENE_NAME})<-[]-(hgncCode:Code {SAB:'HGNC'})<-[:CODE]-(hgncConcept:Concept), 
p = shortestPath((hgncConcept)-[r*]->(hpoConcept)) WHERE NONE(R IN r WHERE R.SAB CONTAINS 'MSigDB')
RETURN  p AS Path
```

![hpo_to_gene_path.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/hpo_to_gene_path.png)

Note “coexpressed_with” is based on GTEx (click on table result as SAB). Codes are orange, terms are Blue, and concept nodes are in purple.

17. Shortest path between an HPO term and all genes and return everything on the path and the path length

```graphql
//Given an HPO term find shortest paths with all HGNC genes
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoCode:Code {CODE:HPO_CODE})<-[:CODE]-(hpoConcept:Concept),
(hgncCode:Code {SAB:'HGNC'})<-[:CODE]-(hgncConcept:Concept)-[:PREF_TERM]->(hgncTerm:Term),
p = shortestPath((hgncConcept)-[*]->(hpoConcept)) 
RETURN hpoCode, hgncTerm, p LIMIT 10
```

```graphql
//Given an HPO term find shortest paths with all HGNC genes and return it as table
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoCode:Code {CODE:HPO_CODE})<-[:CODE]-(hpoConcept:Concept),
(hgncCode:Code {SAB:'HGNC'})<-[:CODE]-(hgncConcept:Concept)-[:PREF_TERM]->(hgncTerm:Term),
p = shortestPath((hgncConcept)-[*]->(hpoConcept)) 
RETURN hpoCode.CODE AS HPO_Accession, 
hgncTerm.name AS Gene_ID, 
length(p) AS Shortest_Path_Length LIMIT 10
```

![graph.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/graph%201.png)

Shows every gene (as Term nodes in blue) related to the HPO term (as Code node in orange), and finds the shortest paths (by Concept nodes — in purple) [Click for zoomable SVG, then right-click on new image and open in new window.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/graph%201.svg)
