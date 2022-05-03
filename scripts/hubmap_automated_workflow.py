

import warnings
warnings.filterwarnings('ignore')

import pandas as pd
pd.set_option('display.max_columns', 500)

import os
import numpy as np
from collections import Counter
import collections

import json
import anndata
from scipy.io import mmread
import gzip
from scipy import sparse
import matplotlib.pyplot as plt
import urllib
import time
from umls_utils import get_paths, CUIbase64


ON_HPC_CLUSTER = True

if ON_HPC_CLUSTER: config_path = '/home/stearb/R03_HUBMAP/code/'
else:config_path = '/Users/stearb/Dropbox/CHOP/R03/code/neo4j_build_CFDIKG/build_scripts/'

data_dir,helper_data_dir,output_dir,LOCAL_CPU,umls_dir,umls_out_dir = get_paths(config_path)

if not os.path.isdir(output_dir+'HUBMAPsc') and not ON_HPC_CLUSTER:
    os.mkdir(output_dir+'HUBMAPsc')
    print('Creating HuBMAPsc directory...')



study_ids = ['046251c94ea0e79ee935dd3de57e093c',  '3f678ab5cd7ed086ec0d2d4468fc5094',  '81a9fa68b2b4ea3e5f7cb17554149473', 'be103f95cc6c1a3e48f099d1bd149a49',
'04968c1fe0149ee367b0e53af55763e4',  '42ab155ddff1d33fe1c505c067828614',  '846e56ed969922f1cb7a81619b175620',  'c019a1cd35aab4d2b4a6ff221e92aaab',
'0576b972e074074b4c51a61c3d17a6e3',  '434fbc55d458dc4e06da9ba4961f3840',  '853ab5348f619043ab2f997ac8ae14f0',  'c05a38c5210b870281b5aea01e290339',
'0d1eb3d774a694b79e844987f771b183',  '4b16c24a3997ea8754921b0f1d60bc4d',  '8e2806ca447695e674889dba28506d38',  'd48b7990d638dbede870ae9c1976e475',
'1197c73d127193dd493ff542890a3d3d',  '53fe8a84564b313d4e8ee90f337129dc',  '91822c7d75c54ce838bcd4d77f076b25',  'd9780d3f4eb9edfe275abaa32ff8633b',
'14946a8eb12f2d787302f818b72fdc4e',  '59249f23ecdcc975c90de9a1956a5285',  '91cfb45f5d398e950ed65786c87f4372',  'e375a44f5cf5457c8f9b1132574c2436',
'1ca63edfa35971f475c91d92f4a70cb0',  '5d111a1db2f18d507d23e79b993e1e4a',  '92248f72d47b916a2027085ec1b8e996',  'e65175561b4b17da5352e3837aa0e497',
'277152f17b5a2f308820ab4d85c5a426',  '68159e4bd6a2cea1cd66e8f3050cfcb7',  '9a36e5319429ec6aca5a8a9fef401929',  'e8d642084fc5ec8b5d348ebab96a4b22',
'29a538c3ddb396dee26188ae1151da46',  '6cd63d0ee2c67c3be41e4be1522d9c07',  '9aed52d22e30b893045fd1f79b3663fb',  'ed630484e46ea49b319c0e1f92140059',
'2ab4c834a887341b8746a3e42143d786',  '7017034c816444f6acb469834e53344f',  '9fe24e50c8b8b77d86900ee4beecef69',  'eec6f3356dc3078c957baaa740849fcc',
'319aafd9420a0c1c6f175d6a2ef060a9',  '71477f504b0069828a368009fa3ab1ad',  'aaedb5272190e61bf557d3b0a1bc591f',  'f2647d9533956fdb12da6b1fc6254441',
'35a639b983ff85728bdb3cbe0eac360a', '739184f7ec84d93a35360cde81cc026c',  'b1f17d04de81b0a8a8e2b894308498d3',  'f412e76986c1012ea9589d545ed8f043',
'35f5b75a7e3d0711f16b0a10219586fb',  '747bd5b3f6fef699bcd6363ff51e59d9',  'b299e98235f157534445f00884ae7c44',  'f71249f6e349fb9a99a3d4f08541cab4',
'391061b538480d6d630bdfec283c0293',  '7646a8a89555a123a56446b66c183d58',  'b340bb5715f967aa74d1b8eaeec0d475',  'f9848244883f6c70972acef16680431a',
'3ac0768d61c6c84f0ec59d766e123e05',  '79f087ae551dd72997f174646bb0d5e0',  'ba3081716f3fa98a1670b0864c5115ff',  'faa1acc13943ee9d365b6cc6a3ea889f',
'3bb5f743b039cb620d7ef234e0876f7a',  '7b99b447ffc977a3f6f890d32c7238b3',  'bdfebbfbbaa33bf1d2a5ae4c31cde1de']


if ON_HPC_CLUSTER:
    HuBMAP_STUDY_DIR = data_dir
else:
    HuBMAP_STUDY_DIR = data_dir+'HUBMAPsc_studies/'


hgnc_master = pd.read_csv(helper_data_dir+'hgnc_master.txt','\t')

UMLS_CUI_CODEs = pd.read_pickle(umls_dir+'CUI-CODEs.pickle')

umls_genes = UMLS_CUI_CODEs[UMLS_CUI_CODEs[':END_ID'].str.startswith('HGNC')].rename(columns={':START_ID':'CUI_hgnc',':END_ID':'hgnc_id'})
umls_genes['hgnc_id'] = [i.split(' ')[1] for i in umls_genes['hgnc_id']]

tpm_bins = list([0.0000000,7e-4,8e-4,9e-4]) + list(np.linspace(1e-3,9e-3,9)) +            list(np.round(np.linspace(1e-2,9e-2,9),2)) + list(np.round(np.linspace(.1,1,10),2)) +            list(np.linspace(2,100,99)) + list(np.arange(100,1100,100)[1:]) +              list(np.arange(2000,11000,1000)) + list(np.arange(20000,110000,10000)) + [300000]

