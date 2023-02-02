#!/usr/bin/env python
# coding: utf-8

# # OWLNETS-UMLS-GRAPH

# In[1]:


import sys
import pandas as pd
import dask.dataframe as dd
import numpy as np
import base64
from collections import Counter
import json
import os
import time
import uuid

'''
def csv_path(file: str) -> str:
    return os.path.join('/home/stearb/data/new_umls_csvs', file)

def owlnets_path(file: str) -> str:
    return os.path.join('/home/stearb/data/graph_datasets/gtex/gtex_exp', file)

def new_csv_path(file: str) -> str:
    return os.path.join('/home/stearb/data/new_umls_csvs', file)

OWL_SAB = 'GTEX_EXP'
'''

def owlnets_path(file: str) -> str: 
    return os.path.join(sys.argv[1], file)
def csv_path(file: str) -> str: 
    return os.path.join(sys.argv[2], file)

OWL_SAB = sys.argv[3].upper()


# In[3]:


#%%time
### Ingest OWLNETS output files, remove NaN and duplicate (keys) if they were to exist
print('Reading OWLNETS files for ontology...')
node_metadata = pd.read_csv(owlnets_path("OWLNETS_node_metadata.txt"), sep='\t',usecols=['node_id','node_namespace','node_label','node_definition','node_synonyms','node_dbxrefs'])
node_metadata = node_metadata.replace({'None': np.nan})
node_metadata = node_metadata.dropna(subset=['node_id']).drop_duplicates(subset='node_id').reset_index(drop=True)

relations_file_exists = os.path.exists(owlnets_path('OWLNETS_relations.txt'))

if relations_file_exists:
    print('Obtaining relations data from relations metadata file.')
    relations = pd.read_csv(owlnets_path("OWLNETS_relations.txt"), sep='\t')
    relations = relations.replace({'None': np.nan})
    relations = relations.dropna(subset=['relation_id']).drop_duplicates(subset='relation_id').reset_index(drop=True)
    # handle relations with no label by inserting part after # - may warrant more robust solution or a hard stop
    relations.loc[relations['relation_label'].isnull(), 'relation_label'] = relations['relation_id'].str.split('#').str[
        -1]
else:
    print('No relations metadata found, so obtaining relations data from edgelist file.')
    
edgelist = pd.read_csv(owlnets_path("OWLNETS_edgelist.txt"), sep='\t')
edgelist = edgelist.replace({'None': np.nan})
edgelist = edgelist.dropna().drop_duplicates().reset_index(drop=True)
edgelist = edgelist[edgelist['subject'] != edgelist['object']].reset_index(drop=True)



edgecount = len(edgelist.index)
nodecount = len(node_metadata.index)

print('Number of edges in edgelist.txt:', edgecount)
print('Number of nodes in node_metadata.txt', nodecount)

if edgecount > 500000 or nodecount > 500000:
    print('WARNING: Large OWLNETS files may cause the script to terminate from memory issues.')


def codeReplacements(x,underscore_replace):
    
    # Convert the code string to the CodeID format.
    # This is sufficient for all cases except EDAM, for which underscores will be restored.
    ret = x.str.replace('#', ' ').str.split('/').str[-1]
    
    if underscore_replace:
        ret = ret.str.replace('_', ' ').str.replace(':', ' ')
        
    ret = ret.str.replace('NCIT ', 'NCI ', regex=False)
    ret = ret.str.replace('MESH ', 'MSH ', regex=False)
    ret = ret.str.replace('GO ', 'GO GO:', regex=False)
    ret = ret.str.replace('NCBITaxon ', 'NCBI ', regex=False)
    ret = ret.str.replace('.*UMLS.*\s', 'UMLS ', regex=True)
    ret = ret.str.replace('.*SNOMED.*\s', 'SNOMEDCT_US ', regex=True)
    ret = ret.str.replace('HP ', 'HPO HP:', regex=False)
    ret = ret.str.replace('^fma', 'FMA ', regex=True)
    ret = ret.str.replace('Hugo.owl HGNC ', 'HGNC ', regex=False)
    ret = ret.str.replace('HGNC ', 'HGNC HGNC:', regex=False)
    ret = ret.str.replace('gene symbol report?hgnc id=', 'HGNC HGNC:', regex=False)
    ret = np.where((OWL_SAB == 'MONDO' and x.str.contains('http://identifiers.org/hgnc')),
                   'HGNC HGNC:' + x.str.split('/').str[-1], ret)
    ret = np.where((x.str.contains('EDAM')), x.str.split(':').str[-1], ret)
    ret = np.where((x.str.contains('edam')), 'EDAM ' + x.str.replace(' ', '_').str.split('/').str[-1], ret)
    ret = np.where(x.str.contains('HGNC HGNC:'), x, ret)
    return ret


print('Establishing edges and inverse edges...')

if relations_file_exists:
    edgelist = edgelist.merge(relations, how='left', left_on='predicate', right_on='relation_id')
    edgelist = edgelist[['subject', 'predicate', 'object', 'relation_label']].rename(
        columns={"relation_label": "relation_label_from_file"})
else:
    edgelist['relation_label_from_file'] = np.NaN
    
    
