# September 2022 CFDE Demonstration

Deanne Taylor, Ben Stear, Taha Mohseni Ahooyi, Jonathan Silverstein

Access this page at https://tinyurl.com/CFDE-Sept2022-KF-HuBMAP 

## Integrating Common Fund Data for Discovery

Hello, my name is Deanne Taylor, and I'll be presenting on the CFDE collaboration between HuBMAP and Kids First.

Our goal in this project was to develop a Knowledge Graph to integrate CFDE datasets at the level of the data points. This would allow biomedical researchers to ask questions of this interconnected data,  by utilizing simple, complex and artificial intelligence queries and analyses. 

Jonathan Silvestein at the HuBMAP project developed an ontology (classification) graph based on the Unified Medical Language System (UMLS), and also included other ontology sources. This ontology graph is a collection of classification and annotation systems.  Myself and my group as part of the Kids First contribution, began adding Common Fund Data points into the annotation environment to create a knowledge graph system we call Petagraph.

Another goal is to eventually build a user interface (UI) to allow for exploration and queries on an integrated CFDE database, to be driven by a front-end web engine, so that users of any experience level will be able to use the interface.

![CFDE_Structure_Demo_Slide.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/CFDE_Structure_Demo_Slide.png)

Here's numbers representing some of the CFDE datasets in PetaGraph that help inform this demonstration:

![summary_table.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/summary_table.png)


## This project was only made possible with CFDE support!


## Introduction to PetaGraph, our experimental data-enriched version of the HuBMAP/UMLS database.

For this demonstration,  we'll be showing you the queries that will operate behind the UI.


PetaGraph's model operates on unified biomedical concepts.  There are multiple ways of classifying the same biomedical term, but in this model there is one central unifying concept per conceptual item, from multiple terminology systems. For example, a human gene concept from Gencode v37 can be represented by several IDs depending on the originating database, but they are all representing the same gene concept node.


### CFDE Queries on Petagraph

	
Question 1: There is evidence that heart defects could be related to changes in developmental programs due to dysregulation of glycosylation.  What glycans are predicted to be found on proteins (and where on the proteins) from genes associated with a Kids First patient with a phenotype such as Atrial Septal Defect?


```graphql
//Starting with HPO human phenotypes, glycans will be extracted in association with Human genes
MATCH (m:Code {CODE:'HP:0001631'})<-[:CODE]-(n:Concept)<-[r:isa*..1 {SAB:'HPO'}]-(o:Concept) WITH collect(n.CUI)+o.CUI AS T UNWIND T AS UT WITH collect(DISTINCT UT) AS PHS MATCH (q:Concept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]->(t:Concept)-[:has_product]->(u:Concept)-[:has_site]->(v:Concept)-[:binds_glycan]->(w:Concept),
(t)-[:CODE]->(r2:Code)-[:SYN]->(a:Term),
(u)-[:CODE]->(b:Code),(v)-[:PREF_TERM]->(c:Term),
(w)-[:CODE]->(d) WHERE q.CUI IN PHS 
RETURN * LIMIT 1
```
![Protein_Glycan2.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/Protein_Glycan2.png)

The glycan is attached to a O-link location on the protein, which is connected to the gene ID, and then to the HPO id.
In the figure above you can see the identity of the glycan on the far right, shown by selecting it in the interface here.
Or you can create a table and see all the results --


Table return of the above query.


```graphql
//Returns a table (not a graphic view)
//Starting with HPO human phenotypes, glycans will be extracted in association with Human genes
MATCH (m:Code {CODE:'HP:0001631'})<-[:CODE]-(n:Concept)<-[r:isa*..1 {SAB:'HPO'}]-(o:Concept) WITH collect(n.CUI)+o.CUI AS T UNWIND T AS UT WITH collect(DISTINCT UT) AS PHS MATCH (q:Concept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]->(t:Concept)-[:has_product]->(u:Concept)-[:has_site]->(v:Concept)-[:binds_glycan]->(w:Concept),
(t)-[:CODE]->(r2:Code)-[:SYN]->(a:Term),
(u)-[:CODE]->(b:Code),(v)-[:PREF_TERM]->(c:Term),
(w)-[:CODE]->(d) WHERE q.CUI IN PHS 
RETURN DISTINCT a.name AS Gene, 
b.CODE AS UniProtKB_AC, 
c.name AS Glycosylation_Type_Site_ProteinID, 
d.CODE AS Glycan
```

Question 2: Given a subject ID in KF, find all the HPO terms for  that patient, and then find all genes associated with those HPO terms, then  find all cis-eQTLs related to those genes. Note that this query is not returning variants within the subject genotype, but rather potential genomic locations to test for variants.

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

Question 3: Starting with a compound that affects gene expression from LINCs, find all affected genes in GTEx with those genes TPM > a user-specified threshold and return the tissues where those genes express.

```graphql
//Returns a table containing compund generic name correlated with genes with higher than threshold expression level in different tissues
WITH 'mosapride' AS COMPOUND_NAME, 5 AS MIN_EXP 
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ub_cui:Concept)-[:PREF_TERM]->(ub_term:Term),
(gtex_exp_cui:Concept)-[:CODE]->(gtex_exp_code:Code {SAB:'GTEX_EXP'})-[]->(gtex_term:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]-(hgncTerm:Term)
WHERE gtex_term.lowerbound > MIN_EXP 
RETURN DISTINCT ChEBITerm.name AS Compound, hgncTerm.name AS GENE, ub_term.name AS Tissue, gtex_term.lowerbound AS Expresseion_Level ORDER BY Expresseion_Level ASCENDING
```

## SUPPLEMENTAL INFO

**Main Project GitHub** (updating often)

[https://github.com/TaylorResearchLab/CFDIKG](https://github.com/TaylorResearchLab/CFDIKG)

If you'd like access to the database to recreate this demonstration, please contact Deanne Taylor and Jonathan Silverstein.

<A HREF="https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/Schema_CFDIKG_5-2022.md" target="new"> May 2022 Data Source Descriptions and Schema Reference</a> (right click to open in new window)

<A HREF="https://neo4j.com/developer/cypher/guide-cypher-basics/" target="new"> Getting started with Cypher (neo4j) </a> (right click to open in new window)

<A HREF="https://smart-api.info/ui/dea4bf91545a51b3dc415ba37e2a9e4e#/" target="new"> Python queries are based on the HuBMAP SMART API found here</A> (right click to open in new window)

<A HREF="https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Demonstration_June2022/PetaGeneSABs.csv", target="new"> SAB list in PetaGraph</A> 
 
 
 