bmi_cui_binned = [['C0587773', 'C0424671', 'C1959901', 'C1445936', 'C0424672','C1319441'],
                [[0,16.5],[16.5001,19.9999],[20,24.999],[25,29.999],[30,39.999],[40,75]]]
df_bmi = pd.DataFrame(np.transpose(bmi_cui_binned),columns=['CUI','BMI Bins'])



def get_all_organ_CUIs(study_ids):
    organs_and_tissues = list()

    for filename in study_ids:
        request = urllib.request.urlopen(f'https://portal.hubmapconsortium.org/browse/dataset/{filename}.json')
        j = json.load(request)
        x=0
        for i in j['ancestors']:
            if 'rui_location' in i.keys(): x = i['rui_location']  #print(json.dumps(i['rui_location'], indent=2))

        if x==0: 
            print('No organ metadata found in rui_location field: '+filename)
        else:
            organ_metadata = json.loads(x)['ccf_annotations']
            organ_CodeIDs = [i.split('/')[-1] for i in organ_metadata]

            if len(organ_CodeIDs): organs_and_tissues.append(organ_CodeIDs)

    organs_flat = [item for sublist in organs_and_tissues for item in sublist]

    # take just the uberon terms and format to match the umls code ids for merging the uberon cuis in
    organs_flat = [i.replace('_',' ') if i.startswith('UBERON') else i for i in organs_flat]
    # add space in middle of FMA Codes
    organs_flat = [i.upper()[:3]+' '+i[3:] if i.startswith('fma') else i for i in organs_flat] 

    df_organs = pd.DataFrame(organs_flat,columns=['tissue_id']).drop_duplicates().reset_index(drop=True)

    umls_organs = UMLS_CUI_CODEs[UMLS_CUI_CODEs[':END_ID'].str.startswith(('UBERON','NCI ','FMA '))].rename(
                                        columns={':START_ID':'CUI_tissue',':END_ID':'tissue_id'})

    organs_master = pd.merge(df_organs,umls_organs,on='tissue_id',how='left')
    
    return organs_master


def get_metadata(filename):
    request = urllib.request.urlopen(f'https://portal.hubmapconsortium.org/browse/dataset/{filename}.json')
    return json.load(request)

def get_matrix(filename):
    if os.path.exists(study_path+'/expr.h5ad'):
        expr = anndata.read_h5ad(filename=study_path+'/expr.h5ad')
    elif os.path.exists(study_path+'/out.h5ad'):
        expr = anndata.read_h5ad(filename=study_path+'/out.h5ad')
    else:
        print('No file named "expr.h5ad" or "out.h5ad" found.')
    
    # FIX and test spliced_unspliced_sum matrrix ingestion
    #expr.layers['spliced_unspliced_sum'].todense()
    #
    sparse_mat = expr._X
    symbols = expr.var
    sample_barcodes = expr._obs.index.to_frame(name='barcodes').reset_index(drop=True)
    df_exp = pd.DataFrame(sparse_mat.todense())
    df_exp.columns = symbols.index.to_list()
    df_exp.index = [i[0] for i in sample_barcodes.values]
    
    assert len(symbols.index.to_list()) == len(np.unique(symbols.index.to_list())), 'Ensembl genes not unique'
    assert len(df_exp.index.to_list()) == len(np.unique(df_exp.index.to_list())), 'Barcodes not unique'
    
    return df_exp, sample_barcodes


def determine_spatial(filename):
    '''Determine if the HuBMAP study is a spatial study or not'''
    SPATIAL_FLAG = False
    #check spatial data metadata 
    request = urllib.request.urlopen(f'https://portal.hubmapconsortium.org/browse/dataset/{filename}.json')
    j = json.load(request)
    
    for ancestor in j['ancestors']:
        # Find the 'Dataset' json obj
        if ancestor['entity_type'] == 'Dataset': 
            for datatype in ancestor['data_types']:
                # caseless string matching, .casefold() is better,
                #  also leave room to check for other spatial protocols, not just slide-seq
                if datatype.lower()=='Slide-seq'.lower(): SPATIAL_FLAG = True             
    return SPATIAL_FLAG, j


def get_cluster_dict(study_path,df_exp):
    # why do sample_and_clusters and sampleClusterMap not have the same length?
    CLUSTER_FLAG = 1 # report back on whether we found cluster data or not
    cluster_dict = {}
    
    CLUSTER_PATH_1 = '/hubmap_ui/output/secondary_analysis.factors.json'
    CLUSTER_PATH_2 = '/cluster-marker-genes/output/cluster_marker_genes.factors.json'
    
    if os.path.exists(study_path+CLUSTER_PATH_1):
        with open(study_path+CLUSTER_PATH_1, 'r') as f: contents = json.loads(f.read())
            
    elif os.path.exists(study_path+CLUSTER_PATH_2): 
        with open(study_path+CLUSTER_PATH_2, 'r') as f: contents = json.loads(f.read())          
    else:
        print('No cluster data found, using entire matrix as cluster 0.')
        CLUSTER_FLAG = 0
        cluster_dict[0.0] = df_exp # set entire matrix as cluster 0
        unique_clusters = [0] # just the single cluster, so return this
        return cluster_dict, unique_clusters,CLUSTER_FLAG
        
    samples_and_clusters = pd.Series(contents['Leiden Cluster']['cells'])
    samples_and_clusters['clustered_samples'] = samples_and_clusters.index.to_list()
    samples_and_clusters = pd.DataFrame(contents['Leiden Cluster']['cells'].items(),columns=['barcodes','cluster'])
    sampleClusterMap  = pd.merge(sample_barcodes,samples_and_clusters,on='barcodes',how='left')
    unique_clusters = np.sort(sampleClusterMap['cluster'].dropna().unique())
    
    for CLUSTER in unique_clusters:
        # Get samples (barcodes) for each cluster
        cluster_N_samples = sampleClusterMap[sampleClusterMap['cluster'] == CLUSTER]['barcodes'].values
        cluster_N_mask = [i[0] for i in df_exp.index.to_frame().isin(cluster_N_samples).values] 
        df_cluster_N = df_exp[cluster_N_mask]
        cluster_dict[CLUSTER] = df_cluster_N
        assert len(df_cluster_N) == len(cluster_N_samples)
    
    return cluster_dict, unique_clusters, CLUSTER_FLAG