if OWL_SAB in ['GTEX_COEXP','LINCS','MSIGDB','CMAP','CLINVAR','HUBMAPSC','SCHEART_PMID_31835037','HGNC_HPO',
            'HPO_MP','HCOP','MP','HCOP_MP','HGNC_ANNOS','GTEX_EXP','GTEX_EQTL','KF']:
    underscore_replace = False
    print('underscore_replace = False')
else:
    underscore_replace = True
    print('underscore_replace = True')
    
edgelist['subject'] = codeReplacements(edgelist['subject'],underscore_replace)
edgelist['object'] = codeReplacements(edgelist['object'],underscore_replace)

#underscore_replace = True

dfro = pd.read_json("https://raw.githubusercontent.com/oborel/obo-relations/master/ro.json")
# Information on relationship properties (i.e., relationship property nodes) is in the node array.
dfnodes = pd.DataFrame(dfro.graphs[0]['nodes'])
# Information on edges (i.e., relationships between relationship properties) is in the edges array.
dfedges = pd.DataFrame(dfro.graphs[0]['edges'])


# In[4]:


#%%time

dfrelationtriples = dfnodes.merge(dfedges, how='inner', left_on='id', right_on='sub')
# Get object node
dfrelationtriples = dfrelationtriples.merge(dfnodes, how='inner', left_on='obj', right_on='id')

# Identify relationship properties that do not have inverses.<br>
# 1. Group relationship properties by predicate, using count.<br>
#   ('pred' here describes the relationship between relationship properties.)

dfpred = dfrelationtriples.groupby(['id_x', 'pred']).count().reset_index()

# 2. Identify the relationships for which the set of predicates does not include "inverseOf".

listinv = dfpred[dfpred['pred'] == 'inverseOf']['id_x'].to_list()
listnoinv = dfpred[~dfpred['id_x'].isin(listinv)]['id_x'].to_list()
dfnoinv = dfrelationtriples.copy()
dfnoinv = dfnoinv[dfnoinv['id_x'].isin(listnoinv)]

# 3. Rename column names to match the relationtriples frame. (Column names are described farther down.)
dfnoinv = dfnoinv[['id_x', 'lbl_x', 'id_y', 'lbl_y']].rename(
    columns={'id_x': 'IRI', 'lbl_x': 'relation_label_RO', 'id_y': 'inverse_IRI', 'lbl_y': 'inverse_RO'})
# The inverses are undefined.
dfnoinv['inverse_IRI'] = np.nan
dfnoinv['inverse_RO'] = np.nan

# Look for members of incomplete inverse pairs--i.e., relationship properties that are<br>
# the *object* of an inverseOf edge, but not the corresponding *subject* of an inverseOf edge.<br>

# 1. Filter edges to inverseOf.
dfedgeinv = dfedges[dfedges['pred'] == 'inverseOf']

# 2. Find all relation properties that are objects of inverseOf edges.
dfnoinv = dfnoinv.merge(dfedgeinv, how='left', left_on='IRI', right_on='obj')

# 3. Get the label for the relation properties that are subjects of inverseOf edges.
dfnoinv = dfnoinv.merge(dfnodes, how='left', left_on='sub', right_on='id')
dfnoinv['inverse_IRI'] = np.where(dfnoinv['lbl'].isnull(), dfnoinv['inverse_IRI'], dfnoinv['id'])
dfnoinv['inverse_RO'] = np.where(dfnoinv['lbl'].isnull(), dfnoinv['inverse_RO'], dfnoinv['lbl'])
dfnoinv = dfnoinv[['IRI', 'relation_label_RO', 'inverse_IRI', 'inverse_RO']]

# Filter the base triples frame to just those relationship properties that have inverses.<br>
# This step eliminates relationship properties related by relationships such as "subPropertyOf".
dfrelationtriples = dfrelationtriples[dfrelationtriples['pred'] == 'inverseOf']

# Rename column names.Column names will be:<br>
# IRI - the IRI for the relationship property, relation_label_RO - the label for the relationship property<br>
# inverse_RO - the label of the inverse relationship property<br>
# inverse_IRI - IRI for the inverse relationship (This will be dropped.)
dfrelationtriples = dfrelationtriples[['id_x', 'lbl_x', 'id_y', 'lbl_y']].rename(
    columns={'id_x': 'IRI', 'lbl_x': 'relation_label_RO', 'id_y': 'inverse_IRI', 'lbl_y': 'inverse_RO'})

# Add triples for problematic relationship properties--i.e., without inverses or from incomplete pairs.
dfrelationtriples = pd.concat([dfrelationtriples, dfnoinv], ignore_index=True).drop_duplicates(subset=['IRI'])

# Convert stings for labels for relationships to expected delimiting.
dfrelationtriples['relation_label_RO'] =     dfrelationtriples['relation_label_RO'].str.replace(' ', '_').str.split('/').str[-1]
dfrelationtriples['inverse_RO'] = dfrelationtriples['inverse_RO'].str.replace(' ', '_').str.split('/').str[-1]

dfrelationtriples = dfrelationtriples.drop(columns='inverse_IRI')


# In[ ]:





# In[5]:


#%%time
edgelist = edgelist.merge(dfrelationtriples, how='left', left_on='predicate',
                          right_on='IRI').drop_duplicates().reset_index(drop=True)
