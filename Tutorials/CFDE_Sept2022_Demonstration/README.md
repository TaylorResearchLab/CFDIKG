# September 2022 CFDE Demonstration

Deanne Taylor, Ben Stear, Taha Moheseni Ahooyi, Jonathan Silverstein

## Integrating Common Fund Data for Discovery

For this tutorial/demonstration we'll be using a knowledge graph we're calling "PetaGraph."
It was developed as a collaboration between HuBMAP's Jonathan Silverstein and Deanne Taylor's group as part of Kids First.

The goal is to allow the actual data within CFDE to interoperate within a connected Knowledge Graph, so that plots, queries, and algorithms can be designed against it for biomedical reserach purposes.

PetaGraph is populated with the HuBMAP UMLS ontology graph, and the Taylor group integrated several sources of CFDE data into the ontology graph. 

![CFDE_Structure_Demo_Slide.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/CFDE_Structure_Demo_Slide.png)



Here's numbers representing some of the CFDE datasets in PetaGraph that help inform this demonstration:

![summary_table.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/tutorial_images/summary_table.png)



## Introduction to PetaGraph, our experimental data-enriched version of the HuBMAP/UMLS database.

Our goal is to eventually build a user interface (UI) to allow for queries on an integrated CFDE database, to be driven by a front-end web engine, so that users of any experience level will be able to use the interface.

For this demonstration,  we'll be showing you the queries that will operate behind the UI.

**This project was only made possible with CFDE support.**

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

Question 2: I'm interested in finding relationships betwen human phenotypes and gene pathways/genesets. Which human phenotypes are associated with MSigDB genesets/pathways, using gene-tissue expression information in GTEx?

Find all pathways in MSigDB linked to genes expressed in GTEx tissues that are known to be linked to human phenotypes.

Returns HPO terms associated with tissue-specific GTEx genes within MSigDB pathways.

For the graphic, we "LIMIT 1". Table format query below will return many more.

```graphql
//Returns HPO terms associated with genes and GTEx tissues MSigDB pathways associated with the genes
MATCH (ubCode:Code {SAB:'UBERON'})-[:CODE]-(ubConcept:Concept)-[]-(hpoConcept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]-(hgncConcept:Concept)-[r1]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ubConcept:Concept)-[:PREF_TERM]->(ubTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term),
(hpoCode:Code {SAB:'HPO'})<-[:CODE]-(hpoConcept)
WHERE r1.SAB CONTAINS 'MSigDB C2'
RETURN * LIMIT 1
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

Question 3. I hypothesize that HNRNPH2, a heterogeneous nuclear ribonucleoprotein that regulates RNA processing, may have some relationship to heart development that may affect subject phenotypes in Kids First. How are human phenotypes in Kids First related to HNRNPH2 in the knowledge graph?

We start with Atrial Septal Defects in Kids First data. We would be able to iterate through every Kids First phenotype.

Return the shortest path between an HPO term and a gene and return everything on the path and the path length, with and without using MSigDB. 
Shortest paths aren't always the best paths, and there are queries that can be done ordering all paths by size, for example.

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



## SUPPLEMENTAL INFO

**Main Project GitHub** (updating often)

[https://github.com/TaylorResearchLab/CFDIKG](https://github.com/TaylorResearchLab/CFDIKG)

If you'd like access to the database to recreate this demonstration, please contact Deanne Taylor and Jonathan Silverstein.

<A HREF="https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/Schema_CFDIKG_5-2022.md" target="new"> May 2022 Data Source Descriptions and Schema Reference</a> (right click to open in new window)

<A HREF="https://neo4j.com/developer/cypher/guide-cypher-basics/" target="new"> Getting started with Cypher (neo4j) </a> (right click to open in new window)

<A HREF="https://smart-api.info/ui/dea4bf91545a51b3dc415ba37e2a9e4e#/" target="new"> Python queries are based on the HuBMAP SMART API found here</A> (right click to open in new window)

<A HREF="https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Demonstration_June2022/PetaGeneSABs.csv", target="new"> SAB list in PetaGraph</A> 
 
 
 