def process_clusters(cluster_dict,unique_clusters):
    # get cluster lengths for normalizing gene sums
    clusters_lensum = 0
    cluster_sample_nums = {}
    for CLUSTER in unique_clusters:
        #print(cluster_dict[CLUSTER].shape)
        clusters_lensum = clusters_lensum + cluster_dict[CLUSTER].shape[0] 
        cluster_sample_nums[CLUSTER] = cluster_dict[CLUSTER].shape[0]
        
    # Sum gene expressions per cluster and drop genes whose sum == 0    
    gene_exp_sum_dict = {}
    for CLUSTER in unique_clusters:
        gene_sums=cluster_dict[CLUSTER].sum()
        gene_sums = gene_sums[gene_sums > 0.00]   
        gene_exp_sum_dict[CLUSTER] = gene_sums 
        
    # How many Nones are there in each cluster?
    for CLUSTER in unique_clusters:
        c = gene_exp_sum_dict[CLUSTER]
        total_len  = len(c)
        nones = [x for x in c.index.tolist() if x is None] 
        assert len(nones) == 0
        
    # Normalize gene expression by # of cells per cluster
    gene_exp_sum_normed = {}
    for CLUSTER in unique_clusters:                   
        gene_exp_sum_normed[CLUSTER] = gene_exp_sum_dict[CLUSTER] / cluster_sample_nums[CLUSTER]
        
    # Add cluster column
    gene_exp_sum_clust = {}
    for CLUSTER in unique_clusters:
        temp = pd.DataFrame(gene_exp_sum_normed[CLUSTER])
        temp['cluster'] = str(CLUSTER)
        gene_exp_sum_clust[CLUSTER]  = temp
        
    for CLUSTER in unique_clusters:
        if CLUSTER == 0:
            all_cluster_df = gene_exp_sum_clust[CLUSTER] # this should be okay if we only have a single cluster.
        else:
            all_cluster_df = all_cluster_df.append(gene_exp_sum_clust[CLUSTER])

    # check all clusters were appended
    length_all_clusters = 0
    for CLUSTER in unique_clusters:
        length_all_clusters = length_all_clusters + len(gene_exp_sum_clust[CLUSTER])
    assert length_all_clusters == len(all_cluster_df)        


    all_cluster_df['ensembl_id'] = all_cluster_df.index.to_list()
    all_cluster_df['unique_hubmap_del'] =  all_cluster_df['cluster'].astype(str) + ' ' + all_cluster_df['ensembl_id']
    all_cluster_df = all_cluster_df.rename(columns={0:'gene expression normed'})
    all_cluster_df['ensembl_match'] = [i.split('.')[0] for i in all_cluster_df['ensembl_id'].values]
    assert all_cluster_df.duplicated().sum() == 0
    
    # Need to add in cluster data here to create hubmap-cluster CUI-CUIs
    all_cluster_df['CODE_cluster'] = [metadata['uuid']+' CLUSTER '+i.split('.')[0] for i in all_cluster_df['cluster'].values]
    all_cluster_df['SAB'] = 'HUBMAPsc CLUSTER'
    all_cluster_df['CodeID_cluster'] = all_cluster_df['SAB'] + ' ' + all_cluster_df['CODE_cluster'] 
    all_cluster_df['CUI_cluster'] = CUIbase64(all_cluster_df['CodeID_cluster'])

    return all_cluster_df


def merge_hgnc_cuis(all_cluster_df,hgnc_master,metadata,umls_genes):
    '''merge in HGNC gene names and their CUIs'''
    ensembl_hgnc_map = hgnc_master[['hgnc_id','ensembl_gene_id']].rename(columns={'ensembl_gene_id':'ensembl_match'})
    df_ens_hgnc = pd.merge(all_cluster_df,ensembl_hgnc_map,on='ensembl_match')
    assert df_ens_hgnc.isna().sum().sum() == 0

    # merge in CUIs
    df = pd.merge(df_ens_hgnc,umls_genes,on='hgnc_id')
    
    # Create HuBMAP CUI,CodeID,CODE,SAB (study_id + cluster_# + CUI_hgnc + hgnc_id), study_id == metadata['uuid'] 
    df['HuBMAP_CODE'] = metadata['uuid'] +' '+'cluster ' +                 pd.Series([i[0] for i in df['cluster'].astype(str).str.split('.')]) +                 ' ' +  df['CUI_hgnc'] + ' ' + df['hgnc_id']
    
    df['SAB'] = 'HUBMAPsc'
    df['HuBMAP_CODE_ID'] = df['SAB']+ ' ' + df['HuBMAP_CODE']
    df['CUI_HuBMAP']  = CUIbase64(df['HuBMAP_CODE_ID'])

    return df