edgelist = edgelist[
    ['subject', 'predicate', 'object', 'relation_label_from_file', 'relation_label_RO', 'inverse_RO']].rename(
    columns={'relation_label_RO': 'relation_label_RO_fromIRIjoin', 'inverse_RO': 'inverse_RO_fromIRIjoin'})

edgelist['predicate'] = edgelist['predicate'].str.replace(' ', '_').str.replace('#', '/').str.split('/').str[-1]
edgelist = edgelist.merge(dfrelationtriples, how='left', left_on='predicate',
                          right_on='relation_label_RO').drop_duplicates().reset_index(drop=True)
edgelist = edgelist[['subject', 'predicate', 'object', 'relation_label_from_file', 'relation_label_RO_fromIRIjoin',
                     'inverse_RO_fromIRIjoin', 'relation_label_RO', 'inverse_RO']].rename(
    columns={'relation_label_RO': 'relation_label_RO_frompredicatejoinlabel',
             'inverse_RO': 'inverse_RO_frompredicatejoinlabel'})

if relations_file_exists:
    edgelist['relation_label_from_file'] =     edgelist['relation_label_from_file'].str.replace(' ', '_').str.replace('#', '/').str.split('/').str[-1]
    edgelist = edgelist.merge(dfrelationtriples, how='left', left_on='relation_label_from_file',
                              right_on='relation_label_RO').drop_duplicates().reset_index(drop=True)
    edgelist = edgelist[['subject', 'predicate', 'object', 'relation_label_from_file', 'relation_label_RO_fromIRIjoin',
                         'inverse_RO_fromIRIjoin', 'relation_label_RO_frompredicatejoinlabel',
                         'inverse_RO_frompredicatejoinlabel', 'relation_label_RO', 'inverse_RO']].rename(
        columns={'relation_label_RO': 'relation_label_RO_fromfilelabeljoinlabel',
                 'inverse_RO': 'inverse_RO_fromfilelabeljoinlabel'})



edgelist['relation_label'] = edgelist['relation_label_RO_fromIRIjoin']
edgelist['relation_label'] = np.where(edgelist['relation_label'].isnull(),edgelist['relation_label_RO_frompredicatejoinlabel'],edgelist['relation_label'])
if relations_file_exists:
    edgelist['relation_label'] = np.where(edgelist['relation_label'].isnull(),edgelist['relation_label_RO_fromfilelabeljoinlabel'],edgelist['relation_label'])
    edgelist['relation_label'] = np.where(edgelist['relation_label'].isnull(),edgelist['relation_label_from_file'],edgelist['relation_label'])
edgelist['relation_label'] = np.where(edgelist['relation_label'].isnull(),edgelist['predicate'],edgelist['relation_label'])
edgelist['relation_label'] = np.where(edgelist['predicate'].str.contains('subClassOf'),'isa', edgelist['relation_label'])

# The algorithm for inverses is simpler: if one was derived from RO, use it; else leave empty, and<br>
# the script will create a pseudo-inverse.

edgelist['inverse'] = edgelist['inverse_RO_fromIRIjoin']
edgelist['inverse'] = np.where(edgelist['inverse'].isnull(), edgelist['inverse_RO_frompredicatejoinlabel'],
                               edgelist['inverse'])
if relations_file_exists:
    edgelist['inverse'] = np.where(edgelist['inverse'].isnull(), edgelist['inverse_RO_fromfilelabeljoinlabel'],
                                   edgelist['inverse'])
    
#### Add unknown inverse_ edges (i.e., pseudo-inverses)
edgelist.loc[edgelist['inverse'].isnull(), 'inverse'] = 'inverse_' + edgelist['relation_label']


# In[ ]:





# In[7]:


#%%time
print('Cleaning up node metadata...')

    #node_metadata['node_id'].str.replace(':', ' ').str.replace('#', ' ').str.replace('_', ' ').str.split('/').str[-1]
if OWL_SAB not in ['LINCS','MSIGDB','CMAP','CLINVAR','HUBMAPSC','SCHEART_PMID_31835037','HGNC_HPO',
                'HPO_MP','GTEX_COEXP','HCOP','MP','HCOP_MP','HGNC_ANNOS','GTEX_EXP','GTEX_EQTL','KF']:
    node_metadata['node_id'] = codeReplacements(node_metadata['node_id'],underscore_replace)
    
node_metadata.loc[node_metadata['node_synonyms'].notna(), 'node_synonyms'] =     node_metadata[node_metadata['node_synonyms'].notna()]['node_synonyms'].astype('str').str.split('|')

node_metadata.loc[node_metadata['node_dbxrefs'].notna(), 'node_dbxrefs'] =     node_metadata[node_metadata['node_dbxrefs'].notna()]['node_dbxrefs'].astype('str').str.upper().str.replace(':', ' ')
node_metadata['node_dbxrefs'] = node_metadata['node_dbxrefs'].str.split('|')
explode_dbxrefs = node_metadata.explode('node_dbxrefs')[['node_id', 'node_dbxrefs']].dropna().astype(
    str).drop_duplicates().reset_index(drop=True)
explode_dbxrefs['node_dbxrefs'] = codeReplacements(explode_dbxrefs['node_dbxrefs'],underscore_replace)

