# .cypher or .cyp are the preferred file extensions for cypher files

### Deleting (and detaching) all nodes/relationships from a very large database  
# Must use apoc.periodic.iterate() instead of the regular query MATCH(n) DETACH DELETE n, to avoid JavaHeap Space error.
# https://stackoverflow.com/questions/51171928/difference-between-apoc-periodic-iterate-and-apoc-periodic-commit-when-deleting/51172771

CALL apoc.periodic.iterate(         
    "MATCH (n) RETURN n",
    "DETACH DELETE n",
    {batchSize:1000}
)
YIELD batches, total RETURN batches, total 




##### Loading human-mouse homologous Gene IDs and creating a :HOMOLOGOUS relation to and from both lists


:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 
"file:///homologous_genes.csv" AS row
 MERGE (h:Human_gene {gene_id: row.Human})
 MERGE (m:Mouse_gene {gene_id: row.Mouse})
 MERGE (h)-[:HOMOLOGOUS]->(m)
 MERGE (m)-[:HOMOLOGOUS_mouse]->(h)


### Use Neosemantics to stream in RDF file  
CALL n10s.rdf.stream.fetch("https://github.com/neo4j-labs/neosemantics/raw/3.5/docs/rdf/vw.owl","Turtle",{}) 
yield subject as s, predicate  as p, object as o
