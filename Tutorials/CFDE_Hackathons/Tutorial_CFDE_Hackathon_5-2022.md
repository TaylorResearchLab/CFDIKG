# CFDE May 10th Hackathon

## Logistics

**Main Project GitHub** (updating often)

[https://github.com/TaylorResearchLab/CFDIKG](https://github.com/TaylorResearchLab/CFDIKG)

Login for **Neo4j Bolt Interface**:

[http://neo4j-hubkid.dev.hubmapconsortium.org:7474/browser](http://neo4j-hubkid.dev.hubmapconsortium.org:7474/browser)

Password to the Bolt interface will be distributed during tutorial session. If you want a user password to the Bolt interface after the tutorial is over, email taylordm at chop <dot> edu

**Jupyter Binder URL**:

[https://mybinder.org/v2/gh/nih-cfde/2022-may-kg-binder/stable](https://mybinder.org/v2/gh/nih-cfde/2022-may-kg-binder/stable)

## Introduction to the Graph

### SCHEMA REFERENCE

<A HREF="https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/Schema_CFDIKG_5-2022.md" target="new"> Data Source Descriptions and Schema Reference</a> (right click to open in new window)

### Introduction to Queries

All queries below will be done through the Bolt interface (linked up top) unless specifically noted to be in Python.

Select specific datasets by specifying the SAB (source abbreviation) property on the Code node. Here we match on a HPO Code node and its corresponding Concept node. 

Other SABs to try are: HGNC (human genes), HCOP (mouse genes), MP (mammalian phenotype), GTEX_EXP (GTEx expression data), GTEX_EQTL (GTEx eQTL data) 

 We can control how many ‘instances’ of the pattern are returned by using the LIMIT keyword. 

```graphql
MATCH (a:Concept)-[r:CODE]->(b:Code {SAB:"HPO"}) RETURN * LIMIT 5
```

Examples: 

Get the preferred term of a concept

MATCH (a:Concept{CUI:"C0001367"})-[:PREF_TERM]->(b:Term) RETURN *

General graph structure with Semantic Types

```graphql
//with semantic types
MATCH (a:Term)<--(b:Concept)
-->(c:Code)-[d:PT]->(a),
(f:Definition)<--(b)-->
(g:Semantic)-->(h:Semantic),
(b)-[i:isa]->(j:Concept)
WHERE b.CUI = d.CUI
AND c.SAB = i.SAB
RETURN * LIMIT 1
```

Recursive search in ontologies (here HPO), collect all HPO terms one level down from the parent Term (here HP:0001631, atrial septal defects), find all genes associated with these phenotypes and find whether or not these genes are Glycosyltransferases or Glycans or neither.

```graphql
WITH 'HP:0001631' AS parent_hpo
MATCH (co1:Code {CODE:parent_hpo})<-[:CODE]-(c1:Concept)-[a]-(c2:Concept)-[:CODE]->(P_code:Code {SAB:'MP'})
MATCH (P_code)<-[:CODE]-(P_concept:Concept)<-[:isa  *0..1 {SAB:'MP'}]-(C_concept:Concept)
WITH  collect(C_concept.CUI) + P_concept.CUI AS terms UNWIND terms AS uterms WITH collect(DISTINCT uterms) AS phenos
MATCH (mp_concept:Concept)-[r:CODE]->(mp_code:Code)
WHERE mp_concept.CUI in phenos
MATCH (mp_concept:Concept)-[s]->(hgnc_hcop_Concept:Concept)-[:has_mouse_ortholog]-(hgnc_concept:Concept)-[:CODE]-(human_gene:Code {SAB:'HGNC'}) 
WITH hgnc_concept,human_gene
MATCH (hgnc_concept)-[:PREF_TERM]->(gene_symbol:Term)
WITH DISTINCT human_gene,gene_symbol
OPTIONAL MATCH  (human_gene)-[q]-(gly:Term)
WHERE gly.name IN ['Glycosyltransferase','Glycan']
RETURN DISTINCT split(gene_symbol.name,' gene')[0] AS symbol,human_gene.CODE AS hgnc_id, gly.name AS protein_type
```

## Queries to try

### Level I **queries**

Level 1 queries only include (generally) one dataset.

1. Display the structure of the GTEx expression data.  Return 1 (LIMIT 1) GTEx CUI, and expression and tissue codes and Term (binned TPM).   This will display the  actual nodes, so its best to execute this query in the Bolt interface (the website GUI). If executed with cypher-shell (on the command line) or via the api, you’ll have several json objects returned. 

```graphql
MATCH (gtex_cui:Concept)-[r0:CODE]-(gtex_code:Code {SAB:'GTEX_EXP'})-[:TPM]-(gtex_term:Term)
MATCH (gtex_cui)-[r1]-(hgnc_concept:Concept)-[r2]-(hgnc_code:Code {SAB:'HGNC'})
MATCH (gtex_cui)-[r3]-(ub_concept:Concept)-[r4]-(ub_code:Code {SAB:'UBERON'}) 
RETURN * LIMIT 1
```

![GTEx_expression.png](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/GTEx_expression.png)

1. Given a HPO (phenotype) term, return all linked gene names by leveraging the HPO-to-gene links in Jax. #Need SAB to relationships

```graphql
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoTerm:Term)-[:PT]-(hpoCode:Code {CODE: HPO_CODE})-[r1:CODE]-(hpo_concept)-[r2]-(hgnc_concept:Concept)-[r3:CODE]-(hgnc_code:Code {SAB:'HGNC'})-[:PT]-(hgnc_term:Term) 
RETURN hgnc_code.CODE AS HGNC_ID, hgnc_term.name AS GENE_SYMBOL

```

Same query as above — but with the HuBMAP API to the same KG. Jupyter Notebook time!  If you’re of a Python mind, open up the Jupyter binder link above and paste in the following code block, or if you like you can do this locally on your own machine. If you’re doing this locally, ou’ll need to install the requests library noted in the import statement below.

```python
# Python
# For Jupyter Binder interface, Python accessing the Smart API at HuBMAP.
# Use the Codes-Concepts endpoint to return the HPO concept
# that corresponds to this HPO code
import requests

BASE_URL = 'https://ontology.api.hubmapconsortium.org/'
headers = {'Accept': 'application/json'}

response = requests.get(BASE_URL+'codes/HPO HP:0001631/concepts',headers=headers)
response_decoded = response.json()

print('\nServer response: ', response_decoded)  #print the response

# Grab the HPO concept
hpoCUI = response_decoded[0]['concept']

# Use the Concepts-Concepts endpoint to return all 
# Concepts that have a relationship with this HPO Concept
response = requests.get(BASE_URL+f'concepts/{hpoCUI}/concepts',headers=headers)
response_decoded = response.json() 

# Select the Concepts that have 'gene_associated_with_phenotype' Relationships. 
# This will give us just the HGNC Concepts
hgncCUI_list = [i['concept'] for i in response_decoded if i['relationship'] == 'gene_associated_with_phenotype']

print('\nFirst few HGNC Concept IDs: ',hgncCUI_list[:3])

# Loop through the list of HGNC Concept IDs and use the Concepts-Codes endpoint 
# to return each corresponding HGNC Code
codeIDs = []
for n in range(0,20): #limit by 20 to save us some hang time
    hgncCUI=hgncCUI_list[n]
    response = requests.get(BASE_URL+f'concepts/{hgncCUI}/codes',headers=headers)
    codeIDs.extend(response.json())
    
# Select just the CodeIDs that have the 'HGNC' prefix
hgnc_CodeIDs = [codeID for codeID in codeIDs if codeID.startswith('HGNC')]

print('First few HGNC CodeIDs:',hgnc_CodeIDs[:3])

# Finally, remove the 'HGNC ' prefix from the CodeIDs, we want just the HGNC Codes
hgnc_Codes = [codeID.replace('HGNC ','') for codeID in hgnc_CodeIDs]

print('\nFirst few HGNC Codes:', hgnc_Codes[:3])
print('\nTotal HGNC codes returned:',len(hgnc_Codes))
```

![A Concept (blue), Code (purple) and Term (green) node from HPO (left side) and HGNC (right side) and the bidirectional relationships between the two Concept nodes.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/HPO_HGNC.png)

A Concept (blue), Code (purple) and Term (green) node from HPO (left side) and HGNC (right side) and the bidirectional relationships between the two Concept nodes.

![Same as above but now showing multiple genes associated with the same HPO Code. ](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/HPO_HGNC_many_genes.png)

Same as above but now showing multiple genes associated with the same HPO Code. 

1. Given an HGNC (gene) name, give the mouse gene name from HCOP

```graphql
WITH 'BRCA1' as gene_name
MATCH (hgnc_term:Term {name:gene_name+' gene'})-[:MTH_ACR]-(hgnc_code:Code {SAB:'HGNC'})-[r1:CODE]-(hpo_concept)-[r2:has_human_ortholog]-(mouse_gene_concept:Concept)-[r3:CODE]-(mouse_gene_code:Code {SAB:'HGNC_HCOP'}) 
RETURN *
```

Same query as above — but Jupyter Notebook time!  If you’re of a Python mind, open up the Jupyter binder link above and paste in the following code block:

```python
#Python
import requests

BASE_URL = 'https://ontology.api.hubmapconsortium.org/'
headers = {'Accept': 'application/json'}

gene_name = 'BRCA1'

# Use the Terms-Codes endpoint to return the HPO concept
# that corresponds to this HPO code
response = requests.get(BASE_URL+f'/terms/{gene_name}/codes',headers=headers)
response_decoded = response.json()
print('\nServer response: ', response_decoded)

# grab just the HGNC code (it will have 'HGNC' as a prefix)
BRCA1_HGNC_CodeID = [codeID['code'] for codeID in response_decoded if codeID['code'].startswith('HGNC')][0]

print('BRCA1 HGNC ID =',BRCA1_HGNC_CodeID)

# Use the Codes-Concepts endpoint to return the HPO concept
# that corresponds to this HPO code
response = requests.get(BASE_URL+f'codes/{BRCA1_HGNC_CodeID}/concepts',headers=headers)
response_decoded = response.json()

# We are querying for a single concept here so no need to filter, we can just grab the concept diectly 
BRCA1_concept = response_decoded[0]['concept']

# Use the Concepts-Concepts endpoint to return all 
# Concepts that have a relationship with the BRCA1  Concept
response = requests.get(BASE_URL+f'concepts/{BRCA1_concept}/concepts',headers=headers)
response_decoded = response.json()

# Select the mouse ortholog Concept, it will be connected to the human
# BRCA1 concept by the 'has_human_ortholog' relationship
BRCA1_mouse_concept = [i['concept'] for i in response_decoded if  i['relationship'] == 'has_human_ortholog'][0]

response = requests.get(BASE_URL+f'concepts/{BRCA1_mouse_concept}/codes',headers=headers)
response_decoded = response.json()

# Lastly, remove the prefix from the mouse gene codeID
mouse_genes = [i.replace('HCOP HCOP:','') for i in response_decoded]
mouse_genes
```

![HGNC Concept (blue), Code (purple) and Term (green) from HGNC on the left and its corresponding Mouse gene Concept and code on the right  ](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/HGNC_HCOP.png)

HGNC Concept (blue), Code (purple) and Term (green) from HGNC on the left and its corresponding Mouse gene Concept and code on the right  

1. Given an HPO code, return the corresponding MP code if known

```graphql
WITH 'HP:0001631' AS HPO_CODE
MATCH (hpoTerm:Term)-[r0:PT]-(hpoCode:Code {CODE:HPO_CODE})-[r1:CODE]-(hpo_concept)-[r2:has_mouse_phenotype]-(mp_concept:Concept)-[r3:CODE]-(mp_code:Code {SAB:'MP'})-[r4:Term]-(mpTerm:Term)
RETURN *
```

Same query as above — but Jupyter Notebook time!  If you’re of a Python mind, open up the Jupyter binder link above and paste in the following code block:

```python
import requests

BASE_URL = 'https://ontology.api.hubmapconsortium.org/'
headers = {'Accept': 'application/json'}

hpo_search = 'HP:0001631'

hpo_code='HPO ' + hpo_search #SAB plus search term are needed in the query.

response = requests.get(BASE_URL+f'codes/{hpo_code}/concepts',headers=headers)
response_decoded = response.json()

hpo_concept_id = response_decoded[0]['concept']

# Use the Concepts-Concepts endpoint to return all 
# Concepts that have a relationship with this HPO Concept
response = requests.get(BASE_URL+f'concepts/{hpo_concept_id}/concepts',headers=headers)
response_decoded = response.json() 

# Filter the returned concepts by the 'has_human_phenotype' relationship. This is the 
# relationship that connects the HPO and MP concepts 
mp_concept = [i['concept'] for i in response_decoded if i['relationship'] == 'has_human_phenotype'][0]

response = requests.get(BASE_URL+f'concepts/{mp_concept}/codes',headers=headers)
response_decoded = response.json()

# Lastly, remove the prefix from the mouse gene codeID
mp_code = [i.replace('MP ','') for i in response_decoded]
print('MP Code: ', mp_code)
```

![A Concept (blue), Code (purple) and Term (green) from HPO on the left and its corresponding MP Concept, Code and Term on the right.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/HPO_MP.png)

A Concept (blue), Code (purple) and Term (green) from HPO on the left and its corresponding MP Concept, Code and Term on the right.

1. Starting with a human gene, find all (drug) compounds that affect expression of that gene in a LINCs dataset (binary relationship: upregulated or downregulated). The time/dosage/cell type variables in LINCS have been collapsed. In cases of conflicts (up or down) the data includes both up and down links. In the future we can include all data from LINCs.

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

1. Return all non-zero GTEx expression levels  for a specific tissue type, listed by top TPM (LIMIT 100)

```graphql
WITH 'aorta' AS tissuename
MATCH (ub_term:Term {name:tissuename})-[r0:PT]-(ub_code:Code {SAB:'UBERON'})-[r1:CODE]-(ub_cui:Concept)-[r2:tissue_has_median_expression]-(gtex_exp_cui:Concept)-[r3:CODE]-(gtex_exp_code:Code {SAB:'GTEX_EXP'})-[r4]-(gtex_term:Term) 
MATCH (gtex_exp_cui)-[r5:gene_has_median_expression]-(hgnc_cui:Concept)-[r6:PREF_TERM]-(hgnc_term:Term)
WHERE gtex_term.lowerbound > 0
RETURN  ub_term.name AS tissue, hgnc_term.name AS gene_symbol ,gtex_term.name AS TPM ORDER BY TPM DESCENDING limit 100
```

1. Return all significant (adj p val < .05 or lower) GTEx eQTLs for a specific tissue, listed by smallest pvalue (LIMIT 100). The eQTL data schema is shown as a result of the query.

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

![An UBERON Concept, Code and Term (top left), an HGNC Concept and preferred Term (top right) and GTEx eQTL Concept, Code and Terms (center). The GTEx Terms shown here represent a binned  p-value and variant ID for the eQTL](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/GTEx_eQTL.png)

An UBERON Concept, Code and Term (top left), an HGNC Concept and preferred Term (top right) and GTEx eQTL Concept, Code and Terms (center). The GTEx Terms shown here represent a binned  p-value and variant ID for the eQTL

1. The query below is exactly the same as the one above but returns additional fields related to the eQTLs

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

1. Return all HuBMAP clusters/samples that express a certain gene above a defined threshold. 

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

![From left to right (Concepts are orange): A tissue Concept (could be UBERON, FMA or SNOMED) , HuBMAP dataset Concept, HuBMAP cluster Concept (most datasets have between 10 and 20 clusters), HuBMAP expression Concept and a HGNC Concept.](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/hubmap.png)

From left to right (Concepts are orange): A tissue Concept (could be UBERON, FMA or SNOMED) , HuBMAP dataset Concept, HuBMAP cluster Concept (most datasets have between 10 and 20 clusters), HuBMAP expression Concept and a HGNC Concept.

 10. Return HPO codes, phenotype names and number of phenotype for Kids First Patient

```graphql
WITH 'PT_ZB5SBXFK' AS KF_ID
MATCH (kfCode:Code {SAB:'KF',CODE: KF_ID})-[r0:CODE]-(kfCUI:Concept)-[r1:patient_has_phenotype]-(hpoCUI:Concept)-[r2:phenotype_associated_with_gene]-(hgncCUI:Concept)-[r3:gene_has_eqtl]-(gtexEqtlCUI:Concept)-[r4:CODE]-(gtexEqtlCode:Code)
MATCH (hpoCUI)-[r5:CODE]-(hpoCode {SAB:'HPO'})
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
 eqtl_pval.name AS pvalue ORDER BY pvalue ASCENDING
```

### **Level II queries**

Level II queries contain information from 2 Common Fund datasets.

1. Given a subject ID in KF, find all the HPO terms for  that patient, and then find all genes associated with those HPO terms, then  find all cis-eQTLs related to those genes. Note that this query is not returning variants actually found within the subject, but rather potential locations to test for variants,  given the phenotypes associated with the subject.

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

1. Start with a compound in LINCs, find all human genes related to that compound and then all the tissues in GTEx with those genes TPM > a user-specified threshold.

```graphql
//Returns a table containing compund generic name correlated with genes with higher than threshold expression level in different tissues
WITH 'mosapride' AS COMPOUND_NAME, 5 AS MIN_EXP 
MATCH (ChEBITerm:Term {name:COMPOUND_NAME})<-[]-(ChEBICode:Code {SAB:'CHEBI'})<-[:CODE]-(ChEBIconcept:Concept)-[r1 {SAB:'LINCS L1000'}]->(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ub_cui:Concept)-[:PREF_TERM]->(ub_term:Term),
(gtex_exp_cui:Concept)-[:CODE]->(gtex_exp_code:Code {SAB:'GTEX_EXP'})-[]->(gtex_term:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]-(hgncTerm:Term)
WHERE gtex_term.lowerbound > MIN_EXP 
RETURN DISTINCT ChEBITerm.name AS Compound, hgncTerm.name AS GENE, ub_term.name AS Tissue, gtex_term.lowerbound AS Expresseion_Level ORDER BY Expresseion_Level ASCENDING
```

1. Find intersection between MSigDB Hallmark pathways given a target LINCS compound through genes associated with those entities

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

![graph.svg](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/graph.svg)

1. Find all HuBMAP clusters expressing more than one genes related to a human phenotype (using OMIM)

```graphql
WITH 'HP:0000023' AS hpo_code, 0 as gene_exp_threshold, .75 AS overlap_perc
MATCH (hpoTerm:Term)-[r0:PT]-(hpoCode:Code {CODE:hpo_code})-[r1:CODE]-(hpoCUI:Concept)-[r2:phenotype_associated_with_gene]-(hgncCUI:Concept)-[r3:PREF_TERM]-(hgncTerm:Term) 
WITH collect(hgncCUI.CUI) AS gene_CUIs, gene_exp_threshold,overlap_perc
MATCH (HM_hgncCUI:Concept)-[r4:gene_expression_of_hubmap_study]-(hubmapCUI:Concept)-[r5:CODE]-(hubmapCode:Code {SAB:'HUBMAPsc'})-[r6:CODE]-(hubmapTerm:Term) 
WHERE hubmapTerm.lowerbound > gene_exp_threshold
WITH gene_CUIs, collect(HM_hgncCUI.CUI) AS hm_gene_CUIs, gene_exp_threshold
WITH [x IN hm_gene_CUIs WHERE x IN gene_CUIs] AS overlap
RETURN overlap

WITH 'HP:0000023' AS hpo_code, 0.3 as gene_exp_threshold, .75 AS overlap_perc
MATCH (hpoTerm:Term)-[r0:PT]-(hpoCode:Code {CODE:hpo_code})-[r1:CODE]-(hpoCUI:Concept)-[r2:phenotype_associated_with_gene]-(hgncCUI:Concept)-[r3:PREF_TERM]-(hgncTerm:Term) 
WITH  hgncTerm, collect(hgncCUI.CUI) AS hpo_hgnc_cuis,hgncCUI, gene_exp_threshold
MATCH (hgncCUI)-[r4:gene_expression_of_hubmap_study]-(hubmapCUI:Concept)-[r5:CODE]-(hubmapCode:Code {SAB:'HUBMAPsc'})-[r6]-(hubmapTerm:Term) 
WHERE hubmapTerm.lowerbound > gene_exp_threshold
WITH collect( DISTINCT hgncCUI) AS hm_hgnc_cuis,hpo_hgnc_cuis,  gene_exp_threshold
RETURN size(hpo_hgnc_cuis),size(hm_hgnc_cuis)
```

```graphql
// return all genes that are related to the hpo term 
// AND are expressed higher than thresh. just need to return study/dataset id
// and cluster
WITH 'HP:0000023' AS hpo_code, 0.3 as gene_exp_threshold, .75 AS overlap_perc
MATCH (hpoTerm:Term)-[r0:PT]-(hpoCode:Code {CODE:hpo_code})-[r1:CODE]-(hpoCUI:Concept)-[r2:phenotype_associated_with_gene]-(hgncCUI:Concept)-[r3:PREF_TERM]-(hgncTerm:Term) 
MATCH (hgncCUI)-[r4:gene_expression_of_hubmap_study]-(hubmapCUI:Concept)-[r5:CODE]-(hubmapCode:Code {SAB:'HUBMAPsc'})-[r6]-(hubmapTerm:Term) 
WHERE hubmapTerm.lowerbound > gene_exp_threshold
WITH  DISTINCT hgncCUI AS hm_hgnc_cuis
RETURN  hm_hgnc_cuis.CUI
```

**Level III queries**

1. Starting with a given OMIM human phenotype, glycans will be extracted in association with Human genes

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

![Untitled](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/Untitled.png)

1. Find all pathways in MSigDB linked to genes expressed in GTEx linked to human phenotypes. Returns HPO terms associated with genes and GTEx tissues MSigDB pathways associated with the genes

```graphql
//Returns HPO terms associated with genes and GTEx tissues MSigDB pathways associated with the genes
MATCH (ubCode:Code {SAB:'UBERON'})-[:CODE]-(ubConcept:Concept)-[]-(hpoConcept)-[:phenotype_associated_with_gene {SAB:'HGNC__HPO'}]-(hgncConcept:Concept)-[r1]->(msigdbConcept:Concept)-[:PREF_TERM]->(msigdbTerm:Term),
(hgncConcept:Concept)-[:gene_has_median_expression]-(gtex_exp_cui:Concept)-[:tissue_has_median_expression]-(ubConcept:Concept)-[:PREF_TERM]->(ubTerm:Term),
(hgncConcept:Concept)-[:CODE]->(hgncCode:Code {SAB:'HGNC'})-[:SYN]->(hgncTerm:Term),
(hpoCode:Code {SAB:'HPO'})<-[:CODE]-(hpoConcept)
WHERE r1.SAB CONTAINS 'MSigDB C2'
RETURN hgncConcept,hgncCode,hgncTerm,msigdbConcept,msigdbTerm,gtex_exp_cui,ubConcept,ubCode,ubTerm,hpoConcept,hpoCode LIMIT 1
```

![graph-5.svg](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/graph-5.svg)

**Graph theory-esque queries**

1. Shortest path between an HPO term and a gene and return everything on the path and the path length, with and without using MSigDB. 

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

![graph-4.svg](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/graph-4.svg)

Note “coexpressed_with” is based on GTEx (click on table result as SAB). Codes are orange, terms are Blue, and concept nodes are in purple.

1. Shortest path between an HPO term and all genes and return everything on the path and the path length

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

![graph.svg](https://github.com/TaylorResearchLab/CFDIKG/blob/master/Tutorials/CFDE_Hackathons/images/graph%201.svg)

Shows every gene (as Term nodes in blue) related to the HPO term (as Code node in orange), and finds the shortest paths (by Concept nodes — in purple)