# Add SAB and CODE columns
node_metadata['SAB'] = node_metadata['node_id'].str.split(' ').str[0]
node_metadata['CODE'] = node_metadata['node_id'].str.split(' ').str[-1]
del node_metadata['node_namespace']
# del explode_dbxrefs - not deleted here because we need it later


### Get the UMLS CUIs for each node_id as nodeCUIs
print('ASSIGNING CUIs TO NODES, including for nodes that are cross-references...')
explode_dbxrefs['nodeXrefCodes'] = explode_dbxrefs['node_dbxrefs'].str.split(' ').str[-1]

explode_dbxrefs_UMLS =     explode_dbxrefs[explode_dbxrefs['node_dbxrefs'].str.contains('UMLS C') == True].groupby('node_id', sort=False)[
        'nodeXrefCodes'].apply(list).reset_index(name='nodeCUIs')
node_metadata = node_metadata.merge(explode_dbxrefs_UMLS, how='left', on='node_id')
del explode_dbxrefs_UMLS
del explode_dbxrefs['nodeXrefCodes']

### Get the UMLS CUIs for each node_id from CUI-CODEs file as CUI_CODEs
print('--reading CUI-CODES.csv...')
CUI_CODEs = pd.read_csv(csv_path("CUI-CODEs.csv"))
CUI_CODEs = CUI_CODEs.dropna().drop_duplicates().reset_index(drop=True)


#### A big groupby - ran a couple minutes - changed groupby to not sort the keys to speed it up
print('--flattening data from CUI_CODEs...')
CODE_CUIs = CUI_CODEs.groupby(':END_ID', sort=False)[':START_ID'].apply(list).reset_index(name='CUI_CODEs')
# JAS the call to upper is new.
print('--merging data from CUI_CODEs to node metadata...')
node_metadata = node_metadata.merge(CODE_CUIs, how='left', left_on='node_id', right_on=CODE_CUIs[':END_ID'].str.upper())
del CODE_CUIs
del node_metadata[':END_ID']

### Add column for Xref's CUIs - merge exploded_node_metadata with CUI_CODEs then group, eliminate duplicates and merge with node_metadata

node_xref_cui = explode_dbxrefs.merge(CUI_CODEs, how='inner', left_on='node_dbxrefs',
                                      right_on=CUI_CODEs[':END_ID'].str.upper())
node_xref_cui = node_xref_cui.groupby('node_id', sort=False)[':START_ID'].apply(list).reset_index(name='XrefCUIs')
node_xref_cui['XrefCUIs'] = node_xref_cui['XrefCUIs'].apply(lambda x: pd.unique(x)).apply(list)
node_metadata = node_metadata.merge(node_xref_cui, how='left', on='node_id')
del node_xref_cui
del explode_dbxrefs

### Add column for base64 CUIs
def base64it(x):
    return [base64.urlsafe_b64encode(str(x).encode('UTF-8')).decode('ascii')]

node_metadata['base64cui'] = node_metadata['node_id'].apply(base64it)
print('Done....................')


# In[8]:


# THIS BLOCK TAKES THE LONGEST ^^^^^^^6


# In[9]:


#%%time
### Add cuis list and preferred cui to complete the node "atoms" (code, label, syns, xrefs, cuis, CUI)

print('--assigning CUIs to nodes...')
# create correct length lists
node_metadata['cuis'] = node_metadata['base64cui']
node_metadata['CUI'] = ''

#join list across row
node_metadata['cuis'] = node_metadata[['nodeCUIs', 'CUI_CODEs', 'XrefCUIs', 'base64cui']].values.tolist()
#remove nan, flatten, and remove duplicates - retains order of elements which is key to consistency
node_metadata['cuis'] = node_metadata['cuis'].apply(lambda x: [i for i in x if i == i])
node_metadata['cuis'] = node_metadata['cuis'].apply(lambda x: [i for row in x for i in row])
node_metadata['cuis'] = node_metadata['cuis'].apply(lambda x: pd.unique(x)).apply(list)


# In[9]:


# REWRITE AS LIST COMPREHENSION ^^^^^^^


# In[11]:


#%%time

#node_metadata = from_pandas(node_metadata, npartitions=8)
#node_metadata = node_metadata.compute()

#cui_list_lens = [len(i) for i in node_metadata['cuis']]

#repeats = pd.concat([node_metadata[:49_900],node_metadata[:100]])
#len(np.unique(repeats.cuis))

#d = pd.DataFrame([i[0] for i in repeats['cuis']])
#d[d[0].duplicated()]

#repeats[repeats['cuis'].duplicated()]

#repeats = repeats.reset_index(drop=True)
#repeats['cuis'][4] = rows.cuis*3


# In[10]:


#%%time
#iterate to select one CUI from cuis in row order - we ensure each node_id has its own distinct CUI
#each node_id is assigned one CUI distinct from all others' CUIs to ensure no self-reference in edgelist

# why are we doing the same thing for both these lists?
# if there is only one CUI per row we can get rid of the inner for loop.
t0 = time.time()

node_idCUIs = set() 
nmCUI = set()

for rows in node_metadata.itertuples():
    addedone = False
    INDEX = rows.Index

    for x in rows.cuis:
        if ((x in node_idCUIs) | (addedone == True)):
            dummy = 0  
        else:
            nmCUI.add((INDEX,x))
            node_idCUIs.add((INDEX,x))
            addedone = True

    if addedone == False:
        nmCUI.add((INDEX,uuid.uuid4()))
        node_idCUIs.add((INDEX,uuid.uuid4()))
        
    if INDEX % 100_000 == 0:
        print('Row: '+str(INDEX)+' Elapsed Time: '+str(np.round((time.time()-t0)/60,1)) + ' min')

