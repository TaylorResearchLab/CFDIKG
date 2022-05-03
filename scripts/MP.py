
import pandas as pd
import numpy as np
import warnings
from umls_utils import get_paths, CUIbase64

import os
from collections import Counter



def MP(config_path):

    data_dir,helper_data_dir,output_dir,LOCAL_CPU, umls_dir, umls_out_dir = get_paths(config_path)

    if not  os.path.isdir(output_dir+'MPO'):
        os.mkdir(output_dir+'MPO')
        print('Creating MPO directory...')


    if LOCAL_CPU:
        mp = pd.read_csv('/Users/stearb/Desktop/R03_local/data/ontologies/MP_n10s_directional.csv')
    else:
        mp = pd.read_csv(data_dir+'MP_n10s_directional.csv')


    all_codes = pd.concat([mp['start_code'],mp['end_code']])


    mp['start_SAB']  = [i[0] for i in mp['start_code'].str.split('_')]
    mp['end_SAB']  = [i[0] for i in mp['end_code'].str.split('_')]

    mp['start_code'] = [i.replace('_',':') if i.startswith('MP_') else i for i in mp['start_code']]
    mp['end_code'] = [i.replace('_',':') if i.startswith('MP_') else i for i in mp['end_code']]

    mp_only = mp.loc[((mp['start_SAB'] == 'MP') & (mp['end_SAB'] == 'MP'))]

    mp_only.dropna(inplace=True) 

    mp.loc[((mp['start_SAB'] == 'UBERON') & (mp['end_SAB'] == 'MP'))]

    mp_only.drop(['start_SAB','end_SAB'],axis=1,inplace=True)

    mp_only.reset_index(drop=True,inplace=True)


    mp_only['start_CodeID']  = [i.split(':')[0] + ' '+i for i in mp_only['start_code']]
    mp_only['end_CodeID'] = [i.split(':')[0] + ' '+i for i in mp_only['end_code']]

    mp_only['start_CUI'] = [i for i in CUIbase64(mp_only['start_CodeID'])]
    mp_only['end_CUI'] = [i for i in CUIbase64(mp_only['end_CodeID'])]

    assert len(np.unique(mp_only['start_CUI'])) == mp_only.nunique()['start_CUI']
    assert len(np.unique(mp_only['end_CUI'])) == mp_only.nunique()['end_CUI']

    CUIs = pd.DataFrame(pd.concat([mp_only['start_CUI'],mp_only['end_CUI']]),columns=['CUI:ID'])


    CUIs.drop_duplicates(inplace=True)

    CUIs.to_pickle(output_dir+'MPO/CUIs_mp_ont.pickle')


    CUI_CUIs = mp_only[['start_CUI','end_CUI','rel']].rename(
                            columns={'start_CUI':':START_ID','end_CUI':':END_ID','rel':':TYPE'})

    CUI_CUIs[':TYPE'] = 'isa' 

    CUI_CUIs['SAB'] = 'MP'


    CUI_CUIs_inverse = CUI_CUIs.rename(columns={':START_ID':':END_ID',':END_ID':':START_ID'})

    CUI_CUIs_inverse[':TYPE'] = 'inverse_isa'

    CUI_CUIs_all = pd.concat([CUI_CUIs,CUI_CUIs_inverse])

    CUI_CUIs_all.drop_duplicates(inplace=True)


    CUI_CUIs_all.to_pickle(output_dir+'MPO/CUI_CUIs_mp_ont.pickle')


    CUI_CODEs_array = np.concatenate([mp_only[['start_CUI','start_CodeID']].values,
                                      mp_only[['end_CUI','end_CodeID']].values])

    CUI_CODEs = pd.DataFrame(CUI_CODEs_array,columns=[':START_ID',':END_ID'])

    CUI_CODEs.drop_duplicates(inplace=True)

    CUI_CODEs.to_pickle(output_dir+'MPO/CUI_CODEs_mp_ont.pickle')


    CODEs_array = np.concatenate([mp_only[['start_code','start_CodeID']].values,
                                  mp_only[['end_code','end_CodeID']].values])

    CODEs = pd.DataFrame(CODEs_array,columns=['CODE','CodeID:ID'])

    CODEs['SAB'] = 'MP'

    CODEs = CODEs[['CodeID:ID','SAB','CODE']]

    CODEs.drop_duplicates(inplace=True)

    CODEs.to_pickle(output_dir+'MPO/CODEs_mp_ont.pickle')



    UMLS_SUIs = pd.read_pickle(umls_dir+'SUIs.pickle')


    mp_only['start_SUI'] = CUIbase64(mp_only['start_name'])

    mp_only['end_SUI'] = CUIbase64(mp_only['end_name'])


    SUIs_array = np.concatenate([mp_only[['start_SUI','start_name']].values,mp_only[['end_SUI','end_name']].values])

    SUIs = pd.DataFrame(SUIs_array,columns=['SUI:ID','name'])

    SUIs.drop_duplicates(inplace=True)



    SUIs = SUIs[~SUIs['name'].isin(UMLS_SUIs['name'])] # new way, where we query umls csvs directly

    SUIs.to_pickle(output_dir+'MPO/SUIs_mp_ont.pickle')




    CODE_SUIs_array = np.concatenate([mp_only[['start_CodeID','start_SUI','start_CUI','start_name']].values,
                                      mp_only[['end_CodeID','end_SUI','end_CUI','end_name']].values])

    CODE_SUIs = pd.DataFrame(CODE_SUIs_array,columns=[':START_ID',':END_ID','CUI','name'])

    CODE_SUIs[':TYPE']  = 'Term'

    CODE_SUIs.drop_duplicates(inplace=True)


    CODE_SUIs_overlap = CODE_SUIs[CODE_SUIs['name'].isin(UMLS_SUIs['name'])]

    CODE_SUIs_ok = CODE_SUIs[~CODE_SUIs['name'].isin(UMLS_SUIs['name'])]



    CODE_SUIs_overlap_fixed = pd.merge(CODE_SUIs_overlap.drop(':END_ID',axis=1),UMLS_SUIs[['SUI:ID','name']],on='name')


    CODE_SUIs_overlap_fixed.rename(columns={'SUI:ID':':END_ID'},inplace=True)


    CODE_SUIs_overlap_fixed.drop('name',axis=1,inplace=True)
    CODE_SUIs_ok.drop('name',axis=1,inplace=True)

    CODE_SUIs_final = pd.concat([CODE_SUIs_ok,CODE_SUIs_overlap_fixed])

    CODE_SUIs_final.to_pickle(output_dir+'MPO/CODE_SUIs_mp_ont.pickle')




