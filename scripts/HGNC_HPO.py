#!/usr/bin/env python
# coding: utf-8

import pandas as pd
import numpy as np
import os
from collections import Counter
from umls_utils import get_paths


def HGNC_HPO(config_path):

    # Get paths from config file
    #config_path = '/Users/stearb/Dropbox/CHOP/R03/code/neo4j_build_CFDIKG/build_scripts/'

    data_dir,helper_data_dir,output_dir,LOCAL_CPU,umls_dir,umls_out_dir = get_paths(config_path)

    if not  os.path.isdir(output_dir+'HGNC_HPO'):
        os.mkdir(output_dir+'HGNC_HPO')
        print('Creating HGNC_HPO directory...')


    hgnc_hpo = pd.read_csv(data_dir+'hgnc_hpo_mappings.txt',
                           sep='\t',skiprows=1,header=None)

    hgnc_hpo.columns = ['HPO-id','HPO label','entrez-gene-id','entrez-gene-symbol',
                                'Additional Info from G-D source','G-D source','disease-ID for link']

    hgnc_hpo = hgnc_hpo[['HPO-id','entrez-gene-symbol']]
    hgnc_hpo.rename(columns={'entrez-gene-symbol':'symbol'},inplace=True)

    # ### Load in hgnc_master, which contains the gene_symbol - hgnc_code mappings
    hgnc_master = pd.read_csv(helper_data_dir+'hgnc_master_2cols.txt')
    hgnc_master.drop('Unnamed: 0',axis=1,inplace=True)

    # ### Merge in HGNC Codes
    hgnc_hpo_mappings = pd.merge(hgnc_hpo,hgnc_master,on='symbol')
    hgnc_hpo_mappings.drop('symbol',axis=1,inplace=True)
    hgnc_hpo_mappings.rename(columns={'hgnc_id':'HGNC_ID'},inplace=True)
    hgnc_hpo_mappings.drop_duplicates(inplace=True)

    # ### Merge in HGNC CUIs
    # GET CUI - HGNC CODE MAPPINGS STRAIGHT FROM CSVs
    # UMLS_CUI_CODEs = pd.read_csv(umls_dir+'CUI-CODEs.csv')
    UMLS_CUI_CODEs = pd.read_pickle(umls_dir+'CUI-CODEs.pickle')

    umls_genes = UMLS_CUI_CODEs[UMLS_CUI_CODEs[':END_ID'].str.startswith('HGNC')].rename(
                                        columns={':START_ID':'CUI_hgnc',':END_ID':'HGNC_ID'})

    umls_genes['HGNC_ID'] = [i.split(' ')[1] for i in umls_genes['HGNC_ID']]

    df = pd.merge(hgnc_hpo_mappings,umls_genes,on='HGNC_ID')

    # ### Merge in HPO CUIs
    hpo_cuis = UMLS_CUI_CODEs[UMLS_CUI_CODEs[':END_ID'].str.startswith('HPO')].rename(
                                        columns={':START_ID':'CUI_hpo',':END_ID':'HPO-id'})

    hpo_cuis['HPO-id'] = [i.split(' ')[1] for i in hpo_cuis['HPO-id']]

    final = pd.merge(df,hpo_cuis,on='HPO-id')
    final.drop(['HPO-id','HGNC_ID'],axis=1,inplace=True)
    final.drop_duplicates(inplace=True)


    # ### CUI-CUIs (Create forwards and reverse relationships)
    forwards = final.rename(columns={'CUI_hgnc':':START_ID','CUI_hpo':':END_ID'})
    forwards[':TYPE'] = 'gene_associated_with_phenotype'

    reverse = final.rename(columns={'CUI_hgnc':':END_ID','CUI_hpo':':START_ID'})
    reverse = reverse[[':START_ID',':END_ID']]
    reverse[':TYPE'] = 'phenotype_associated_with_gene'

    CUI_CUIs = pd.concat([forwards,reverse])
    CUI_CUIs['SAB'] = 'HGNC__HPO'

    CUI_CUIs.to_pickle(output_dir+'HGNC_HPO/CUI_CUIs_hgnc_hpo.pickle')

