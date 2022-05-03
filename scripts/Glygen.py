


import warnings
warnings.filterwarnings('ignore')

import pandas as pd
import numpy as np
import os
from collections import Counter
import hashlib
import base64
from umls_utils import get_paths, CUIbase64


def Glygen_annos(config_path):


    data_dir,helper_data_dir,output_dir,LOCAL_CPU,umls_dir,umls_out_dir = get_paths(config_path)


    if not  os.path.isdir(output_dir+'glygen_annos'):
        os.mkdir(output_dir+'glygen_annos')

    UMLS_CUI_CODEs = pd.read_csv(umls_dir+'CUI-CODEs.csv')

    umls_genes = UMLS_CUI_CODEs[UMLS_CUI_CODEs[':END_ID'].str.startswith('HGNC')].rename(
                                        columns={':START_ID':'CUI_hgnc',':END_ID':'HGNC_ID'})

    UMLS_CODE_SUIs = pd.read_csv(umls_dir+'CODE-SUIs.csv')

    umls_hgnc = UMLS_CODE_SUIs[UMLS_CODE_SUIs[':START_ID'].isin(umls_genes['HGNC_ID'])]


    umls_hgnc_acr = umls_hgnc[umls_hgnc[':TYPE'] == 'ACR']

    umls_hgnc_acr.rename(columns={':START_ID':'CodeID',':END_ID':'SUI:ID'},inplace=True) 

    UMLS_SUIs = pd.read_csv(umls_dir+'SUIs.csv')

    umls_hgnc_ids2codes = pd.merge(umls_hgnc_acr,UMLS_SUIs,on='SUI:ID')

    umls_hgnc_ids2codes['HGNC_ID'] = [i.split(' ')[1] for i in umls_hgnc_ids2codes['CodeID']]


    umls_hgnc_ids2codes = umls_hgnc_ids2codes.drop(['SUI:ID',':TYPE'],axis=1).rename(
                                                                        columns={'name':'symbol'})


    df_GT = pd.read_csv(data_dir+'glycosyltransferase_and_glycans/human/human_protein_glycosyltransferase.csv')


    cols = ['gene_symbol']#,'uniprotkb_canonical_ac','uniprotkb_protein_name','go_molecular_function']

    df_GT_select = df_GT[cols].drop_duplicates('gene_symbol').rename(columns={'gene_symbol':'symbol'})





    glyco_df = pd.merge(df_GT_select,umls_hgnc_ids2codes)#.isna().sum()



    glyco_df['name'] =  'Glycosyltransferase'    # pd.Series(glyco_term_name*len(glyco_df))
    glyco_df[':TYPE'] = 'is_protein_type'

    glyco_df['SUI'] = CUIbase64(glyco_df['name'] )




    glyco_CODE_SUIs = glyco_df[['CodeID','SUI','CUI',':TYPE']].rename(columns={'CodeID':':START_ID','SUI':':END_ID'}) 




    glyco_SUIs = glyco_df[['SUI','name']].rename(columns={'SUI':'SUI:ID'})

    glyco_SUIs.drop_duplicates(inplace=True)


    mouse_mapping_codes = pd.read_csv(helper_data_dir+'mouse_symbol_cui_codes.csv')
    mouse_mapping_codes.rename(columns={'mouse_symbol':'gene_symbol'},inplace=True)


    df_GT_mouse = pd.read_csv(data_dir+'glycosyltransferase_and_glycans/mouse/mouse_protein_glycosyltransferase.csv')
    df_GT_mouse = df_GT_mouse['gene_symbol']


    df_mouse_merged = pd.merge(mouse_mapping_codes,df_GT_mouse)

    df_mouse_merged['name'] =  'Glycosyltransferase'    # pd.Series(glyco_term_name*len(glyco_df))
    df_mouse_merged[':TYPE'] = 'is_protein_type'

    df_mouse_merged['SUI'] = CUIbase64(df_mouse_merged['name'] )


    glyco_CODE_SUIs_mouse = df_mouse_merged[['CodeID_mouse','SUI','CUI_mouse',':TYPE']]                            .rename(columns=
                                                {'CodeID_mouse':':START_ID',
                                                 'SUI'         :':END_ID',
                                                 'CUI_mouse'   :'CUI'})


    glyco_SUIs_mouse = df_mouse_merged[['SUI','name']].rename(columns={'SUI':'SUI:ID'}).drop_duplicates()



    glycans = pd.read_csv(data_dir+'glycosyltransferase_and_glycans/glycan_enzyme.csv')

    df_glycans = glycans[['gene_name','species']]




    glycan_human = df_glycans[df_glycans['species'] == 'human'].drop_duplicates()
    glycan_mouse = df_glycans[df_glycans['species'] == 'mouse'].drop_duplicates()



    glycan_human_merged = pd.merge(umls_hgnc_ids2codes.rename(columns={'symbol':'gene_name'}),
                                                                     glycan_human)





    glycan_mouse_merged = pd.merge(mouse_mapping_codes.rename(columns={'gene_symbol':'gene_name'})
             ,glycan_mouse)


    glycans_both = pd.concat([glycan_human_merged.rename(columns={'HGNC_ID':'Code'}),
                            glycan_mouse_merged.rename(columns={'CODE_mouse':'Code','CUI_mouse':'CUI',
                                       'CodeID_mouse':'CodeID'}) ])


    glycans_both.drop(['gene_name','species'],axis=1,inplace=True)




    glycans_both['name'] =  'Glycan'    
    glycans_both[':TYPE'] = 'is_protein_type'

    glycans_both['SUI'] =   'S20147466'    #CUIbase64(glycans_both['name'] )


    glycans_CODE_SUIs = glycans_both[['CodeID','SUI','CUI',':TYPE']].rename(columns=
                                                {'CodeID':':START_ID',
                                                 'SUI'   :':END_ID'})


    assert glyco_CODE_SUIs[':END_ID'][0] == glyco_CODE_SUIs_mouse[':END_ID'][0]


    CODE_SUIs_all = pd.concat([glyco_CODE_SUIs,glyco_CODE_SUIs_mouse, glycans_CODE_SUIs])
    SUIs_all = pd.concat([glyco_SUIs])  #,glycans_SUIs]) # glyco_SUIs_mouse, same as the human glyco term

    assert len(CODE_SUIs_all.columns) == 4
    assert len(SUIs_all.columns) == 2



    CODE_SUIs_all.to_csv(output_dir+'glygen_annos/CODE_SUIs_glygenAnnos.csv',index=False)

    SUIs_all.to_csv(output_dir+'glygen_annos/SUIs_glygenAnnos.csv',index=False)




