#!/usr/bin/env python
# coding: utf-8


import pandas as pd
import numpy as np
import os
from collections import Counter
from umls_utils import get_paths, CUIbase64
import warnings
warnings.filterwarnings('ignore')

def HPO_MP(config_path):
    
    # Get paths from config file
    data_dir,helper_data_dir,output_dir,LOCAL_CPU,umls_dir, umls_out_dir = get_paths(config_path)

    if not  os.path.isdir(output_dir+'hpo_mp_mapping'):
        os.mkdir(output_dir+'hpo_mp_mapping')
        print('Creating hpo_mp_mapping directory...')


    #if LOCAL_CPU:
                #df=pd.read_excel('/Users/stearb/desktop/R03_local/data/tiffany_mappings/
                   #KF_HPO_OBO2OBOMappings_Aggregated_20DEC2020.xlsx',sheet_name='KF_OMOP2OBMappings_20Dec2020')
    #else:
    df=pd.read_excel(data_dir+'KF_HPO_OBO2OBOMappings_Aggregated_20DEC2020.xlsx',sheet_name='KF_OMOP2OBMappings_20Dec2020')


    # Replace _ with :
    df['HP_ID']  = df['HP_ID'].str.replace('_', ':')
    df['MPO_URI']  = df['MPO_URI'].str.replace('_', ':')


    # Splitby '|' so we can  have one HPO term and one MP term per row so we can upload to neo4j database.
    df['MPO_URI'] = df['MPO_URI'].str.split('|')
    df['MPO_URI'].head(5)



    # Unravel MPO_URI column
    df_ravel = pd.DataFrame(columns=df.columns)
    j=0

    for index, row in df.iterrows():    
        if len(row['MPO_URI']) == 1:
            df_ravel.loc[j] = row
            j=j+1

        elif len(row['MPO_URI']) > 1:
            current_row = row.drop(['MPO_URI']).T # Get all values except MPO_URI (which contains multiple terms)

            for MPO_TERM in row['MPO_URI']:
                row_temp = current_row
                mpo_formatted = pd.DataFrame([MPO_TERM],columns=['MPO_URI']).T
                mpo_formatted = mpo_formatted[0]
                new_row = row_temp.append(mpo_formatted).T # combine row_ with each MPO_URI and add them as new rows
                new_row=new_row[list(df_ravel.columns)]

                df_ravel.loc[j]  = np.ravel(new_row.T.values)
                j=j+1
                row_temp = 0




    mp_fixed = []
    for i in df_ravel['MPO_URI']:
        if len(i) == 1: # Length is 1 if its a list, otherwise it's the length of the string
            mp_fixed.append(i[0])
        else:
            mp_fixed.append(i)

    assert df_ravel.shape[0] == len(mp_fixed)
    df_ravel['MPO_URI'] = mp_fixed



    df_ravel.drop(['MPO_MAPPING','MPO_EVIDENCE'],axis=1,inplace=True) # Remove these cols for now

    # Strip white space from mp terms
    df_ravel['MPO_URI']  = [i.strip() for i in df_ravel['MPO_URI']]



    # ## Need to Connect these at the Concept & Code level, so we need to add CUIs, CODEs and  CodeIDs
    df_ravel.drop(['HP_LABEL','MPO_LABEL','HP_SYNONYM'],axis=1,inplace=True)
    df_ravel.rename(columns={'HP_ID':'CODE_HPO','MPO_URI':'CODE_MP'},inplace=True)
    df_ravel.head(4)


    ### There are already HPO terms in UMLS. We only need to create new CUIs/CODEs/CodeIDs for HPO terms that arent in there. But first we need to get HPO CUI/CODEs from UMLS and merge them into the dataframe (merge in CUIs on HPO Code).

    # From CSVs
    UMLS_CUI_CODE = pd.read_csv(umls_dir+'CUI-CODEs.csv')

    umls_hpo = UMLS_CUI_CODE[UMLS_CUI_CODE[':END_ID'].str.startswith('HPO')].rename(
                        columns={':END_ID':'CODE_HPO',':START_ID':'CUI_HPO'})

    umls_hpo.rename(columns={'HPO_CODE':'CODE_HPO','HPO_CONCEPT':'CUI_HPO'},inplace=True)

    umls_hpo['CODE_HPO'] = [i.split(' ')[1] for i in umls_hpo['CODE_HPO']]



    df_ravel['CodeID_MP'] = ['MP '+i for i in df_ravel['CODE_MP']]
    df_ravel['CodeID_HPO'] = ['HPO '+i for i in df_ravel['CODE_HPO']]
    df_ravel['CUI_MP'] =  CUIbase64(df_ravel['CodeID_MP'])

    assert len(df_ravel['CODE_MP'].unique())  ==  len(df_ravel['CodeID_MP'].unique()) 
    assert len(df_ravel['CODE_HPO'].unique())  ==  len(df_ravel['CodeID_HPO'].unique()) 


    # ### Merge in UMLS  HPO CUIs

    df_merge = pd.merge(left=df_ravel,right=umls_hpo.drop_duplicates(['CODE_HPO']),on='CODE_HPO',how='inner')


    # Save CUIs
    CUIs = pd.DataFrame(df_merge['CUI_MP'].drop_duplicates(),columns=['CUI'])

    if LOCAL_CPU:
        CUIs.to_csv('/Users/stearb/desktop/R03_local/data/ingest_files/hpo_mp_mapping/CUIs_phenomapping.csv',index=False) 
    else:
        CUIs.to_csv(output_dir+'hpo_mp_mapping/CUIs_phenomapping.csv',index=False) 



    # Save CUI-CUIs ( Same relationship SAB for both HPO->MP & MP->HPO )
    CUI_CUI = df_merge[['CUI_HPO','CUI_MP']]

    # Add SAB and relationship type (:TYPE) so the df matches the format of the UMLS import files.
    CUI_CUI[':TYPE'] = 'has_mouse_phenotype'
    CUI_CUI['SAB'] = 'HPO__MP'

    # Reverse the columns to create the inverse relationship, has_human_phenotype
    CUI_CUI_inverse = df_merge[['CUI_MP','CUI_HPO']]
    CUI_CUI_inverse[':TYPE'] = 'has_human_phenotype'
    CUI_CUI_inverse['SAB'] = 'HPO__MP'

    # Now combine both (need to change column names first so they can be concatenated) and save.
    CUI_CUI.rename(columns={'CUI_HPO':':START_ID','CUI_MP':':END_ID'},inplace=True)
    CUI_CUI_inverse.rename(columns={'CUI_HPO':':END_ID','CUI_MP':':START_ID'},inplace=True)

    CUI_CUIs_all = pd.concat([CUI_CUI,CUI_CUI_inverse])

    if LOCAL_CPU:
        CUI_CUIs_all.to_csv('/Users/stearb/desktop/R03_local/data/ingest_files/hpo_mp_mapping/CUI_CUI_phenomapping.csv',index=False) 
    else:
        CUI_CUIs_all.to_csv(output_dir+'hpo_mp_mapping/CUI_CUI_phenomapping.csv',index=False) 


    # Save CUI-CODEs
    mp_cui_codes = df_merge[['CUI_MP','CodeID_MP']]

    mp_cui_codes_reformat = mp_cui_codes.rename(columns={'CUI_MP':'CUI','CodeID_MP':'CODE'}).drop_duplicates()

    if LOCAL_CPU: mp_cui_codes_reformat.to_csv('/Users/stearb/desktop/R03_local/data/ingest_files/hpo_mp_mapping/CUI_CODEs_phenomapping.csv',index=False)
    else: mp_cui_codes_reformat.to_csv(output_dir+'hpo_mp_mapping/CUI_CODEs_phenomapping.csv',index=False)


    # Save CODEs
    mp_codes = df_merge[['CodeID_MP','CODE_MP']]
    mp_codes['SAB'] = 'MP'
    mp_codes.rename(columns={'CodeID_MP':'CodeID','CODE_MP':'CODE'},inplace=True)
    mp_codes  = mp_codes[['CodeID','SAB','CODE']]

    if LOCAL_CPU:
        mp_codes.to_csv('/Users/stearb/desktop/R03_local/data/ingest_files/hpo_mp_mapping/CODEs_phenomapping.csv',index=False)
    else:
        mp_codes.to_csv(output_dir+'hpo_mp_mapping/CODEs_phenomapping.csv',index=False)

        
#print('starting hpo-mp mappings build')       
#hpo_mp_mappings()        
#print('finished hpo-mp mappings build')       
