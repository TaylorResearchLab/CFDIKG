
######################################################################
####### Queries to analyze the Monarch Neo4j graph database  #########
######################################################################

#### Get total number of nodes #######
match (n) return count(n)      # 14,599,603

### Get total number of relationships #####
match (n)-[r]-() return count(r)      #  62,766,987

### Get a list of the types of relationships ####
match ()-[r]-() return distinct r.edge_label limit 15

###### List ALL organisms in the database #########
match(n:`organism taxon`) return n.name as name order by n.name

######  See which organism has the most relationships #######
match(n:`organism taxon`)-[r]-()
return n.name,  count(r) order by count(r) desc

###### Return human/mouse node ###########
match(n:`organism taxon`) 
where n.name="Homo sapiens" or n.name="Mus musculus"
return n

####### Return 300 human Ontology ID
match(n:`organism taxon` {name:"Homo sapiens"})-[ont:`biolink:part_of`]-(o:`biolink:OntologyClass`)
return n.name as name, ont.edge_label, o.id as ontologyID limit 300

###### Find  number of (first level?) human ontologies
match(n:`organism taxon` {name:"Homo sapiens"})-[ont:`biolink:part_of`]-(o:`biolink:OntologyClass`) return count(o)         # 6529

#### Find the type of relationship linking organism to gene
match(n:`biolink:Gene`)-[r]-(t:`organism taxon` {name:"Homo sapiens"}) return type(r)       # "biolink:related_to"

#### Find all human genes ####
match (h:`organism taxon` {name:"Homo sapiens"})-[r:`biolink:related_to`]-(g:`biolink:Gene`) return count(g)  # 205 ? 

#### Return graph of human node connected to genes ####
match (h:`organism taxon` {name:"Homo sapiens"})-[r:`biolink:related_to`]-(g:`biolink:Gene`) return h,r,g

### Get total number of genes #######
match (n:`biolink:Gene`) return count(n)    # 1,718,787

###### get number of genes by organism ####
match (h:`organism taxon`)-[r:`biolink:related_to`]-(g:`biolink:Gene`)
return h.name as organism, count(g) as genes order by genes desc



