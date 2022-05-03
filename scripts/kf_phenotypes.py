#!/usr/bin/env python
# coding: utf-8

# In[1]:


import pandas as pd
import numpy as np
import os 
from umls_utils import get_paths, CUIbase64



def kf_phenotypes(config_path):

    # Get paths from config file
    #config_path = '/Users/stearb/Dropbox/CHOP/R03/code/neo4j_build_CFDIKG/build_scripts'
    
    data_dir,helper_data_dir,output_dir,LOCAL_CPU, umls_dir, umls_out_dir = get_paths(config_path)


    if not  os.path.isdir(output_dir+'kf_phenotypes'):
        os.mkdir(output_dir+'kf_phenotypes')
        print('Creating kf_phenotypes directory...')


    kf = pd.read_excel(data_dir+'KF_April2020_PosPhenos_HPO_Taylor.xlsx',
                       sheet_name='PositivePhenotypes')

    df = kf[['participant_id','hpo_id_phenotype']].rename(
                        columns={'participant_id':'KF_CODE','hpo_id_phenotype':'HPO_CODE'})

    df['KF_CodeID'] = ['KF ' + i for i in df['KF_CODE']]
    df['HPO_CodeID'] = ['HPO ' + i for i in df['HPO_CODE']]


    # From CSVs
    UMLS_CUI_CODE = pd.read_csv(umls_dir+'CUI-CODEs.csv')

    umls_hpo = UMLS_CUI_CODE[UMLS_CUI_CODE[':END_ID'].str.startswith('HPO')].rename(
                        columns={':END_ID':'HPO_CODE',':START_ID':'HPO_CUI'})

    umls_hpo.rename(columns={'HPO_CODE':'HPO_CodeID','HPO_CONCEPT':'CUI_HPO'},inplace=True)

    df['KF_CUI'] = CUIbase64(df['KF_CodeID'])

    df_merge = pd.merge(df,umls_hpo)


    # CUIs
    CUIs = df_merge['KF_CUI'].rename('CUI:ID')
    CUIs.to_csv(output_dir+ 'kf_phenotypes/CUIs_kf.csv',index=False)


    # CUI-CUIs
    CUI_CUIs = df_merge[['KF_CUI','HPO_CUI']].rename(columns={'KF_CUI':':START_ID','HPO_CUI':':END_ID'})
    CUI_CUIs[':TYPE'] = 'patient_has_phenotype'
    CUI_CUIs['SAB'] = 'KF_HPO'
    CUI_CUIs_inverse = CUI_CUIs.rename(columns={':END_ID':':START_ID',':START_ID':':END_ID'})
    CUI_CUIs_inverse = CUI_CUIs_inverse[[':START_ID',':END_ID',':TYPE','SAB']]
    CUI_CUIs_inverse[':TYPE'] = 'phenotype_of_patient'
    CUI_CUIs_inverse['SAB'] = 'KF_HPO'
    CUI_CUIs_all = pd.concat([CUI_CUIs,CUI_CUIs_inverse])
    CUI_CUIs_all.to_csv(output_dir+'kf_phenotypes/CUI_CUIs_kf.csv',index=False)


    # CODEs
    CODEs = df_merge[['KF_CodeID','KF_CODE']]
    CODEs['SAB'] = 'KF'
    CODEs = CODEs[['KF_CodeID','SAB','KF_CODE']]
    CODEs.to_csv(output_dir+'kf_phenotypes/CODEs_kf.csv',index=False)


    # CUI-CODEs
    CUI_CODEs = df_merge[['KF_CUI','KF_CodeID']].rename(columns={'KF_CUI':':START_ID','KF_CODE':':END_ID'})
    CUI_CODEs.to_csv(output_dir+'kf_phenotypes/CUI_CODEs_kf.csv',index=False)

