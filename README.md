# CFDIKG

## Basic Schema
### HumanPhenotype--MousePhenotype--MouseGenes--HumanGenes
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_nodes.png)


###                          Unique Identifiers UMLS vs  UMLS+


------------------------------------------------------------------------------------------------
Node Type  | UI property |   UMLS ex.  |      UMLS+     |  NOTES                               |
| :---: | :---: | :---: | :---: | :---: | 
Concept    | CUI         | C1234567    | KC123456789000 | Prefix with 'K', 12 ints not 9       |
Code       | CodeID      | SAB 12345   | SAB 12345      | No change                            |
Term       | SUI         | S1234567    | KS123456789000 | Prefix with 'K', 12 ints not 7       |
Definition | ATUI        | AT123456789 | KAT123456789   | Prefix with 'K'                      |
Semantic   | TUI         | T123        |       N/A      |                                      |
NDC        |             |             |       N/A      |                                      |
------------------------------------------------------------------------------------------------





## Same image but with the nodes expanded
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_expanded.png)

# Showing more nodes
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_nodes5.png)

# Showing a whole cluster
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_nodes50.png)

# Showing multiple clusters
![alt text](https://github.com/TaylorResearchLab/CFDIKG/blob/master/images/umls_nodes500.png)
