#!/usr/bin/env python
# coding: utf-8

import pandas as pd
import numpy as np
from collections import Counter
#import matplotlib.pyplot as plt
import warnings
import os
warnings.filterwarnings('ignore')
from umls_utils import CUIbase64,get_paths

def scHeart(config_path):
    #config_path = '/Users/stearb/Dropbox/CHOP/R03/code/neo4j_build_CFDIKG/build_scripts/'


    # Get paths from config file
    data_dir,helper_data_dir,output_dir,LOCAL_CPU, umls_dir, umls_out_dir = get_paths(config_path)


    if not os.path.isdir(output_dir+'scHeart'):
        os.mkdir(output_dir+'scHeart')
        print('Creating scHeart directory...')


    z = pd.read_csv('/Users/stearb/Desktop/R03_local/data/scHeart/asp_cell_type_markers_zeros_labelled.csv')
    z.drop(['p_val','pct.1','pct.2'],axis=1,inplace=True)

    #### Merge in HGNC IDs
    hgnc_master = pd.read_csv('/Users/stearb/Desktop/R03_local/data/use_config/HELPER_FILES/hgnc_master.txt','\t')
    gene_map = hgnc_master[['hgnc_id','symbol']].rename(columns={'symbol':'gene'})

    z2 = pd.merge(z,gene_map,on='gene')



    #### Merge in HGNC CUIs

    # First, GET CUI - HGNC CODE MAPPINGS STRAIGHT FROM CSVs
    UMLS_CUI_CODEs = pd.read_csv(umls_dir+'CUI-CODEs.csv')

    umls_genes = UMLS_CUI_CODEs[UMLS_CUI_CODEs[':END_ID'].str.startswith('HGNC')].rename(
                                        columns={':START_ID':'CUI_hgnc',':END_ID':'hgnc_id'})

    umls_genes['hgnc_id'] = [i.split(' ')[1] for i in umls_genes['hgnc_id']]

    z3 = pd.merge(z2,umls_genes,on='hgnc_id')


    ### Create the scHeart SAB
    z3['SAB'] = 'scHeart PMID: 31835037'

    # Create scHeart CODE

    # assert that the celltype and hgncid col will uniquely identify each code node
    assert len(z3) == len(z3[['cluster_celltype_name','hgnc_id']].drop_duplicates()) 

    z3['CODE'] = z3['cluster_celltype_name'] + ' ' + z3['hgnc_id']

    # Create scHeart CODEID
    z3['CODEID'] = z3['SAB'] + ' ' + z3['CODE']

    # Create scHeart CUIs
    z3['CUI:ID'] = CUIbase64(z3['CODEID'])

    z3.drop(['cluster','gene','hgnc_id'],axis=1,inplace=True)




    # ### Create cell type nodes

    # Now create the celltype nodes
    z3.rename(columns={'cluster_celltype_name':'celltype_CODE'},inplace=True)


    z3['celltype_SAB'] = 'author_defined_cluster'
    z3['celltype_CODEID'] = z3['celltype_SAB'] + ':' + z3['celltype_CODE']
    z3['celltype_CUI'] = CUIbase64(z3['celltype_CODEID'])


    # ## Load in main dataset
    # The data_w_bins.csv file is the most up-to-date

    #fulldata = pd.read_csv('/Users/stearb/Desktop/R03_local/data/scHeart/data_w_bins.csv')

    #fulldata['CODEID'] = fulldata['SAB'] + fulldata['preCODE']

    #fulldata['CUI:ID'] = CUIbase64(fulldata['CODEID'])

    #fulldata.head(3)

    fulldata = z3


    ### Remove rows w/ p val greater than .06 


    fulldata = fulldata[fulldata['p_val_adj'] < .06]


    # ### CUIs


    celltype_CUIs = fulldata['celltype_CUI'].rename({'celltype_CUI':'CUI:ID'}).drop_duplicates()#.reset_index(drop=True)

    CUIs = pd.concat([pd.DataFrame(fulldata['CUI:ID'].values,columns=['CUI:ID']),pd.DataFrame(celltype_CUIs.values,columns=['CUI:ID'])])
    CUIs.columns = ['CUI:ID']

    assert CUIs.duplicated().sum() == 0
    CUIs.to_csv(output_dir+'scHeart/CUIs_scHeart.csv',index=False)


    # ### CUI_CUIs

    sc_to_hgnc = fulldata[['CUI:ID','CUI_hgnc']]
    sc_to_hgnc[':TYPE'] = 'single_cell_expression_of'
    sc_to_hgnc['SAB'] = 'scHeart__HGNC'

    hgnc_to_sc = fulldata[['CUI_hgnc','CUI:ID']]
    hgnc_to_sc[':TYPE'] = 'has_single_cell_expression'
    hgnc_to_sc['SAB'] = 'scHeart__HGNC'

    sc_to_ct = fulldata[['CUI:ID','celltype_CUI']]
    sc_to_ct[':TYPE'] = 'single_cell_expression_in'
    sc_to_ct['SAB'] = 'scHeart__cellType'

    ct_to_sc = fulldata[['celltype_CUI','CUI:ID']]
    ct_to_sc[':TYPE'] = 'has_single_cell_expression'
    ct_to_sc['SAB'] = 'scHeart__cellType'

    CUI_CUIs = pd.DataFrame(np.concatenate([sc_to_hgnc.values,hgnc_to_sc.values , sc_to_ct.values,ct_to_sc.values
                                           ]),columns=[':START_ID',':END_ID',':TYPE','SAB'])

    CUI_CUIs.drop_duplicates(inplace=True)

    CUI_CUIs.to_csv(output_dir+'scHeart/CUI_CUIs_scHeart.csv',index=False)


    # ### CUI-CODE

    CUI_CODEs = fulldata[['CUI:ID','CODEID']]
    CUI_CODEs.columns = [':START_ID',':END_ID']

    CUI_CODEs_celltypes = fulldata[['celltype_CUI','celltype_CODEID']]
    CUI_CODEs_celltypes.columns = [':START_ID',':END_ID']

    CUI_CODEs_all = pd.concat([CUI_CODEs,CUI_CODEs_celltypes])
    CUI_CODEs_all.drop_duplicates(inplace=True)
    CUI_CODEs_all.to_csv(output_dir+'scHeart/CUI_CODEs_scHeart.csv',index=False)


    # ### CODES

    CODEs = fulldata[['CODEID','SAB','CODE']]
    CODEs.columns = ['CodeID:ID','SAB','CODE']

    CODEs_celltypes = fulldata[['celltype_CODEID','celltype_SAB','celltype_CODE']]
    CODEs_celltypes.columns = ['CodeID:ID','SAB','CODE']

    CODEs_all = pd.concat([CODEs,CODEs_celltypes])
    CODEs_all.drop_duplicates(inplace=True)


    CODEs_all.to_csv(output_dir+'scHeart/CODEs_scHeart.csv',index=False)


    # ## SUIs and CODE-SUIs will both be created in 2 steps.
    # Split p-vals up into bins

    # Define pval Bins:
    #### EXACT SAME BINS from GTEx notebook. ######
    bins = [0,1e-12,1e-11,1e-10,1e-9,1e-8,1e-7,1e-6,1e-5,1e-4,1e-3,.005,.01,.02,.03,.04,.05,.06]

    # Bin pvals
    fulldata['pvalue_bins'] = pd.cut(fulldata['p_val_adj'], bins)


    # # Now bin the log2FC column

    log2fc_bins_neg = [-5,-4,-3,-2.5,-2,-1.75,-1.5,-1.25,-1,-.75,-.5,-.25,-.2,-.15,-.1,-.05]
    log2fc_bins_pos = [i*-1 for i in log2fc_bins_neg][::-1] # and reverse it.
    log2fc_bins =  log2fc_bins_neg + [0] + log2fc_bins_pos + [6,7]
    fulldata['log2fc_bins'] = pd.cut(fulldata['avg_log2FC'], log2fc_bins)


    # pvalues that are 0 need to be addded to the (0.0,1e-12] bin. The lowerbound for this bin is not inclusive so
    # 0's are not automatically added to it.

    fulldata['pval_bins'] = [i if i is not np.nan else '(0.0,1e-12]' for i in fulldata['pvalue_bins']]
    fulldata.drop('pvalue_bins',axis=1,inplace=True)


    # Remove [] and () characters from intervals before creating SUIs
    fulldata['log2fc_bins'] = [str(i)[1:-1] for i in fulldata['log2fc_bins']]
    fulldata['pval_bins'] = [str(i)[1:-1] for i in fulldata['pval_bins']]

    fulldata['log2fc_bins'] = fulldata['log2fc_bins'].str.replace(' ','')
    fulldata['pval_bins'] = fulldata['pval_bins'].str.replace(' ','')


    assert fulldata.isna().sum().sum() == 0
    assert len(fulldata[fulldata['log2fc_bins'].isna()]) == 0


    # Create SUIs for this step.
    fulldata['SUIs_pvals'] = CUIbase64(fulldata['pval_bins'])
    fulldata['SUIs_log2fc'] = CUIbase64(fulldata['log2fc_bins'])


    SUIs_pvals = fulldata[['SUIs_pvals','pval_bins']].rename(columns={'SUIs_pvals':'SUI:ID','pval_bins':'name'})
    SUIs_log2fc = fulldata[['SUIs_log2fc','log2fc_bins']].rename(columns={'SUIs_log2fc':'SUI:ID','log2fc_bins':'name'})


    SUIs_all_bins = pd.concat([SUIs_pvals,SUIs_log2fc])
    SUIs_all_bins.drop_duplicates(inplace=True)
    SUIs_all_bins.reset_index(drop=True,inplace=True)


    # Create CODE-SUIs for this step

    CODE_SUIs_pvals = fulldata[['CODEID','SUIs_pvals','CUI:ID']].rename(columns={'CODEID':':START_ID','SUIs_pvals':':END_ID',
                                                              'CUI:ID':'CUI'})
    CODE_SUIs_pvals[':TYPE'] = 'p_value'



    CODE_SUIs_log2fc = fulldata[['CODEID','SUIs_log2fc','CUI:ID']].rename(columns={'CODEID':':START_ID','SUIs_log2fc':':END_ID',
                                                              'CUI:ID':'CUI'})

    CODE_SUIs_log2fc[':TYPE'] = 'log2fc'

    CODE_SUIs_all_bins = pd.concat([CODE_SUIs_pvals,CODE_SUIs_log2fc])

    CODE_SUIs_all_bins.columns = [':START_ID', ':END_ID', 'CUI',':TYPE']

    CODE_SUIs_all_bins = CODE_SUIs_all_bins[[':START_ID', ':END_ID',':TYPE','CUI']] # reorder

    CODE_SUIs_all_bins.drop_duplicates(inplace=True)


    # # Create the Threshold Terms (they will be strings)
    # 
    # Thresholds:
    # - < .05
    # - < .001
    # - < .0001
    # - < 1e-10

    # ### Assign Threshold values 

    fulldata['pval_threshold_1e-10'] = ['< 1e-10' if i < 1e-10 else np.nan for i in fulldata['p_val_adj']]

    fulldata['pval_threshold_1e-4'] = ['< 0.0001' if i < 1e-4 else np.nan for i in fulldata['p_val_adj']]

    fulldata['pval_threshold_1e-3'] = ['< 0.001' if i < 1e-3 else np.nan for i in fulldata['p_val_adj']]

    fulldata['pval_threshold_1e-2'] = ['< 0.01' if i < 1e-3 else np.nan for i in fulldata['p_val_adj']]

    fulldata['pval_threshold_.05'] = ['< 0.05' if i < .05 else np.nan for i in fulldata['p_val_adj']]

    thresh_df = fulldata[['pval_threshold_1e-10','pval_threshold_1e-4',
                      'pval_threshold_1e-3','pval_threshold_1e-2','pval_threshold_.05','p_val_adj']]




    # ### Create CODE-SUI file for pvals, log2fc and thresholds

    CODE_SUIs_thresholds = pd.DataFrame(np.concatenate([fulldata[['CODEID','CUI:ID','pval_threshold_1e-10']].values,
                                            fulldata[['CODEID','CUI:ID','pval_threshold_1e-4']].values,
                                            fulldata[['CODEID','CUI:ID','pval_threshold_1e-3']].values,
                                            fulldata[['CODEID','CUI:ID','pval_threshold_1e-2']].values,
                                            fulldata[['CODEID','CUI:ID','pval_threshold_.05']].values]),
                                                     columns=['CODEID','CUI:ID','name'])

    CODE_SUIs_thresholds.dropna(inplace=True)
    CODE_SUIs_thresholds['SUI:ID'] = CUIbase64(CODE_SUIs_thresholds['name'])
    CODE_SUIs_thresholds[':TYPE'] = 'p_value_threshold'



    SUI_thresholds = CODE_SUIs_thresholds[['SUI:ID','name']]
    SUI_thresholds.drop_duplicates(inplace=True)


    CODE_SUIs_thresholds = CODE_SUIs_thresholds.rename(columns={'CODEID':':START_ID',
                                                                'SUI:ID':':END_ID',
                                                               'CUI:ID':'CUI'}).drop('name',axis=1)

    CODE_SUIs_thresholds = CODE_SUIs_thresholds[[':START_ID',':END_ID', ':TYPE','CUI' ]]


    assert CODE_SUIs_thresholds.duplicated().sum() == 0


    CODE_SUIs_all = pd.concat([CODE_SUIs_all_bins,CODE_SUIs_thresholds])

    CODE_SUIs_all.to_csv(output_dir+'scHeart/CODE_SUIs_scHeart.csv',index=False)


    SUIs_all = pd.concat([SUIs_all_bins,SUI_thresholds])

    SUIs_all.to_csv(output_dir+'scHeart/SUIs_scHeart.csv',index=False)



