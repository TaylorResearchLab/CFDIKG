

import pandas as pd
import numpy as np
import os
from collections import Counter 
from umls_utils import get_paths
import time

def aggregate_files(config_path):

    data_dir,helper_data_dir,output_dir,LOCAL_CPU,umls_dir, umls_out_dir = get_paths(config_path)

    import_dir = output_dir

    if not os.path.isdir(output_dir+'new_UMLS_CSVs'):
        os.mkdir(output_dir+'new_UMLS_CSVs')
        print('Creating new_UMLS_CSVs directory...')

    new_UMLS_CSVs_path = output_dir+'new_UMLS_CSVs'+'/'






    t0 = time.time()

    CUI_ortho = pd.read_pickle(output_dir+'orthologs/CUI_mouse_ortho.pickle')

    CUI_genopheno = pd.read_pickle(output_dir+'genopheno/CUIs_genotype.pickle')

    CUI_mp = pd.read_pickle(output_dir+'MPO/CUIs_mp_ont.pickle') 

    CUI_phenomap = pd.read_csv(output_dir+'hpo_mp_mapping/CUIs_phenomapping.csv')

    CUI_gtex = pd.read_pickle(output_dir+'GTEx/CUIs_GTEx.pickle')


    CUI_kf = pd.read_csv(output_dir+'KF_phenotypes/CUIs_kf.csv')

    CUI_scHeart = pd.read_csv(output_dir+'scHeart/CUIs_scHeart.csv')

    CUI_hubmap = pd.read_pickle(output_dir+'HUBMAPsc/hubmap_CUIs.pickle')


    CUIs_all = pd.DataFrame(np.concatenate([CUI_ortho.values,CUI_genopheno ,CUI_mp  # CUI_dbsnp,
                                 ,CUI_phenomap,CUI_gtex,CUI_kf,CUI_scHeart,CUI_hubmap]),columns=['CUI:ID']).drop_duplicates()



    assert CUIs_all.nunique()['CUI:ID'] == len(CUIs_all)


    print('CUIs took',(time.time()-t0)/60,'minutes')



    t0 = time.time()

    CUI_CUI_ortho = pd.read_pickle(output_dir+'orthologs/CUI_CUI_ortho.pickle')

    CUI_CUI_genopheno = pd.read_pickle(output_dir+'genopheno/CUI_CUI_genotype.pickle')

    CUI_CUI_mp = pd.read_pickle(output_dir+'MPO/CUI_CUIs_mp_ont.pickle') # All :TYPEs are 'SCO' still...

    CUI_CUI_phenomap = pd.read_csv(output_dir+'hpo_mp_mapping/CUI_CUI_phenomapping.csv')

    CUI_CUI_gtex = pd.read_pickle(output_dir+'GTEx/CUI_CUI_GTEx.pickle')


    CUI_CUI_kf = pd.read_csv(output_dir+'kf_phenotypes/CUI_CUIs_kf.csv')

    CUI_CUI_scHeart = pd.read_csv(output_dir+'scHeart/CUI_CUIs_scHeart.csv')

    CUI_CUI_hgnc_hpo = pd.read_pickle(output_dir+'HGNC_HPO/CUI_CUIs_hgnc_hpo.pickle')


    CUI_CUI_hubmap = pd.read_pickle(output_dir+'HUBMAPsc/hubmap_CUI_CUIs.pickle')


    CUI_CUIs_all = pd.DataFrame(np.concatenate([CUI_CUI_ortho.values,
                                                CUI_CUI_genopheno,
                                                CUI_CUI_mp,
                                                CUI_CUI_phenomap,
                                                CUI_CUI_gtex, 
                                                CUI_CUI_kf, 
                                                CUI_CUI_scHeart,
                                                CUI_CUI_hgnc_hpo, # CUI_CUI_dbsnp
                                                CUI_CUI_hubmap
                                                ]),
                                                    columns=[':START_ID',':END_ID',':TYPE','SAB']).drop_duplicates()

    print('CUI-CUIs took',(time.time()-t0)/60,'minutes')




    t0 = time.time()

    CUI_CODEs_ortho = pd.read_pickle(output_dir+'orthologs/CUI_CODE_ortho.pickle')

    CUI_CODEs_genopheno = pd.read_pickle(output_dir+'genopheno/CUI_CODE_genotype.pickle')

    CUI_CODEs_mp = pd.read_pickle(output_dir+'MPO/CUI_CODEs_mp_ont.pickle')  

    CUI_CODEs_phenomap = pd.read_csv(output_dir+'hpo_mp_mapping/CUI_CODEs_phenomapping.csv')

    CUI_CODEs_gtex = pd.read_pickle(output_dir+'GTEx/CUI_CODEs_GTEx.pickle')


    CUI_CODEs_hgncAnnos =  pd.read_csv(output_dir+'hgnc_annos/CUI_CODEs_hgncAnno.csv')

    CUI_CODES_kf = pd.read_csv(output_dir+'kf_phenotypes/CUI_CODEs_kf.csv')

    CUI_CODES_scHeart = pd.read_csv(output_dir+'scHeart/CUI_CODEs_scHeart.csv')

    CUI_CODEs_hubmap = pd.read_pickle(output_dir+'HUBMAPsc/hubmap_CUIs_CODEs.pickle')



    CUI_CODEs_all = pd.DataFrame(np.concatenate([CUI_CODEs_ortho.values, 
                                             CUI_CODEs_mp.values, 
                                             CUI_CODEs_gtex.values,
                                             CUI_CODEs_genopheno.values,
                                             CUI_CODEs_phenomap.values, 
                                             CUI_CODEs_hgncAnnos.values,
                                             CUI_CODES_kf.values,
                                             CUI_CODES_scHeart.values,  #   CUI_CODEs_dbsnp.values
                                             CUI_CODEs_hubmap.values
                                           ]), columns=[':START_ID',':END_ID']).drop_duplicates()

    print('CUI-Codes took',(time.time()-t0)/60,'minutes')





    t0 = time.time()


    CODEs_ortho = pd.read_pickle(output_dir+'orthologs/CODE_mouse_ortho.pickle')

    CODEs_genopheno = pd.read_pickle(output_dir+'genopheno/CODEs_genotype.pickle')

    CODEs_mp = pd.read_pickle(output_dir+'MPO/CODEs_mp_ont.pickle')    

    CODEs_phenomap = pd.read_csv(output_dir+'hpo_mp_mapping/CODEs_phenomapping.csv')

    CODEs_gtex = pd.read_pickle(output_dir+'GTEx/CODEs_GTEx.pickle')   


    CODEs_hgncAnnos = pd.read_csv(output_dir+'hgnc_annos/CODEs_hgncAnno.csv')  


    CODEs_kf = pd.read_csv(output_dir+'kf_phenotypes/CODEs_kf.csv') 

    CODEs_scHeart = pd.read_csv(output_dir+'scHeart/CODEs_scHeart.csv') 

    CODEs_hubmap = pd.read_pickle(output_dir+'HUBMAPsc/hubmap_CODEs.pickle')


    CODEs_all = pd.DataFrame(np.concatenate([CODEs_ortho.values, 
                                             CODEs_genopheno.values,
                                             CODEs_mp.values, 
                                             CODEs_phenomap.values,
                                            CODEs_gtex.values, # CODEs_dbsnp.values
                                             CODEs_hgncAnnos.values,
                                             CODEs_kf.values,
                                             CODEs_scHeart.values,
                                             CODEs_hubmap.values
                                            ]),
                                         columns=['CodeID:ID','SAB','CODE']).drop_duplicates()

    print('Codes took',(time.time()-t0)/60,'minutes')



    t0 = time.time()

    SUIs_ortho = pd.read_pickle(output_dir+'orthologs/SUIs_ortho.pickle')

    SUIs_mp = pd.read_pickle(output_dir+'MPO/SUIs_mp_ont.pickle')
    SUIs_mp.rename(columns={'SUI':'SUI:ID','Term':'name'},inplace=True) 


    SUIs_gtex = pd.read_pickle(output_dir+'GTEx/SUIs_GTEx.pickle')
    SUIs_gtex['name'] = SUIs_gtex['name'].astype(str)


    SUIs_hgncAnno = pd.read_csv(output_dir+'hgnc_annos/SUIs_hgncAnnos.csv')

    SUIs_glygenAnno = pd.read_csv(output_dir+'glygen_annos/SUIs_glygenAnnos.csv')

    SUIs_scHeart = pd.read_csv(output_dir+'scHeart/SUIs_scHeart.csv')

    SUIs_all = pd.concat([SUIs_ortho,
                          SUIs_gtex, 
                          SUIs_mp,
                          SUIs_hgncAnno,
                          SUIs_glygenAnno,
                          SUIs_scHeart]) 


    SUIs_all.drop_duplicates('name',inplace=True)
    SUIs_all.drop_duplicates('SUI:ID',inplace=True)

    assert 0 == len(SUIs_all[SUIs_all['SUI:ID'].duplicated()])

    print('SUIs took',(time.time()-t0)/60,'minutes')





    t0 = time.time()


    CODE_SUI_ortho = pd.read_pickle(output_dir+'orthologs/CODE_SUI_ortho.pickle')

    CODE_SUIs_mp = pd.read_pickle(output_dir+'MPO/CODE_SUIs_mp_ont.pickle')

    CODE_SUIs_GTEX = pd.read_pickle(output_dir+'GTEx/CODE_SUIs_GTEx.pickle')


    CODE_SUIs_hgncAnno = pd.read_csv(output_dir+'hgnc_annos/CODE_SUIs_hgncAnnos.csv') 


    CODE_SUIs_glygenAnno = pd.read_csv(output_dir+'glygen_annos/CODE_SUIs_glygenAnnos.csv') 


    CODE_SUIs_scHeart = pd.read_csv(output_dir+'scHeart/CODE_SUIs_scHeart.csv') 

    CODE_SUIs_hubmap = pd.read_pickle(output_dir+'HUBMAPsc/hubmap_CODE_SUIs.pickle')

    CODE_SUIs_all = pd.concat([CODE_SUI_ortho,CODE_SUIs_GTEX,CODE_SUIs_mp,
                               CODE_SUIs_hgncAnno,
                               CODE_SUIs_glygenAnno,
                               CODE_SUIs_scHeart,CODE_SUIs_hubmap]) # 

    assert CODE_SUIs_all.isna().sum().sum() == 0

    assert set(CODE_SUIs_mp[':START_ID']) & set(CODE_SUIs_GTEX[':START_ID']) &  set(CODE_SUI_ortho[':START_ID']) == set()
    assert set(CODE_SUIs_mp[':END_ID']) & set(CODE_SUIs_GTEX[':END_ID']) &  set(CODE_SUI_ortho[':END_ID']) == set()

    print('CODE-SUIs took',(time.time()-t0)/60,'minutes')



    t0 = time.time()


    assert CUIs_all.isna().sum().sum() == 0
    assert CUI_CUIs_all.isna().sum().sum() == 0
    assert CUI_CODEs_all.isna().sum().sum() == 0
    assert CODEs_all.isna().sum().sum() == 0
    assert SUIs_all.isna().sum().sum() == 0
    assert CODE_SUIs_all.isna().sum().sum() == 0

    print('Assertions took',(time.time()-t0)/60,'minutes')



    t0 = time.time()


    UMLS_CUIs = pd.read_pickle(umls_dir+'CUIs.pickle')

    UMLS_CUI_CUIs = pd.read_pickle(umls_dir+'CUI-CUIs.pickle')

    UMLS_CODEs = pd.read_pickle(umls_dir+'CODEs.pickle')

    UMLS_CUI_CODEs = pd.read_pickle(umls_dir+'CUI-CODEs.pickle')

    UMLS_SUIs = pd.read_pickle(umls_dir+'SUIs.pickle')

    UMLS_CODEs_SUIs = pd.read_pickle(umls_dir+ 'CODE-SUIs.pickle')#,na_filter = False) 

    UMLS_CODEs_SUIs = UMLS_CODEs_SUIs[UMLS_CODEs_SUIs[':END_ID'].astype(bool)]

    UMLS_CUI_SUIs = pd.read_pickle(umls_dir+'CUI-SUIs.pickle')

    print('Loading UMLS files took',(time.time()-t0)/60,'minutes')




    t0 = time.time()


    concat_CUIs = pd.concat([UMLS_CUIs.drop_duplicates(),CUIs_all])

    concat_CUI_CUIs = pd.concat([UMLS_CUI_CUIs.drop_duplicates(),CUI_CUIs_all])

    concat_CODEs =  pd.concat([UMLS_CODEs.drop_duplicates(),CODEs_all])

    concat_CUI_CODEs  = pd.concat([UMLS_CUI_CODEs.drop_duplicates(),CUI_CODEs_all])

    concat_SUIs = pd.concat([UMLS_SUIs.drop_duplicates(),SUIs_all])

    concat_CODE_SUIs = pd.concat([UMLS_CODEs_SUIs.drop_duplicates(),CODE_SUIs_all])

    print('Concatenating files took',(time.time()-t0)/60,'minutes')


    t0 = time.time()


    concat_CUIs.to_csv(umls_out_dir+'CUIs.csv',index=False)
    concat_CUI_CUIs.to_csv(umls_out_dir+'CUI-CUIs.csv',index=False)
    concat_CODEs.to_csv(umls_out_dir+'CODEs.csv',index=False)
    concat_CUI_CODEs.to_csv(umls_out_dir+'CUI-CODEs.csv',index=False)
    concat_SUIs.to_csv(umls_out_dir+'SUIs.csv',index=False)
    concat_CODE_SUIs.to_csv(umls_out_dir+'CODE-SUIs.csv',index=False)

    print('Saving files took',(time.time()-t0)/60,'minutes')