d = dict(node_idCUIs)
ordered_cui_dict = {key:d[key] for key in sorted(d.keys())}
v = list(ordered_cui_dict.values())


# 7min 26s   for n=250k
# 9.4 min when convertiing to set and then searching each time.


# In[19]:


'''
import multiprocessing 
PARALLEL_SWITCH = 100_000

def search_cuis(x,cuis):
    return x in cuis
#iterate to select one CUI from cuis in row order - we ensure each node_id has its own distinct CUI
#each node_id is assigned one CUI distinct from all others' CUIs to ensure no self-reference in edgelist

# why are we doing the same thing for both these lists?
# if there is only one CUI per row we can get rid of the inner for loop.
t0 = time.time()

node_idCUIs = []
nmCUI = []

pool = multiprocessing.Pool()

for rows in node_metadata[:250_000].itertuples():
    addedone = False
    #print(rows.Index); break
    for x in rows.cuis:
        if rows.Index >= PARALLEL_SWITCH:
            s = [i[0] for i in node_metadata['cuis']]
            cui_list_splits = [s[i::n] for i in range(n)]
            args = list(zip([x]*len(cui_list_splits),cui_list_splits))
            results = pool.starmap(search_cuis, args)
            
            if (np.any(results) | (addedone == True)):
                dummy = 0
            else:
                nmCUI.append(x)
                node_idCUIs.append(x)
                addedone = True
        else:
            if ((x in node_idCUIs) | (addedone == True)):
                dummy = 0
            else:
                nmCUI.append(x)
                node_idCUIs.append(x)
                addedone = True

    if addedone == False:
        nmCUI.append('')
        node_idCUIs.append('')
        
    if rows.Index % 50000 == 0:
        print('Row: '+str(rows.Index)+' Elapsed Time: '+str(np.round((time.time()-t0)/60,1)) + ' min')
    elif rows.Index == PARALLEL_SWITCH:
        print('Switching to parallel search...')
'''


# In[78]:


# n = 20
# s = [i[0] for i in node_metadata['cuis']]
# cui_list_splits = [s[i::n] for i in range(n)]

#cui_list_splits[0]
# x = 'R1RFWF9FUVRMIHJzMTU5Mjk2NS1IZWFydC1BdHJpYWwtQXBwZW5kYWdlLUFTUzFQMTA='

# args = list(zip([x]*len(cui_list_splits),cui_list_splits))

#pool = multiprocessing.Pool()
#results = pool.starmap(search_cuis, args)
# np.any(results)


# In[11]:


#%%time
nmCUI = v
node_idCUIs = v
node_metadata['CUI'] = nmCUI

### Join CUI from node_metadata to each edgelist subject and object
print('Assembling CUI-CUI relationships...')
# Merge subject and object nodes with their CUIs; drop the codes; and add the SAB.

#The product will be a DataFrame in the format<br>
#CUI1 relation CUI2 inverse, e.g.,CUI1 isa CUI2 inverse_isa
#JAS 20 OCT 2022 Trim objnode1 and objnode2 DataFrames to reduce memory demand. (This is an issue for large ontologies, such as PR.)

if OWL_SAB == 'PR':
    # The node_metadata DataFrame has been filtered to proteins from a specified organism.
    # The edgelist DataFrame also needs to be filtered via merging.
    mergehow = 'inner'
else:
    # The node_metadata has not been filtered.
    mergehow = 'left'
    
edgelist = edgelist.merge(node_metadata, how=mergehow, left_on='subject', right_on='node_id')
edgelist = edgelist[['CUI', 'relation_label', 'object', 'inverse']]
edgelist.columns = ['CUI1', 'relation_label', 'object', 'inverse']

#Check first for object nodes in node_metadata--i.e., of type 1.<br>
#Matching CUIs will be in a field named 'CUI'.
objnode1 = edgelist.merge(node_metadata, how=mergehow, left_on='object', right_on='node_id')
objnode1 = objnode1[['object', 'CUI1', 'relation_label', 'inverse', 'CUI']]

# Check for object nodes in CUI_CODEs--i.e., of type 2. Matching CUIs will be in a field named ':END_ID'.
objnode2 = edgelist.merge(CUI_CODEs, how=mergehow, left_on='object', right_on=':END_ID')
objnode2 = objnode2[['object', 'CUI1', 'relation_label', 'inverse', ':START_ID']]

#Union (pd.concat with drop_duplicates) objNode1 and objNode2 to allow for conditional<br>
#selection of CUI.  The union will result in a DataFrame with columns for each node:<br>
#object CUI1 relation_label inverse CUI :START_ID
objnode = pd.concat([objnode1, objnode2]).drop_duplicates()

#If CUI is non-null, then the node is of the first type; otherwise, it is likely of the second type.
objnode['CUIMatch'] = objnode[':START_ID'].where(objnode['CUI'].isna(), objnode['CUI'])

edgelist = objnode[['CUI1', 'relation_label', 'CUIMatch', 'inverse']]

