
####################################################################################
####### Examples using algorithms from Neo4j's 'Graph Data Science library' #########
#####################################################################################

You can get it by clicking on install plug-ins in the NEO4j desktop. If you're not 
using NEO4j desktop you can download the graph data science library from neo4j.com/download-center.

------
SYNTAX
------

CALL gds[.<tier>.].<algorithm>.<execution-mode>[.<estimate>](
  graphName: STRING,
  configuration: MAP    )
  
  <tier> - tier of support, Ex. product/beta/Alpha  (product algs are the top-tier and most optimized by neo4j. If you were using a 
                                            product-tier algorithm just leave this parameter blank. Call sig:  CALL gds.beta...)
  <algorithm> - name of algorithm to execute, Ex. 'pagerank' 
  <execution-mode> - how to run the alg.: write/stream/stats  (stream will return the results  without altering the graph, 
                                                                write will alter the graph and stats will give stats about algorithm results.)
  <estimate> - estimate the memory requirements of the alg.

