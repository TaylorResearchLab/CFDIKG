
// Load IMPC triples/turtle or .owl files with neosemantics plugin 
// Data is From https://archive.monarchinitiative.org/202011/rdf/

CREATE CONSTRAINT n10s_unique_uri ON (r:Resource) ASSERT r.uri IS UNIQUE;
CALL n10s.graphconfig.init();
CALL n10s.onto.import.fetch("file:///Users/stearb/desktop/R03_local/data/impc.ttl",
                        "Turtle",{addResourceLabels : TRUE})