# Merge object nodes with subject nodes.
edgelist.columns = ['CUI1', 'relation_label', 'CUI2', 'inverse']
edgelist = edgelist.dropna().drop_duplicates().reset_index(drop=True)
edgelist['SAB'] = OWL_SAB
print('Done..........')


# In[12]:


## Write out files
### Test existence when appropriate in original csvs and then add data for each csv
#### Write CUI-CUIs (':START_ID', ':END_ID', ':TYPE', 'SAB') (no prior-existance-check because want them in this SAB)
print('Appending to CUI-CUIs.csv...')
# forward ones
edgelist.columns = [':START_ID', ':TYPE', ':END_ID', 'inverse', 'SAB']
edgelist[[':START_ID', ':END_ID', ':TYPE', 'SAB']].to_csv(csv_path('CUI-CUIs.csv'), mode='a', header=False, index=False)
# reverse
edgelist.columns = [':END_ID', 'relation_label', ':START_ID', ':TYPE', 'SAB']
edgelist[[':START_ID', ':END_ID', ':TYPE', 'SAB']].to_csv(csv_path('CUI-CUIs.csv'), mode='a', header=False, index=False)
del edgelist


# In[13]:


#%%time



#### Write CODEs (CodeID:ID,SAB,CODE) - with existence check against CUI-CODE.csv
print('Appending to CODEs.csv...')
newCODEs = node_metadata[['node_id', 'SAB', 'CODE', 'CUI_CODEs']]
newCODEs = newCODEs[newCODEs['CUI_CODEs'].isnull()]
newCODEs = newCODEs.drop(columns=['CUI_CODEs'])
newCODEs = newCODEs.rename({'node_id': 'CodeID:ID'}, axis=1)

newCODEs = newCODEs.dropna().drop_duplicates().reset_index(drop=True)
# write/append - comment out during development
newCODEs.to_csv(csv_path('CODEs.csv'), mode='a', header=False, index=False)

del newCODEs
#### Write CUIs (CUI:ID) - with existence check against CUI-CODE.csv
print('Appending to CUIs.csv...')
CUIs = CUI_CODEs[[':START_ID']].dropna().drop_duplicates().reset_index(drop=True)
CUIs.columns = ['CUI:ID']

newCUIs = node_metadata[['CUI']]
newCUIs.columns = ['CUI:ID']


# Here we isolate only the rows not already matching in existing files
df = newCUIs.drop_duplicates().merge(CUIs.drop_duplicates(), on=CUIs.columns.to_list(), how='left', indicator=True)
newCUIs = df.loc[df._merge == 'left_only', df.columns != '_merge']
newCUIs.reset_index(drop=True, inplace=True)

newCUIs = newCUIs.dropna().drop_duplicates().reset_index(drop=True)
# write/append - comment out during development
newCUIs.to_csv(csv_path('CUIs.csv'), mode='a', header=False, index=False)


#### Write CUI-CODEs (:START_ID,:END_ID) - with existence check against CUI-CODE.csv
print('Appending to CUI_CODES.csv...')

newCUI_CODEsCUI = node_metadata[['CUI', 'node_id']]
newCUI_CODEsCUI.columns = [':START_ID', ':END_ID']

newCUI_CODEscuis = node_metadata[['cuis', 'node_id']][node_metadata['cuis'].apply(len) > 1]
newCUI_CODEscuis['cuis'] = newCUI_CODEscuis['cuis'].apply(lambda x: x[:-1])
newCUI_CODEscuis = newCUI_CODEscuis.explode('cuis')[['cuis', 'node_id']]
newCUI_CODEscuis.columns = [':START_ID', ':END_ID']

newCUI_CODEs = pd.concat([newCUI_CODEsCUI, newCUI_CODEscuis], axis=0).dropna().drop_duplicates().reset_index(drop=True)
df = newCUI_CODEs.merge(CUI_CODEs, on=CUI_CODEs.columns.to_list(), how='left', indicator=True)
newCUI_CODEs = df.loc[df._merge == 'left_only', df.columns != '_merge']
newCUI_CODEs = newCUI_CODEs.dropna().drop_duplicates().reset_index(drop=True)

newCUI_CODEs.to_csv(csv_path('CUI-CODEs.csv'), mode='a', header=False, index=False)

del newCUI_CODEsCUI
del newCUI_CODEscuis
del df
del newCUI_CODEs
print('Done')


# In[15]:


#%%time

node_metadata = node_metadata.replace('nan',np.nan)

if node_metadata['node_label'].isna().all():
    print('All node_labels are NaN.')