def create_hubmap_hgnc_cluster_cui_cuis(df):
    '''create hubmap-hgnc CUI-CUI relationships (and the reverse rels)
       create hubmap-cluster CUI-CUI Relationships (and the reverse rels) '''
    ######### CUI-CUI (HuBMAP -- HGNC)
    HuBMAP_HGNC_CUI_CUI = df[['CUI_HuBMAP','CUI_hgnc']]
    HuBMAP_HGNC_CUI_CUI[':TYPE'] = 'hubmap_study_has_gene_expression'
    HuBMAP_HGNC_CUI_CUI['SAB'] = 'HUBMAPsc__HGNC' 
    # Same thing but reversed
    HuBMAP_HGNC_CUI_CUI_REVERSE = df[['CUI_hgnc','CUI_HuBMAP']]
    HuBMAP_HGNC_CUI_CUI_REVERSE[':TYPE'] =  'gene_expression_of_hubmap_study'
    HuBMAP_HGNC_CUI_CUI_REVERSE['SAB'] = 'HUBMAPsc__HGNC' 
    HuBMAP_HGNC_CUI_2_CUIs = pd.concat([HuBMAP_HGNC_CUI_CUI.rename(columns={'CUI_HuBMAP':':START_ID','CUI_hgnc':':END_ID'}),HuBMAP_HGNC_CUI_CUI_REVERSE.rename(columns={'CUI_hgnc':':START_ID','CUI_HuBMAP':':END_ID'})])

    assert HuBMAP_HGNC_CUI_2_CUIs.shape[1] == 4, 'CUI-CUI incorrect cols'

    ######## CUI-CUI  (HUBMAP--CLUSTER)
    HuBMAP_CLUSTER_CUI_CUI = df[['CUI_HuBMAP','CUI_cluster']].rename(columns={'CUI_HuBMAP':':START_ID','CUI_cluster':':END_ID'})
    HuBMAP_CLUSTER_CUI_CUI[':TYPE'] = 'hubmap_node_belongs_to_cluster'
    HuBMAP_CLUSTER_CUI_CUI['SAB'] = 'HUBMAPsc__CLUSTER' 
    # Same thing but reversed
    HuBMAP_CLUSTER_CUI_CUI_REVERSE = df[['CUI_cluster','CUI_HuBMAP']].rename(columns={'CUI_HuBMAP':':END_ID','CUI_cluster':':START_ID'})
    HuBMAP_CLUSTER_CUI_CUI_REVERSE[':TYPE'] =  'cluster_has_hubmap_node'
    HuBMAP_CLUSTER_CUI_CUI_REVERSE['SAB'] = 'HUBMAPsc__CLUSTER' 
    HuBMAP_CLUSTER_CUI_2_CUIs = pd.concat([HuBMAP_CLUSTER_CUI_CUI,HuBMAP_CLUSTER_CUI_CUI_REVERSE])

    assert len(HuBMAP_CLUSTER_CUI_2_CUIs) == len(HuBMAP_HGNC_CUI_2_CUIs)
    assert HuBMAP_CLUSTER_CUI_2_CUIs.shape[1] == 4, 'HUBMAP-CLUSTER CUI-CUI incorrect cols'
    assert HuBMAP_HGNC_CUI_2_CUIs.shape[1] == 4, 'HUBMAP-HGNC CUI-CUI incorrect cols'

    return HuBMAP_HGNC_CUI_2_CUIs,HuBMAP_CLUSTER_CUI_2_CUIs



def create_tissue_CUI_rels(metadata,df,organs_master):
    organ_CodeIDs_sample = None
    tissue_data=0
    TISSUE_FLAG = 0 # report back on if tissue/organ metadata was found
    # Find tissue codes from the study metadata
    for i in metadata['ancestors']:
        if 'rui_location' in i.keys(): 
            tissue_data = i['rui_location']  #print(json.dumps(i['rui_location'], indent=2))
            organ_metadata_sample = json.loads(tissue_data)['ccf_annotations']
            organ_CodeIDs_sample = [i.split('/')[-1] for i in organ_metadata_sample]
            
    # CAN ALSO BE IN metadata['origin_sample']
    #"mapped_organ": "Lung (Right)", 
    #    "mapped_specimen_type": "Organ", 
    #    "organ": "RL",
    if tissue_data==0: 
        print('No organ metadata found in rui_location field: '+metadata['uuid']) #TISSUE_FLAG = 0

    if tissue_data != 0:
        TISSUE_FLAG = 1
        # take just the uberon terms and format to match the umls code ids for merging the uberon CUIs in
        organ_CodeIDs_sample = [i.replace('_',' ') if i.startswith('UBERON') else i for i in organ_CodeIDs_sample]# if i.startswith('UBERON')]
        # capitalize and add space for FMA codes to match umls code ids for merging FMA CUIs in
        organ_CodeIDs_sample = [i.upper()[:3]+' '+i[3:] if i.startswith('fma') else i for i in organ_CodeIDs_sample] #s[:4] + ' ' + s[4:], add space in middle    

        # Add tissue CUIs as their own columns, the value will be there CUIs from the organs master df
        for tissue_code in organ_CodeIDs_sample:
            tissue_CUI = organs_master[organs_master['tissue_id']==tissue_code]['CUI_tissue'].values[0]

            if str(tissue_CUI) == 'nan': pass #print(tissue_code+' has no matching CUI ')
            elif str(tissue_CUI) != 'nan':  df[tissue_code+' tissue_CUI'] = tissue_CUI ;#print(tissue_CUI);
   
        tissue_cols = [i for i in df.columns if 'tissue_CUI' in i] # loop through columns that contain the string tissue_CUI
        
        # if tissue codes were found, but then none of them mapped to any known CUIs (aka tissue_cols = []), we will still be inside this if statement
        # but we wont loop through the following for loop, and HUBMAP_TISSUE_CUI_CUI will never be assigned.
        if len(tissue_cols) == 0:  return df,None,TISSUE_FLAG, organ_CodeIDs_sample
        
        ## Now get the Dataset uuid, then create the Concept/Code data (same process we did for the Donor)
        DATASET_CODE = None
        
        # Find dataset uuid in metadata
        for descendant in metadata['descendants']:
            if descendant['entity_type'] == 'Dataset': DATASET_CODE = descendant['uuid']
        if DATASET_CODE == None:
            for ancestor in metadata['ancestors']:
                if ancestor['entity_type'] == 'Dataset': DATASET_CODE = ancestor['uuid']
                    
        assert DATASET_CODE != None
        
        DATASET_SAB = 'HUBMAPsc DATASET'; DATASET_CodeID = DATASET_SAB + ' ' + DATASET_CODE
        df['Dataset_SAB'] = DATASET_SAB; df['Dataset_CODE'] = DATASET_CODE
        df['Dataset_CODE_ID'] = DATASET_CodeID; df['Dataset_CUI'] = CUIbase64(pd.Series(DATASET_CodeID))[0]

        #### Automate creation of Tissue CUI - DATASET CUI #####
        for n,tissue_CUI in enumerate(tissue_cols):
            forward = df[['Dataset_CUI',tissue_CUI]].rename(columns={'Dataset_CUI':':START_ID',tissue_CUI:':END_ID'}).drop_duplicates()
            forward['SAB'] = 'HUBMAPsc_DATASET__TISSUE'
            forward[':TYPE'] = 'hubmap_dataset_contains_tissue'

            reverse = df[[tissue_CUI,'Dataset_CUI']].rename(columns={tissue_CUI:':START_ID','Dataset_CUI':':END_ID'}).drop_duplicates()
            reverse['SAB'] = 'HUBMAPsc_DATASET__TISSUE'
            reverse[':TYPE'] = 'tissue_in_hubmap_dataset'

            both = pd.concat([forward,reverse])

            if n == 0: DATASET_TISSUE_CUI_CUI = both
            else: DATASET_TISSUE_CUI_CUI = DATASET_TISSUE_CUI_CUI.append(both)

        assert len(DATASET_TISSUE_CUI_CUI) == 2*len(tissue_cols)
        assert DATASET_TISSUE_CUI_CUI.shape[1] == 4; assert DATASET_TISSUE_CUI_CUI.duplicated().sum() == 0
        
        return df, DATASET_TISSUE_CUI_CUI,TISSUE_FLAG, organ_CodeIDs_sample
    
    return df,None,TISSUE_FLAG, organ_CodeIDs_sample # if tissue_data =0, return None instead of tissue CUI-CUI data


