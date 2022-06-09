# June 9, 2021 CFDE Tutorial

Our goal is to both grow the database and build a user interface (UI) to allow for queries on an integrated CFDE database, to be driven by a front-end web engine, so that users of any experience level will be able to use the interface.

For this demonstration,  we'll be showing you the queries that will operate behind the UI.


## Just some logistics

**Main Project GitHub** (updating often)

[https://github.com/TaylorResearchLab/CFDIKG](https://github.com/TaylorResearchLab/CFDIKG)

If you'd like access to the database to recreate this demonstration, please contact Deanne Taylor and Jonathan Silverstein.

### SUPPLEMENTAL INFO

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

### Level I queries: One CFDE dataset

1. Display the structure of the GTEx expression data.  Return 1 (LIMIT 1) GTEx CUI, and expression and tissue codes and Term (binned TPM).   This will display the  actual nodes as a graph.  If executed with cypher-shell (on the command line) or via the api, you’ll have several json objects returned. 

```graphql
MATCH (gtex_cui:Concept)-[r0:CODE]-(gtex_code:Code {SAB:'GTEX_EXP'})-[:TPM]-(gtex_term:Term)
MATCH (gtex_cui)-[r1]-(hgnc_concept:Concept)-[r2]-(hgnc_code:Code {SAB:'HGNC'})
MATCH (gtex_cui)-[r3]-(ub_concept:Concept)-[r4]-(ub_code:Code {SAB:'UBERON'}) 
RETURN * LIMIT 1
```

![GTEx_expression.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/GTEx_expression.png)

2. Given a HPO (phenotype) term, return all linked gene names by leveraging the HPO-to-gene links curated by Peter Robinson's group at Jax. The phenotype<->gene relationships are obtained from Orphanet and OMIM. A future iteration of this graph will indicate which are from Orphanet, and which are from OMIM.

```graphql
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoTerm:Term)-[:PT]-(hpoCode:Code {CODE: HPO_CODE})-[r1:CODE]-(hpo_concept)-[r2]-(hgnc_concept:Concept)-[r3:CODE]-(hgnc_code:Code {SAB:'HGNC'})-[:PT]-(hgnc_term:Term) 
RETURN hgnc_code.CODE AS HGNC_ID, hgnc_term.name AS GENE_SYMBOL

```

![A Concept (blue), Code (purple) and Term (green) node from HPO (left side) and HGNC (right side) and the bidirectional relationships between the two Concept nodes.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/HPO_HGNC.png)

A Concept (blue), Code (purple) and Term (green) node from HPO (left side) and HGNC (right side) and the bidirectional relationships between the two Concept nodes.

![Same as above but now showing multiple genes associated with the same HPO Code. ](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/HPO_HGNC_many_genes.png)

Same as above but now showing multiple genes associated with the same HPO Code. 

3. Given an HGNC (gene) name, give the mouse gene name from HCOP

```graphql
WITH 'BRCA1' as gene_name
MATCH (hgnc_term:Term {name:gene_name+' gene'})-[:MTH_ACR]-(hgnc_code:Code {SAB:'HGNC'})-[r1:CODE]-(hpo_concept)-[r2:has_human_ortholog]-(mouse_gene_concept:Concept)-[r3:CODE]-(mouse_gene_code:Code {SAB:'HGNC_HCOP'}) 
RETURN *
```


![HGNC Concept (blue), Code (purple) and Term (green) from HGNC on the left and its corresponding Mouse gene Concept and code on the right  ](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/HGNC_HCOP.png)

HGNC Concept (blue), Code (purple) and Term (green) from HGNC on the left and its corresponding Mouse gene Concept and code on the right  

4. Given an HPO code, return the corresponding MP code if known

```graphql
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoTerm:Term)-[r0:PT]-(hpoCode:Code {CODE:HPO_CODE})-[r1:CODE]-(hpo_concept)-[r2:has_mouse_phenotype]-(mp_concept:Concept)-[r3:CODE]-(mp_code:Code {SAB:'MP'})-[r4:Term]-(mpTerm:Term)
RETURN *
```

![A Concept (blue), Code (purple) and Term (green) from HPO on the left and its corresponding MP Concept, Code and Term on the right.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/HPO_MP.png)

A Concept (blue), Code (purple) and Term (green) from HPO on the left and its corresponding MP Concept, Code and Term on the right.

5. Starting with a human gene, find all (drug) compounds that affect expression of that gene in a LINCs dataset (binary relationship: upregulated or downregulated). The time/dosage/cell type variables in LINCS have been collapsed. In cases of conflicts (up or down) the data includes both up and down links. In the future we can include all data from LINCs.

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

6. Return all non-zero GTEx expression levels  for a specific tissue type, listed by top TPM (LIMIT 100)

```graphql
WITH 'aorta' AS tissuename
MATCH (ub_term:Term {name:tissuename})-[r0:PT]-(ub_code:Code {SAB:'UBERON'})-[r1:CODE]-(ub_cui:Concept)-[r2:tissue_has_median_expression]-(gtex_exp_cui:Concept)-[r3:CODE]-(gtex_exp_code:Code {SAB:'GTEX_EXP'})-[r4]-(gtex_term:Term) 
MATCH (gtex_exp_cui)-[r5:gene_has_median_expression]-(hgnc_cui:Concept)-[r6:PREF_TERM]-(hgnc_term:Term)
WHERE gtex_term.lowerbound > 0
RETURN  ub_term.name AS tissue, hgnc_term.name AS gene_symbol ,gtex_term.name AS TPM ORDER BY TPM DESCENDING limit 100
```

7. Return all significant (adj p val < .05 or lower) GTEx eQTLs for a specific tissue, listed by smallest pvalue (LIMIT 100). The eQTL data schema is shown as a result of the query.

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

![An UBERON Concept, Code and Term (top left), an HGNC Concept and preferred Term (top right) and GTEx eQTL Concept, Code and Terms (center). The GTEx Terms shown here represent a binned  p-value and variant ID for the eQTL](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/GTEx_eQTL.png)

An UBERON Concept, Code and Term (top left), an HGNC Concept and preferred Term (top right) and GTEx eQTL Concept, Code and Terms (center). The GTEx Terms shown here represent a binned  p-value and variant ID for the eQTL

8. The query below is exactly the same as the one above but returns additional fields related to the eQTLs

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

9. Return all HuBMAP clusters/samples that express a certain gene above a defined threshold. 

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

![From left to right (Concepts are orange): A tissue Concept (could be UBERON, FMA or SNOMED) , HuBMAP dataset Concept, HuBMAP cluster Concept (most datasets have between 10 and 20 clusters), HuBMAP expression Concept and a HGNC Concept.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/hubmap.png)

From left to right (Concepts are orange): A tissue Concept (could be UBERON, FMA or SNOMED) , HuBMAP dataset Concept, HuBMAP cluster Concept (most datasets have between 10 and 20 clusters), HuBMAP expression Concept and a HGNC Concept.

 10. Return HPO codes, phenotype names and number of phenotype for Kids First Patient

```graphql
MATCH (kfCode:Code {SAB:'KF'})-[r0:CODE]-(kfCUI:Concept)-[r1:patient_has_phenotype]-(hpoCUI:Concept)-[:CODE]-(hpoCode:Code {SAB:'HPO'})-[r2:PT]-(hpoTerm:Term)
WITH kfCode, collect(DISTINCT hpoTerm.name) AS hpo_terms, collect(DISTINCT hpoCode.CODE) AS hpo_codes 
RETURN kfCode.CODE AS KF_ID,
       size(hpo_terms) AS num_phenotypes,
			 hpo_codes, hpo_terms 
	     ORDER BY num_phenotypes 
			 DESCENDING LIMIT 100
```

### **Level II queries**

Level II queries contain information from 2 Common Fund datasets.

11. Given a subject ID in KF, find all the HPO terms for  that patient, and then find all genes associated with those HPO terms, then  find all cis-eQTLs related to those genes. Note that this query is not returning variants actually found within the subject, but rather potential locations to test for variants,  given the phenotypes associated with the subject.

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

12. Start with a compound in LINCs, find all human genes related to that compound and then all the tissues in GTEx with those genes TPM > a user-specified threshold.

```graphql
//Returns a table containing compund generic name correlated with genes with higher than threshold expression level in different tissues
WITH 'mosapride' AS COMPOUND_NAME, 5 AS MIN_EXP 
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ub_cui:Concept)-[:PREF_TERM]->(ub_term:Term),
(gtex_exp_cui:Concept)-[:CODE]->(gtex_exp_code:Code {SAB:'GTEX_EXP'})-[]->(gtex_term:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]-(hgncTerm:Term)
WHERE gtex_term.lowerbound > MIN_EXP 
RETURN DISTINCT ChEBITerm.name AS Compound, hgncTerm.name AS GENE, ub_term.name AS Tissue, gtex_term.lowerbound AS Expresseion_Level ORDER BY Expresseion_Level ASCENDING
```

13. Find intersection between MSigDB Hallmark pathways given a target LINCS compound through genes associated with those entities

```graphql
//Returns the graph linkage of MSigDB hallmark pathways associated with their signature genes regulated by a compound in LINCS L1000
WITH 'mosapride' AS COMPOUND_NAME
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[r2 {SAB:'MSigDB H'}]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term)
RETURN ChEBITerm,ChEBIconcept,hgncConcept,hgncCode,hgncTerm,msigdbConcept,msigdbTerm LIMIT 1
```

```graphql
//Returns a list of MSigDB hallmark pathways regulated by the given LINCS compound
WITH 'mosapride' AS COMPOUND_NAME
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[r2 {SAB:'MSigDB H'}]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term)
RETURN ChEBITerm.name AS Compound,msigdbTerm.name AS Pathway, hgncTerm.name AS Gene
```

![graph.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/graph.png)

14. Find all HuBMAP clusters expressing at least one gene related to a human phenotype (using OMIM)	
	
```graphql
WITH 'HP:0000023' AS hpo_code
MATCH (hpoTerm:Term)-[r0:PT]-(hpoCode:Code {SAB:'HPO'})-[r1:CODE]-(hpoCUI:Concept)-[r2:phenotype_associated_with_gene]->(hgncCUI:Concept)-[r3:gene_expression_of_hubmap_study]->(hubmap_cui:Concept)-[r5:hubmap_node_belongs_to_cluster]-(hmClusterCUI:Concept)-[r6:CODE]-(hmClusterCode:Code) 
WITH split(hmClusterCode.CODE,' ')[0] AS hubmap_study_id, split(hmClusterCode.CODE,' ')[1] AS cluster
RETURN hubmap_study_id,cluster limit 10	
```	
	

**Level III queries**

15. Starting with a given OMIM human phenotype, glycans will be extracted in association with Human genes

```graphql
//Returns a table (not a graphic view)
//Starting with a given OMIM human phenotype, glycans will be extracted in association with Human genes
MATCH (m:Code {CODE:'HP:0001631'})<-[:CODE]-(n:Concept)<-[r:isa*..1 {SAB:'HPO'}]-(o:Concept) WITH collect(n.CUI)+o.CUI AS T UNWIND T AS UT WITH collect(DISTINCT UT) AS PHS MATCH (q:Concept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]->(t:Concept)-[:has_product]->(u:Concept)-[:has_site]->(v:Concept)-[:binds_glycan]->(w:Concept),
(t)-[:CODE]->(:Code)-[:SYN]->(a:Term),
(u)-[:CODE]->(b:Code),(v)-[:PREF_TERM]->(c:Term),
(w)-[:CODE]->(d) WHERE q.CUI IN PHS 
RETURN DISTINCT a.name AS Gene, 
b.CODE AS UniProtKB_AC, 
c.name AS Glycosylation_Type_Site_ProteinID, 
d.CODE AS Glycan
```

![Untitled](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/Untitled.png)

16. Find all pathways in MSigDB linked to genes expressed in GTEx linked to human phenotypes. Returns HPO terms associated with genes and GTEx tissues MSigDB pathways associated with the genes

```graphql
//Returns HPO terms associated with genes and GTEx tissues MSigDB pathways associated with the genes
MATCH (ubCode:Code {SAB:'UBERON'})-[:CODE]-(ubConcept:Concept)-[]-(hpoConcept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]-(hgncConcept:Concept)-[r1]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ubConcept:Concept)-[:PREF_TERM]->(ubTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term),
(hpoCode:Code {SAB:'HPO'})<-[:CODE]-(hpoConcept)
WHERE r1.SAB CONTAINS 'MSigDB C2'
RETURN hgncConcept,hgncCode,hgncTerm,msigdbConcept,msigdbTerm,gtex_exp_cui,ubConcept,ubCode,ubTerm,hpoConcept,hpoCode LIMIT 1
```

![graph-5.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/graph-5.png)

**Graph theory-esque queries**

17. Shortest path between an HPO term and a gene and return everything on the path and the path length, with and without using MSigDB. 

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

![graph-4.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/graph-4.png)

Note “coexpressed_with” is based on GTEx (click on table result as SAB). Codes are orange, terms are Blue, and concept nodes are in purple.

18. Shortest path between an HPO term and all genes and return everything on the path and the path length

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
