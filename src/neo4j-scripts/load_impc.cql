
// Load IMPC triples/turtle or .owl files with neosemantics plugin 
// Data is From https://archive.monarchinitiative.org/202011/rdf/

// first 2 lines must be called before using the n10s plugin
CREATE CONSTRAINT n10s_unique_uri ON (r:Resource) ASSERT r.uri IS UNIQUE;
CALL n10s.graphconfig.init();
CALL n10s.onto.import.fetch("file:///Users/stearb/desktop/R03_local/data/impc.ttl",
                        "Turtle",{addResourceLabels : TRUE})
                            
// Must delete Resource node if you want to reimport RDF/Triples/Turtle data with neosemantics
MATCH (resource:Resource) DETACH DELETE resource;