def bin_expression(df,tpm_bins):    
    # Create gene expression Bins  

    # Assert all values are within the bins ranges
    assert max(df['gene expression normed']) < max(tpm_bins)
    assert min(df['gene expression normed']) > min(tpm_bins)

    df['expression_bins'] = pd.cut(df['gene expression normed'], tpm_bins)

    assert df['expression_bins'].isna().sum() == 0

    df['bins_lowerbound'] = [i.left  for i in df['expression_bins'] ]
    df['bins_upperbound'] = [i.right  for i in df['expression_bins'] ]

    # Define the Term 'name'
    df['name'] = df['bins_lowerbound'].astype(str) + ',' + df['bins_upperbound'].astype(str)

    df.drop(['bins_lowerbound','bins_upperbound'],axis=1,inplace=True)

    df['SUI:ID'] = [i for i in CUIbase64(df['name'] )]

    HUBMAP_CODE_SUIs = df[['HuBMAP_CODE_ID','SUI:ID','CUI_HuBMAP']]
    HUBMAP_CODE_SUIs[':TYPE'] = 'normed_gene_expression_per_cluster'  # normed_gene_expression_per_celltype
    HUBMAP_CODE_SUIs.columns = [':START_ID',':END_ID','CUI',':TYPE']
    
    return df, HUBMAP_CODE_SUIs




def create_metadata_df(metadata,unique_clusters):
    DONOR_CODE = None
    for ancestor in metadata['ancestors']:
        if ancestor['entity_type'] == 'Donor':
            #print(ancestor['uuid'])
            DONOR_CODE = ancestor['uuid']
    assert DONOR_CODE != None
    
    DONOR_SAB = 'HUBMAPsc DONOR'
    DONOR_CODE_ID = DONOR_SAB + ' ' + DONOR_CODE
    DONOR_CUI = CUIbase64(pd.Series(DONOR_CODE_ID))[0]

    # Create metadata dataframe, will hold node info on donor,dataset and the CUI-CUI relationships
    # b/t the donor and his/her metadata
    meta_df = pd.DataFrame([DONOR_CUI,DONOR_CODE,DONOR_CODE_ID,DONOR_SAB]).T
    meta_df.columns = ['CUI_donor','CODE_donor','CodeID_donor','SAB_donor']
    
    DATASET_CODE = None
    
    ## Now get the Dataset uuid, then create the Concept/Code data (same process we did for the Donor)
    for descendant in metadata['descendants']:
        if descendant['entity_type'] == 'Dataset':
            DATASET_CODE = descendant['uuid']
            
    # Some datasets ie ,have their Dataset info in the ancestors, why is this the case? 
    if DATASET_CODE == None:        
        for ancestor in metadata['ancestors']:
                if ancestor['entity_type'] == 'Dataset':
                    DATASET_CODE = ancestor['uuid']
                    
    DATASET_SAB = 'HUBMAPsc DATASET'
    DATASET_CodeID = DATASET_SAB + ' ' + DATASET_CODE
    meta_df['Dataset_SAB'] = DATASET_SAB
    meta_df['Dataset_CODE'] = DATASET_CODE
    meta_df['Dataset_CODE_ID'] = DATASET_CodeID
    meta_df['Dataset_CUI'] = CUIbase64(pd.Series(DATASET_CodeID))[0]

    # Create clusters df
    cluster_df = pd.DataFrame([unique_clusters]).T.astype(int).astype(str)
    cluster_df.columns = ['cluster #']

    cluster_df['CODE_cluster'] = metadata['uuid'] +' CLUSTER ' + cluster_df['cluster #']
    cluster_df['SAB'] = 'HUBMAPsc CLUSTER'
    cluster_df['CodeID_cluster'] = cluster_df['SAB'] + ' ' + cluster_df['CODE_cluster'] 
    cluster_df['CUI_cluster'] = CUIbase64(cluster_df['CodeID_cluster'])

    # Add dataset CUI in bc we want cluster-data set CUI-CUIs
    cluster_df['Dataset_CUI'] = meta_df['Dataset_CUI'].values[0]

    # CUI-CUIs
    # Define Donor to Dataset CUI to CUI
    DONOR_DATASET_CUI_CUI = meta_df[['CUI_donor','Dataset_CUI']].rename(columns={'CUI_donor':':START_ID','Dataset_CUI':':END_ID'})
    DONOR_DATASET_CUI_CUI['SAB'] = 'HUBMAP_DONORsc__HUBMAP_DATSET'
    DONOR_DATASET_CUI_CUI[':TYPE'] = 'donor_belongs_to_dataset'
    # Reverse relationship
    DATASET_DONOR_CUI_CUI = meta_df[['Dataset_CUI','CUI_donor']].rename(columns={'CUI_donor':':END_ID','Dataset_CUI':':START_ID'})
    DATASET_DONOR_CUI_CUI['SAB'] = 'HUBMAP_DONORsc__HUBMAP_DATSET'
    DATASET_DONOR_CUI_CUI[':TYPE'] = 'dataset_belongs_to_donor'

    # Define cluster to dataset CUI to CUI
    CLUSTER_DATASET_CUI_CUI = cluster_df[['CUI_cluster','Dataset_CUI']].rename(columns={'CUI_cluster':':START_ID','Dataset_CUI':':END_ID'})
    CLUSTER_DATASET_CUI_CUI['SAB'] = 'HUBMAPsc_CLUSTER__HUBMAP_DATASET'
    CLUSTER_DATASET_CUI_CUI[':TYPE'] = 'cluster_of_dataset'
    # reverse
    DATASET_CLUSTER_CUI_CUI = cluster_df[['Dataset_CUI','CUI_cluster']].rename(columns={'CUI_cluster':':END_ID','Dataset_CUI':':START_ID'})
    DATASET_CLUSTER_CUI_CUI['SAB'] =  'HUBMAPsc_CLUSTER__HUBMAP_DATASET'
    DATASET_CLUSTER_CUI_CUI[':TYPE'] = 'dataset_has_cluster'

    CUI_CUI_DONOR_DATASET_CLUSTER = pd.concat([DONOR_DATASET_CUI_CUI,DATASET_DONOR_CUI_CUI,CLUSTER_DATASET_CUI_CUI,DATASET_CLUSTER_CUI_CUI])

    # CUIs
    CUIs_donor_dataset_cluster = pd.concat( [meta_df['CUI_donor'].rename('CUI:ID'),meta_df['Dataset_CUI'].rename('CUI:ID'), cluster_df['CUI_cluster'].rename('CUI:ID')] )

    # CUI-CODEs
    CUI_CODE_donor = meta_df[['CUI_donor','CodeID_donor']].rename(columns={'CUI_donor':':START_ID','CodeID_donor':':END_ID'})
    CUIs_CODE_dataset = meta_df[['Dataset_CUI','Dataset_CODE_ID']].rename(columns={'Dataset_CUI':':START_ID','Dataset_CODE_ID':':END_ID'})
    CUI_CODE_cluster = cluster_df[['CUI_cluster','CodeID_cluster']].rename(columns={'CUI_cluster':':START_ID','CodeID_cluster':':END_ID'})
    CUIs_CODE_donor_dataset_cluster  = pd.concat([CUI_CODE_donor,CUIs_CODE_dataset,CUI_CODE_cluster])

    # CODEs
    CODE_donor = meta_df[['CodeID_donor','SAB_donor','CODE_donor']].rename(columns={'CodeID_donor':'CodeID:ID','SAB_donor':'SAB','CODE_donor':'CODE'})
    CODE_dataset = meta_df[['Dataset_CODE_ID','Dataset_SAB','Dataset_CODE']].rename(columns={'Dataset_CODE_ID':'CodeID:ID','Dataset_SAB':'SAB','Dataset_CODE':'CODE'})
    CODE_cluster = cluster_df[['CodeID_cluster','SAB','CODE_cluster']].rename(columns={'CodeID_cluster':'CodeID:ID','CODE_cluster':'CODE'})
    CODEs_donor_dataset_cluster = pd.concat([CODE_donor,CODE_dataset,CODE_cluster])


    return meta_df,CUI_CUI_DONOR_DATASET_CLUSTER, CUIs_donor_dataset_cluster,                CUIs_CODE_donor_dataset_cluster, CODEs_donor_dataset_cluster



