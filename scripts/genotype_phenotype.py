


import pandas as pd
import numpy as np
import os
import re
import matplotlib.pyplot  as plt
from collections import Counter
from umls_utils import get_paths, CUIbase64

pd.options.display.max_columns = None
import warnings
warnings.filterwarnings('ignore')


def genotype_phenotype(config_path):



    data_dir,helper_data_dir,output_dir,LOCAL_CPU, umls_dir, umls_out_dir = get_paths(config_path)


    if not  os.path.isdir(output_dir+'genopheno'):
        os.mkdir(output_dir+'genopheno')



    gno_phno = data_dir+'genotype-phenotype-assertions-ALL.csv'


    cols_to_drop = ['phenotyping_center','colony_id','sex','zygosity','strain_name','project_name',
                    'project_fullname','pipeline_name','pipeline_stable_id','procedure_stable_id',
                    'parameter_stable_id','p_value','percentage_change','effect_size','statistical_method',
                       'resource_name','strain_accession_id','allele_name','procedure_name','marker_accession_id',
                   'allele_symbol']

    df=pd.read_csv(gno_phno).drop(cols_to_drop,axis=1)


    df.dropna(inplace=True)


    df_dropdup = df.drop_duplicates(['marker_symbol','mp_term_id','mp_term_name','allele_accession_id','parameter_name'])

    all_top_level_mp_terms = np.ravel(list(df['top_level_mp_term_id'].apply(lambda x: x.split('|')).values))

    all_top_level_mp_terms_ = list([i.split(',') for i in all_top_level_mp_terms])

    flat_list = [item for sublist in all_top_level_mp_terms_ for item in sublist]




    stats = pd.read_pickle(data_dir+'statistical-results-ALL.pickle')


    stats_cols_to_include = ['marker_symbol','parameter_name','allele_name','marker_accession_id',
                             'mp_term_id','mp_term_name','top_level_mp_term_id','top_level_mp_term_name',
                             'allele_symbol','allele_accession_id']

    stats_slct = stats[stats_cols_to_include]

    stats_slct.dropna(inplace=True) 


    impc_1 = df[['mp_term_id','marker_symbol']]

    impc_2 = stats_slct[['mp_term_id','marker_symbol']].dropna() # There are only 34,434 rows here where mp_term_id is NOT NAN  





    impc_1.columns = ['MP_term','Gene']
    impc_2.columns = ['MP_term','Gene']

    impc_1.columns = impc_2.columns = ['MP_term','Gene']




    master_impc_list = pd.concat([impc_1,impc_2])#,mgi_5])




    master_impc_filt = master_impc_list.drop_duplicates() # .drop_duplicates(['MP_term','Gene'])  






    table_5 = 'http://www.informatics.jax.org/downloads/reports/MGI_PhenoGenoMP.rpt'

    df5=pd.read_csv(table_5,sep='\t',header=None)

    df5.columns = ['Allelic Composition','Allele Symbol(s)','Genetic Background',
                         'Mammalian Phenotype ID','PubMed ID',
                         'MGI Marker Accession ID (comma-delimited)']


    df5['Gene'] = [ i.split('<')[0] for i in df5['Allele Symbol(s)']]

    unique_pheno_df5 = df5['Mammalian Phenotype ID'].nunique()

    unique_genes = df5['Gene'].nunique()

    df5_ = df5[['Mammalian Phenotype ID','Gene']]

    df5_dedup = df5_.drop_duplicates(['Mammalian Phenotype ID','Gene'])



    table_9 = 'http://www.informatics.jax.org/downloads/reports/MGI_GenePheno.rpt'

    df9=pd.read_csv(table_9,sep='\t',header=None)

    df9.columns = ['Allelic Composition','Allele Symbol(s)','Allele IDs','Genetic Background','Mammalian Phenotype ID',
                  'PubMed ID', 'MGI Marker Accession ID','MGI Genotype Accession ID']

    df9['Gene'] = [ i.split('<')[0] for i in df9['Allele Symbol(s)']]

    df9_dedup = df9[['Mammalian Phenotype ID','Gene']].drop_duplicates(['Mammalian Phenotype ID','Gene'])

    unique_mp_terms = len(df9['Mammalian Phenotype ID'].unique())



    table10 = 'http://www.informatics.jax.org/downloads/reports/MGI_Geno_DiseaseDO.rpt'

    df10 = pd.read_csv(table10,sep='\t')

    df10.columns = ['Allelic Composition','Allele Symbol(s)','Allele IDs','Genetic Background','Mammalian Phenotype ID',
                  'PubMed ID', 'MGI Marker Accession ID','DO ID','OMIM ID']


    df10['Gene'] = [ i.split('<')[0] for i in df10['Allele Symbol(s)']]



    df10_dedup = df10[['Mammalian Phenotype ID','Gene']].drop_duplicates(['Mammalian Phenotype ID','Gene'])



    df5_fused  = df5_dedup['Mammalian Phenotype ID'] +'_'+ df5_dedup['Gene']

    df9_fused = df9_dedup['Mammalian Phenotype ID'] +'_'+ df9_dedup['Gene']

    df10_fused = df10_dedup['Mammalian Phenotype ID'] +'_'+ df10_dedup['Gene']






    master = pd.concat([df5_dedup,df9_dedup,df10_dedup])

    master_dedup = master.drop_duplicates()



    m2 = master_dedup[~master_dedup["Gene"].str.contains(pat='\/|\)|\(|\*',regex=True)] # "[^a-zA-Z0-9 -]"




    m2_bar = m2[m2['Gene'].str.contains('\|')]
    m2_nobar = m2[~m2['Gene'].str.contains('\|')]



    a = [i.split('|') for i in m2_bar['Gene']]

    bar_mask = []

    for i in a:
        if i[0]==i[1]:
            bar_mask.append(True)
        else:
            bar_mask.append(False)


    m2_bar_fixed = m2_bar[bar_mask]

    m2_bar_fixed['Gene'] = [i.split('|')[0] for i in m2_bar_fixed['Gene']]


    MASTER_LIST_FIXED = pd.concat([m2_nobar,m2_bar_fixed])


    MASTER_LIST_FIXED.rename(columns= {'Mammalian Phenotype ID' : 'MP_term'},inplace=True)


    MASTER_G2P = pd.concat([master_impc_filt,MASTER_LIST_FIXED])


    MASTER_G2P.drop_duplicates(inplace=True)

    MASTER_G2P_fixed = MASTER_G2P[~MASTER_G2P["Gene"].str.contains(pat='\/|\)|\(|\*',regex=True)]



    MASTER_G2P_fixed['CODE_mouse_gene'] = ['HCOP:'+i for i in MASTER_G2P_fixed['Gene']]
    MASTER_G2P_fixed['CodeID_mouse_gene'] = ['HCOP '+i for i in MASTER_G2P_fixed['CODE_mouse_gene']]


    MASTER_G2P_fixed['CUI_mouse_gene'] = CUIbase64(MASTER_G2P_fixed['CodeID_mouse_gene'])

    assert MASTER_G2P_fixed['CodeID_mouse_gene'].nunique()  ==  MASTER_G2P_fixed['CUI_mouse_gene'].nunique() 
    assert MASTER_G2P_fixed['Gene'].nunique()  ==  MASTER_G2P_fixed['CODE_mouse_gene'].nunique()
    assert MASTER_G2P_fixed.isna().sum().sum() == 0


    MASTER_G2P_fixed.rename(columns={'MP_term':'CODE_mp_term'},inplace=True)

    MASTER_G2P_fixed['CodeID_mp_term'] = ['MP '+i for i in MASTER_G2P_fixed['CODE_mp_term']]


    MASTER_G2P_fixed['CUI_mp_term'] = CUIbase64(MASTER_G2P_fixed['CodeID_mp_term'])


    assert MASTER_G2P_fixed['CodeID_mp_term'].nunique()  ==  MASTER_G2P_fixed['CUI_mp_term'].nunique()
    assert MASTER_G2P_fixed['CODE_mp_term'].nunique()  ==  MASTER_G2P_fixed['CodeID_mp_term'].nunique()


    CUIs = pd.DataFrame(MASTER_G2P_fixed['CUI_mouse_gene'].append(
                MASTER_G2P_fixed['CUI_mp_term']).drop_duplicates(),columns=['CUI'])

    CUIs.to_pickle(output_dir+'genopheno/CUIs_genotype.pickle')


    CUI_CUI = MASTER_G2P_fixed[['CUI_mouse_gene','CUI_mp_term']].rename(columns={'CUI_mouse_gene':':START_ID',
                                                                                 'CUI_mp_term':':END_ID'})

    CUI_CUI[':TYPE'] = 'gene_associated_with_phenotype'

    CUI_CUI_inverse = MASTER_G2P_fixed[['CUI_mouse_gene','CUI_mp_term']].rename(columns={'CUI_mouse_gene':':END_ID',
                                                                                 'CUI_mp_term':':START_ID'})

    CUI_CUI_inverse[':TYPE'] = 'phenotype_has_associated_gene'

    CUI_CUI_all =  pd.concat([CUI_CUI,CUI_CUI_inverse])

    CUI_CUI_all['SAB'] = 'IMPC'

    CUI_CUI_all.to_pickle(output_dir+'genopheno/CUI_CUI_genotype.pickle')



    codes_mouse_genes = MASTER_G2P_fixed[['CodeID_mouse_gene','CODE_mouse_gene']]
    codes_mp_terms = MASTER_G2P_fixed[['CodeID_mp_term','CODE_mp_term']]
    codes_mouse_genes['SAB'] = 'HGNC_HCOP'
    codes_mp_terms['SAB']  = 'MP'

    CODEs = pd.DataFrame(np.concatenate([codes_mouse_genes.values,codes_mp_terms.values], axis=0),columns=['CodeID',
                          'CODE','SAB'])

    CODEs = CODEs[['CodeID','SAB', 'CODE']] # Reorder

    CODES = CODEs.drop_duplicates(['CODE','CodeID'])

    CODES.to_pickle(output_dir+'genopheno/CODEs_genotype.pickle')


    code_cui_genes = MASTER_G2P_fixed[['CUI_mouse_gene','CodeID_mouse_gene']]
    code_cui_mp = MASTER_G2P_fixed[['CUI_mp_term','CodeID_mp_term']]

    CUI_CODEs = pd.DataFrame(np.concatenate([code_cui_genes.values,code_cui_mp.values]),
                 columns=['CUI','CODE']).drop_duplicates(['CODE','CUI'])

    CUI_CODEs.to_pickle(output_dir+'genopheno/CUI_CODE_genotype.pickle')