else:
    ######### Load SUIs from csv #########
    SUIs = pd.read_csv(csv_path("SUIs.csv"))
    # SUIs supposedly unique but...discovered 5 NaN names in SUIs.csv and drop them here
    # ?? from ASCII converstion for Oracle to Pandas conversion on original UMLS-Graph-Extracts ??
    SUIs = SUIs.dropna().drop_duplicates().reset_index(drop=True)

    #### Write SUIs (SUI:ID,name) part 1, from label - with existence check
    print('Appending to SUIs.csv...')
    SUIs = SUIs.astype(str)
    node_metadata = node_metadata.astype(str)

    #newSUIs = node_metadata.merge(SUIs, how='left', left_on='node_label', right_on='name')[
    #    ['node_id', 'node_label', 'CUI', 'SUI:ID', 'name']]

    if node_metadata.isna().sum()['node_label']: 
        newSUIs = node_metadata.dropna(subset=['node_label']).merge(
            SUIs, how='left', left_on='node_label', right_on='name')[
               ['node_id', 'node_label', 'CUI', 'SUI:ID', 'name']]   
    else:
        newSUIs = node_metadata.merge(SUIs, how='left', left_on='node_label', right_on='name')[
        ['node_id', 'node_label', 'CUI', 'SUI:ID', 'name']] 


    newSUIs.loc[(newSUIs['name'] != newSUIs['node_label']), 'SUI:ID'] =         newSUIs[newSUIs['name'] != newSUIs['node_label']]['node_label'].apply(base64it).str[0]

    newSUIs.columns = ['node_id', 'name', 'CUI', 'SUI:ID', 'OLDname']
    newSUIs = newSUIs[newSUIs['OLDname'].isnull()][['node_id', 'name', 'CUI', 'SUI:ID']]
    newSUIs = newSUIs.dropna().drop_duplicates().reset_index(drop=True)
    newSUIs = newSUIs[['SUI:ID', 'name']]

    # update the SUIs dataframe to total those that will be in SUIs.csv
    SUIs = pd.concat([SUIs, newSUIs], axis=0).reset_index(drop=True)

    # write out newSUIs - comment out during development
    newSUIs.to_csv(csv_path('SUIs.csv'), mode='a', header=False, index=False)



    ######### Write CUI-SUIs (:START_ID,:END_ID) ##############
    # get the newCUIs associated metadata (CUIs are unique in node_metadata)

    newCUI_SUIs = newCUIs.merge(node_metadata, how='inner', left_on='CUI:ID', right_on='CUI')
    newCUI_SUIs = newCUI_SUIs[['node_label', 'CUI']].dropna().drop_duplicates().reset_index(drop=True)


    # ====================== MEMORY ERROR BLOCK with GTEX_EQTL ==============================================
    #  get the SUIs matches
    newCUI_SUIs = newCUI_SUIs.merge(SUIs, how='left', left_on='node_label', right_on='name')[
        ['CUI', 'SUI:ID']].dropna().drop_duplicates().reset_index(drop=True)

    newCUI_SUIs.columns = [':START:ID', ':END_ID']
    newCUI_SUIs.to_csv(csv_path('CUI-SUIs.csv'), mode='a', header=False, index=False)
    # ====================== MEMORY ERROR BLOCK with GTEX_EQTL ==============================================
    
    
    #### Load CODE-SUIs and reduce to PT or SY
    print('Appending to CODE-SUIs.csv...')
    CODE_SUIs = pd.read_csv(csv_path("CODE-SUIs.csv"))
    CODE_SUIs = CODE_SUIs[((CODE_SUIs[':TYPE'] == 'PT') | (CODE_SUIs[':TYPE'] == 'SY'))]
    CODE_SUIs = CODE_SUIs.dropna().drop_duplicates().reset_index(drop=True)
    print('################ here')


    #### Write CODE-SUIs (:END_ID,:START_ID,:TYPE,CUI) part 1, from label - with existence check
    #get the SUIs matches
    #newCODE_SUIs = node_metadata.merge(SUIs, how='left', left_on='node_label', right_on='name')[
    #    ['SUI:ID', 'node_id', 'CUI']].dropna().drop_duplicates().reset_index(drop=True)
    node_metadata = node_metadata.replace('nan',np.nan)
    ##### CHANGES MADE HERE #########3 
        
    if node_metadata.isna().sum()['node_label']: 
        newCODE_SUIs = node_metadata.dropna(subset=['node_label']).merge(
            SUIs, how='left', left_on='node_label', right_on='name')[
        ['SUI:ID', 'node_id', 'CUI']].dropna().drop_duplicates().reset_index(drop=True)
    else:
        newCODE_SUIs = node_metadata.merge(
            SUIs, how='left', left_on='node_label', right_on='name')[
        ['SUI:ID', 'node_id', 'CUI']].dropna().drop_duplicates().reset_index(drop=True)




    newCODE_SUIs.insert(2, ':TYPE', 'PT')
    newCODE_SUIs.columns = [':END_ID', ':START_ID', ':TYPE', 'CUI']

    print('############### here2')

    # Here we isolate only the rows not already matching in existing files
    df = newCODE_SUIs.drop_duplicates().merge(CODE_SUIs.drop_duplicates(), on=CODE_SUIs.columns.to_list(), how='left',
                                              indicator=True)
    newCODE_SUIs = df.loc[df._merge == 'left_only', df.columns != '_merge']
    newCODE_SUIs.reset_index(drop=True, inplace=True)

    # write out newCODE_SUIs - comment out during development
    newCODE_SUIs.to_csv(csv_path('CODE-SUIs.csv'), mode='a', header=False, index=False)

    ## Write SUIs (SUI:ID,name) part 2, from synonyms - with existence check
    print('############### here3 ')


node_metadata = node_metadata.replace('nan',np.nan)

#%%time
if node_metadata['node_synonyms'].isna().all() :
    print('All node_synonyms are NaN.')