def get_all_metadata_cats(study_ids):
    metadata_categories = set()

    for filename in study_ids:
        request = urllib.request.urlopen(f'https://portal.hubmapconsortium.org/browse/dataset/{filename}.json')
        j = json.load(request)

        if 'organ_donor_data' in j['donor']['metadata'].keys(): 
            donor_key = 'organ_donor_data'
        elif 'living_donor_data' in j['donor']['metadata'].keys(): 
            donor_key = 'living_donor_data'

        for i in  j['donor']['metadata'][donor_key]: 
            metadata_categories.add(i['grouping_concept_preferred_term'])
    
    metadata_categories = [e for e in metadata_categories if e not in 
                 ('Age','Height','Weight','Rh factor','Kidney donor profile index' )]
    
    return list(metadata_categories)


metadata_cat_dict = {
      'Race_CUI': ('HUBMAP_DATASETsc__RACE','dataset_donor_race','race_of_dataset_donor'),
      'Sex_CUI' : ('HUBMAP_DATASETsc__SEX','dataset_donor_sex','sex_of_donor'),
      'Medical history_CUI': ('HUBMAPsc_DATASET__MEDICAL_HISTORY','dataset_donor_medical_history','medical_history_of_dataset_donor'),
      'Cause of death_CUI' : ('HUBMAPsc_DATASET__CAUSE_OF_DEATH','dataset_donor_cause_of_death','cause_of_death_of_dataset_donor'),
      'Mechanism of injury_CUI': ('HUBMAPsc_DATASET__MECHANISM_OF_INJURY','dataset_donor_mechanism_of_injury','mechanism_of_injury_of_dataset_donor'),
      'Death event_CUI': ('HUBMAPsc_DATASET__DEATH_EVENT','dataset_donor_death_event','death_event_of_dataset_donor'),
    'Social history_CUI':('HUBMAPsc_DATASET__SOCIAL_HISTORY','dataset_donor_social_history','social_history_of_dataset_donor'),
        'Blood type_CUI':('HUBMAPsc_DATASET__BLOOD_TYPE','dataset_donor_blood_type','blood_type_of_dataset_donor'),
'Body mass index_CUI':('HUBMAPsc_DATASET__BMI','dataset_donor_bmi','bmi_of_dataset_donor')}

        
def dataset_metadata_CUIs(metadata,metadata_cat_dict,meta_df,study_id):

    # Each item in this list has a UMLS CUI (Concept) associated with metadata for the donor
    meta_data_categories = []

    if 'organ_donor_data' in metadata['donor']['metadata'].keys():
        donor_key = 'organ_donor_data'
    elif 'living_donor_data' in metadata['donor']['metadata'].keys():
        donor_key = 'living_donor_data'

    # Create metadata column names (just add CUI, or if its already a col name, add CUI_n) 
    for n,i in enumerate(metadata['donor']['metadata'][donor_key]):
        if i['data_type'] == 'Nominal':
            #print(i['grouping_concept_preferred_term'],':',i['preferred_term'], i['concept_id'])
            # There are multiple 'Medical History' fields (and other multiples) 
            # so we need to give them  different column names 
            # so if we find a column name already exists, add a # (n) to the end of it.
            if i['grouping_concept_preferred_term']+'_CUI' in meta_df.columns:
                col_name = i['grouping_concept_preferred_term']+'_CUI'+'_'+str(n)
                meta_df[col_name] = i['concept_id']
                meta_data_categories.append(col_name)
                #print(col_name)
            else:
                col_name = i['grouping_concept_preferred_term']+'_CUI'
                meta_df[col_name] = i['concept_id']
                meta_data_categories.append(col_name)
                #print(col_name)
                
        # BMI and Age are the only numeric metadata categories we are using.
        # we have to move the line 'meta_df[col_name] = i['concept_id']' further down in the logiic
        # where we match the numeric data value to the appropriate bin (and then CUI) 
        elif i['data_type'] == 'Numeric':
            if i['grouping_concept_preferred_term']+'_CUI' in meta_df.columns:
                col_name = i['grouping_concept_preferred_term']+'_CUI'+'_'+str(n)
                meta_data_categories.append(col_name)
            else:
                col_name = i['grouping_concept_preferred_term']+'_CUI'
                meta_data_categories.append(col_name)
            # Must match BMI and Age () to their respective CUIs, which represent bins
            numeric_data_value = np.float(i['data_value'])

            if i['grouping_concept_preferred_term'] == 'Body mass index':
                correct_bin = None
                for bmi_bin in df_bmi['BMI Bins']:
                    if numeric_data_value >= bmi_bin[0] and numeric_data_value <= bmi_bin[1]: correct_bin = bmi_bin
                if correct_bin == None: assert 1==0, 'NO BMI found!' # assert a bin was found
                # turn to str, bc it doesnt work matching on an array.
                correct_bmi_CUI = df_bmi[df_bmi['BMI Bins'].astype(str)==str(correct_bin)]['CUI'].values[0]
                meta_df[col_name] = correct_bmi_CUI
            elif i['grouping_concept_preferred_term'] == 'Age': pass        



    metadata_cat_dict_split = [i.split('_CUI')[0] for i in list(metadata_cat_dict.keys())]
    meta_data_categories = [cat for cat in meta_data_categories if cat.split('_CUI')[0] in metadata_cat_dict_split]
    
    #print(meta_data_categories)
    #assert len(meta_data_categories) == len(set(meta_data_categories))
    
    DATASET_meta_CUI_CUIs = pd.DataFrame(columns=[':START_ID',':END_ID',':TYPE','SAB'])

    for metadata_cat in meta_data_categories:

        for key in metadata_cat_dict.keys(): # get correct key
            if key in metadata_cat: correct_key = key #print(metadata_cat,correct_key)
        mdf = meta_df[['Dataset_CUI',metadata_cat]].rename(columns={'Dataset_CUI':':START_ID',metadata_cat:':END_ID'})
        mdf[':TYPE'] = metadata_cat_dict[correct_key][1] # forward relationship in 1st place
        mdf_rev = meta_df[[metadata_cat,'Dataset_CUI']].rename(columns={'Dataset_CUI':':END_ID',metadata_cat:':START_ID'})
        mdf_rev[':TYPE'] = metadata_cat_dict[correct_key][2] # reverse relationship in 2nd place
        mdf_full = pd.concat([mdf,mdf_rev])
        mdf_full['SAB'] = metadata_cat_dict[correct_key][0] # SAB is in the 0th place
        DATASET_meta_CUI_CUIs = DATASET_meta_CUI_CUIs.append(mdf_full)
        
        assert DATASET_meta_CUI_CUIs.isna().sum().sum() == 0
        
    return DATASET_meta_CUI_CUIs.reset_index(drop=True)



