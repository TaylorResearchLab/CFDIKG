#######  Statistics for our part (gene homologies,geno-pheno links and hp-mp mappings) of UMLS

-How many MP nodes do we have?
match (mp:Code {SAB: "MP"}) return count(mp)   # 1,291

-How many HP nodes do we have?
match (hp:Code {SAB: "HPO"}) return count(hp)  # 14,586

-How many Human gene nodes do we have?
match (hg:Code {SAB: "HGNC"}) return count(hg) # 41,679

-How many Mouse gene nodes do we have?
match (mg:Code {SAB: "HGNC HCOP"}) return count(mg) # 22,295