else:
    if node_metadata['node_synonyms'].nunique() == 1:
        print('only 1 synonym in whole df, check if its legitimate.')
        
    # explode and merge the synonyms
    explode_syns = node_metadata.explode('node_synonyms')[
        ['node_id', 'node_synonyms', 'CUI']].dropna().drop_duplicates().reset_index(drop=True)
    newSUIs = explode_syns.merge(SUIs, how='left', left_on='node_synonyms', right_on='name')[
        ['node_id', 'node_synonyms', 'CUI', 'SUI:ID', 'name']]


    # for Term.name that don't join with node_synonyms update the SUI:ID with base64 of node_synonyms
    newSUIs.loc[(newSUIs['name'] != newSUIs['node_synonyms']), 'SUI:ID'] =         newSUIs[newSUIs['name'] != newSUIs['node_synonyms']]['node_synonyms'].apply(base64it).str[0]

    # change field names and isolate non-matched ones (don't exist in SUIs file)
    newSUIs.columns = ['node_id', 'name', 'CUI', 'SUI:ID', 'OLDname']
    newSUIs = newSUIs[newSUIs['OLDname'].isnull()][['node_id', 'name', 'CUI', 'SUI:ID']]
    newSUIs = newSUIs.dropna().drop_duplicates().reset_index(drop=True)
    newSUIs = newSUIs[['SUI:ID', 'name']]

    # update the SUIs dataframe to total those that will be in SUIs.csv
    SUIs = pd.concat([SUIs, newSUIs], axis=0).reset_index(drop=True)

    # write out newSUIs - comment out during development
    newSUIs.to_csv(csv_path('SUIs.csv'), mode='a', header=False, index=False)

    del newSUIs; print('############### here4')
    
    #### Write CODE-SUIs (:END_ID,:START_ID,:TYPE,CUI) part 2, from synonyms - with existence check

    newCODE_SUIs = explode_syns.merge(SUIs, how='left', left_on='node_synonyms', right_on='name')[
    ['SUI:ID', 'node_id', 'CUI']].dropna().drop_duplicates().reset_index(drop=True)

    newCODE_SUIs.insert(2, ':TYPE', 'SY'); newCODE_SUIs.columns = [':END_ID', ':START_ID', ':TYPE', 'CUI']
    print('####### here 5')
    
    
    df = newCODE_SUIs.drop_duplicates().merge(CODE_SUIs.drop_duplicates(), on=CODE_SUIs.columns.to_list(), how='left',
                                          indicator=True)
    newCODE_SUIs = df.loc[df._merge == 'left_only', df.columns != '_merge']
    newCODE_SUIs.reset_index(drop=True, inplace=True)

    # write out newCODE_SUIs - comment out during development
    newCODE_SUIs.to_csv(csv_path('CODE-SUIs.csv'), mode='a', header=False, index=False)
    del newCODE_SUIs; print('done')


# #### Kernel is dying right here -- this was bc we were trying to do a merge on a NaN col
# https://stackoverflow.com/questions/47386405/memoryerror-when-i-merge-two-pandas-data-frames

# In[17]:


#%%time

#### Write DEFs (ATUI:ID, SAB, DEF) and DEFrel (:END_ID, :START_ID) - with check for any DEFs and existence check
print('Appending to DEFs.csv and DEFrel.csv...')

if node_metadata['node_definition'].isna().all() :
    print('All node_definitions are NaN.')
else:
    DEFs = pd.read_csv(csv_path("DEFs.csv"))
    DEFrel = pd.read_csv(csv_path("DEFrel.csv")).rename(columns={':START_ID': 'CUI', ':END_ID': 'ATUI:ID'})
    DEF_REL = DEFs.merge(DEFrel, how='inner', on='ATUI:ID')[
        ['SAB', 'DEF', 'CUI']].dropna().drop_duplicates().reset_index(drop=True)
    newDEF_REL = node_metadata[['SAB', 'node_definition', 'CUI']].rename(columns={'node_definition': 'DEF'})

    # Compare the new and old retaining only new
    df = newDEF_REL.drop_duplicates().merge(DEF_REL.drop_duplicates(), on=DEF_REL.columns.to_list(), how='left',
                                            indicator=True)
    newDEF_REL = df.loc[df._merge == 'left_only', df.columns != '_merge']
    newDEF_REL.reset_index(drop=True, inplace=True)

    # Add identifier
    newDEF_REL['ATUI:ID'] = newDEF_REL['SAB'] + " " + newDEF_REL['DEF'] + " " + newDEF_REL['CUI']
    newDEF_REL['ATUI:ID'] = newDEF_REL['ATUI:ID'].apply(base64it).str[0]
    newDEF_REL = newDEF_REL[['ATUI:ID', 'SAB', 'DEF', 'CUI']].dropna().drop_duplicates().reset_index(drop=True)

    # Write newDEFs
    newDEF_REL[['ATUI:ID', 'SAB', 'DEF']].to_csv(csv_path('DEFs.csv'), mode='a', header=False, index=False)

    # Write newDEFrel
    newDEF_REL[['ATUI:ID', 'CUI']].rename(columns={'ATUI:ID': ':END_ID', 'CUI': ':START_ID'}).to_csv(
        csv_path('DEFrel.csv'), mode='a', header=False, index=False)
    del DEFs
    del DEFrel
    del DEF_REL
    del newDEF_REL