organs_master = get_all_organ_CUIs(study_ids)
assert organs_master.duplicated().sum() == 0

all_metadata_categories = get_all_metadata_cats(study_ids)



tissue_master_list = []

study_stats = pd.DataFrame(columns=['STUDY_UUID','STUDY_NAME','orginal_count_matrix_shape',
                                    'concat_cluster_shape','tissue_codes','num_clusters','cluster_data','organ_data','CUI_cnts',
                                    'CUI_CUIs_cnts','CUI_CODEs_cnts','CODEs_cnt','CODE_SUIs_cnt'])
t0 = time.time()

for i,filename in enumerate(study_ids):

    study_path = HuBMAP_STUDY_DIR+filename
    
    # this avoids trying to open files like .DS_store
    # could also just provide a list of all study IDs..., ignore spatial data for now...
    #HuBMAP_out_dir = f'/Users/stearb/Desktop/R03_local/data/ingest_files/HuBMAP/studies/{filename}/'
    # DONT NEED TO CHECK IF SPATIAL, JUST GET THE scRNA-seq (non-spatial) file names
    if os.path.isdir(study_path) and len(filename) == 32 and not determine_spatial(filename)[0]: 
        
        print(i,filename)#, end='')
        
        metadata = get_metadata(filename); #title = metadata['title']
        
        df_exp, sample_barcodes = get_matrix(filename) # Build exp. matrix w/ headers and index
        cluster_dict, unique_clusters,CLUSTER_FLAG = get_cluster_dict(study_path,df_exp) # Find cluster data, create cluster dict
        all_cluster_df = process_clusters(cluster_dict,unique_clusters) # Do cluster formatting/processing
        df = merge_hgnc_cuis(all_cluster_df,hgnc_master,metadata,umls_genes) # Merge in HGNC CUIs

        #print(f' (shape = {df_exp.shape})'); print(f'Title: {title}');print('*'*30)
        
        df, DATASET_TISSUE_CUI_CUI,TISSUE_FLAG, organ_CodeIDs_sample = create_tissue_CUI_rels(metadata,df,organs_master) # Create tissue CUI-CUIs
        
        tissue_master_list.append(organ_CodeIDs_sample)
        
        
        # Create HUBMAP- CLUSTER CUI-CUIs and HUBMAP-HGNC CUI-CUIs
        HuBMAP_HGNC_CUI_2_CUIs,HuBMAP_CLUSTER_CUI_2_CUIs = create_hubmap_hgnc_cluster_cui_cuis(df)

        # Concatenate HGNC--HUBMAP and TISSUE--DATASET CUI-CUI files together
        if isinstance(DATASET_TISSUE_CUI_CUI,pd.core.frame.DataFrame): 
            CUI_CUI_all = pd.concat([HuBMAP_HGNC_CUI_2_CUIs,HuBMAP_CLUSTER_CUI_2_CUIs,DATASET_TISSUE_CUI_CUI]) # Why Dups here?
        elif DATASET_TISSUE_CUI_CUI == None: 
            CUI_CUI_all = pd.concat([HuBMAP_HGNC_CUI_2_CUIs,HuBMAP_CLUSTER_CUI_2_CUIs])
                    
        # CUIs (HuBMAP)
        HuBMAP_CUIs = df['CUI_HuBMAP'].rename('CUI:ID'); 
        # CUI-CODE (HuBMAP)
        HuBMAP_CUI_CODEs = df[['CUI_HuBMAP','HuBMAP_CODE_ID']].rename(columns={'CUI_HuBMAP':':START_ID','HuBMAP_CODE_ID':':END_ID'})
        # CODE (HuBMAP)
        HuBMAP_CODEs = df[['HuBMAP_CODE_ID','SAB','HuBMAP_CODE']].rename(columns={'HuBMAP_CODE_ID':'CodeID:ID','HuBMAP_CODE':'CODE' })
        
        assert CUI_CUI_all.duplicated().sum() == 0, 'CUI-CUI dups'
        assert HuBMAP_CUIs.duplicated().sum() == 0, 'CUI dups'
        assert HuBMAP_CUI_CODEs.duplicated().sum() == 0, 'CUI-CODE dups'
        assert HuBMAP_CODEs.duplicated().sum() == 0, 'CODE dups'
        
        # Bin gene expression and create corresponding code-sui rels
        df,HUBMAP_CODE_SUIs = bin_expression(df,tpm_bins)
        
        # Create metadata CUI-CUIs (Donor,Dataset, Cluster and metadata terms about donor) and other files
        meta_df,CUI_CUI_DONOR_DATASET_CLUSTER,        CUIs_donor_dataset_cluster,        CUIs_CODE_donor_dataset_cluster,        CODEs_donor_dataset_cluster = create_metadata_df(metadata,unique_clusters)
        
        dataset_meta_CUI_CUIs = dataset_metadata_CUIs(metadata,metadata_cat_dict,meta_df,filename)

        # Combine datasets from current study
        HUBMAP_CUI_CUI_ALL = pd.concat([CUI_CUI_all,CUI_CUI_DONOR_DATASET_CLUSTER,dataset_meta_CUI_CUIs])
        HUBMAP_CUIs_ALL = pd.DataFrame(pd.concat([HuBMAP_CUIs,CUIs_donor_dataset_cluster]))
        HUBMAP_CODEs_ALL = pd.concat([HuBMAP_CODEs,CODEs_donor_dataset_cluster])
        HUBMAP_CUI_CODEs_ALL = pd.concat([HuBMAP_CUI_CODEs,CUIs_CODE_donor_dataset_cluster])

        # Initialize MASTER datasets if first loop, else, append datasets from studies together
        if i == 0:
            MASTER_CUI_CUI = HUBMAP_CUI_CUI_ALL
            MASTER_CUI = HUBMAP_CUIs_ALL
            MASTER_CODE = HUBMAP_CODEs_ALL
            MASTER_CUI_CODE = HUBMAP_CUI_CODEs_ALL
            MASTER_CODE_SUI = HUBMAP_CODE_SUIs
        else:
            MASTER_CUI_CUI = MASTER_CUI_CUI.append(HUBMAP_CUI_CUI_ALL)
            MASTER_CUI = MASTER_CUI.append(HUBMAP_CUIs_ALL)
            MASTER_CODE = MASTER_CODE.append(HUBMAP_CODEs_ALL)
            MASTER_CUI_CODE = MASTER_CUI_CODE.append(HUBMAP_CUI_CODEs_ALL)
            MASTER_CODE_SUI = MASTER_CODE_SUI.append(HUBMAP_CODE_SUIs)
        
        STATS =  [metadata['uuid'],metadata['title'],df_exp.shape,df.shape,organ_CodeIDs_sample ,
                  len(unique_clusters), CLUSTER_FLAG,TISSUE_FLAG,len(HUBMAP_CUIs_ALL),
                  len(HUBMAP_CUI_CUI_ALL), len(HUBMAP_CUI_CODEs_ALL), len(HUBMAP_CODEs_ALL), 
                  len(HUBMAP_CODE_SUIs)]
        
        study_stats.loc[i] = STATS  
        #print('*'*50); #if i == 4: break; #print(len(unique_clusters))
    else: 
        print(f'Could not find {filename} directory.'); #break


mins = np.round((time.time() - t0)/60,2)
print(f'\nIngest of {len(study_ids)} HUBMAP Single Cell RNAseq datasets took {mins} minutes.\n')





if LOCAL_CPU:
    assert 1==0, 'Not implemented.'
else:
    MASTER_CUI_CUI.to_pickle(output_dir+'HUBMAPsc/hubmap_CUI_CUIs.pickle')
    MASTER_CUI.to_pickle(output_dir+'HUBMAPsc/hubmap_CUIs.pickle')
    MASTER_CODE.to_pickle(output_dir+'HUBMAPsc/hubmap_CODEs.pickle')
    MASTER_CUI_CODE.to_pickle(output_dir+'HUBMAPsc/hubmap_CUIs_CODEs.pickle')
    MASTER_CODE_SUI.to_pickle(output_dir+'HUBMAPsc/hubmap_CODE_SUIs.pickle')


