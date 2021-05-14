# CFDIKG
This is a "Common Fund" enabled knowledge graph built on a UMLS knowledge graph developed by Jonathan Silverstein.

Supported by NIH R03 award 1R03OD030600-01, PIs: Deanne Taylor and Ryan Urbanowicz.

As of May 2021 the code will be sparse as we continue to update the repository. Please watch this repo as we expand and include more useful data and information.



## Basic Schema
### HumanPhenotype--MousePhenotype--MouseGenes--HumanGenes
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_nodes.png)


###    Unique Identifiers UMLS vs  UMLS+
------------------------------------------------------------------------------------------------
Node Type  | UI property |   UMLS example  |      UMLS+ example    |  NOTES                    |
| :---: | :---: | :---: | :---: | :---: | 
Concept    | CUI         | C1234567    | KC123456789000 | Prefix with 'K', 12 ints not 9       |
Code       | CodeID      | SAB 12345   | SAB 12345      | No change                            |
Term       | SUI         | S1234567    | KS123456789000 | Prefix with 'K', 12 ints not 7       |
Definition | ATUI        | AT123456789 | KAT123456789   | Prefix with 'K'                      |
Semantic   | TUI         | T123        |       N/A      |                                      |
NDC        | NDC         | 12345678900 |       N/A      |                                      |
------------------------------------------------------------------------------------------------






## Same image but with the nodes expanded
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_expanded.png)

# Showing more nodes
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_nodes5.png)

# Showing a whole cluster
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_nodes50.png)

# Showing multiple clusters
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_nodes500.png)
