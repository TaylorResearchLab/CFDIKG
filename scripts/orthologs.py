


import numpy as np
import os
import pandas as pd
from collections import Counter
from umls_utils import get_paths, CUIbase64
import warnings





def orthologs(config_path):


    data_dir,helper_data_dir,output_dir,LOCAL_CPU, umls_dir,umls_out_dir = get_paths(config_path)


    if not os.path.isdir(output_dir+'orthologs'):
        os.mkdir(output_dir+'orthologs')


    if LOCAL_CPU:
        hgnc_bulk = pd.read_csv('/Users/stearb/downloads/human_mouse_hcop_fifteen_column.txt',sep='\t')
    else:
        hgnc_bulk = pd.read_csv(data_dir+'human_mouse_hcop_fifteen_column.txt',sep='\t')


    assert hgnc_bulk.isna().sum().sum() == 0


    hgnc_bulk = hgnc_bulk[hgnc_bulk['hgnc_id'] != '-']

    hgnc_bulk.drop_duplicates(['hgnc_id','human_symbol','mouse_symbol'],inplace=True)

    df=hgnc_bulk[['hgnc_id','mouse_symbol','mouse_ensembl_gene','mgi_id','mouse_name']]



    df = df[(df != '-').all(axis=1)]


    df['CODE_mouse'] = ['HCOP:'+i for i in df['mouse_symbol']]
    df['CodeID_mouse']  = ['HCOP '+i for i in df['CODE_mouse']]


    df['CUI_mouse'] =  CUIbase64(df['CodeID_mouse'])

    assert len(df['mouse_symbol'].unique())  ==  len(df['CUI_mouse'].unique()) 
    assert len(df['mouse_symbol'].unique())  ==  len(df['CODE_mouse'].unique()) 

    reorder_cols  = ['CUI_mouse','CODE_mouse', 'CodeID_mouse','hgnc_id','mouse_symbol',
                                             'mouse_ensembl_gene','mgi_id', 'mouse_name']
    df = df[reorder_cols]






    UMLS_CUI_CODEs = pd.read_pickle(umls_dir+'CUI-CODEs.pickle')

    umls_genes = UMLS_CUI_CODEs[UMLS_CUI_CODEs[':END_ID'].str.startswith('HGNC')].rename(
                                                        columns={':START_ID':'CUI_human',':END_ID':'hgnc_id'})

    umls_genes['hgnc_id'] = [i.split(' ')[1] for i in umls_genes['hgnc_id']]


    umls_genes_shared  = umls_genes[umls_genes['hgnc_id'].isin(df['hgnc_id'])]


    CUI2CUI_genes = pd.merge(left=umls_genes_shared,right=df,on='hgnc_id')


    CUI2CUI_genes.rename(columns={'hgnc_id':'CODE_human'},inplace=True)#,'CodeID_mouse':'CODE_mouse'


    CUIs_mouse = pd.DataFrame(CUI2CUI_genes['CUI_mouse'].unique(),columns=['CUI_mouse'])


    CUIs_mouse.to_pickle(output_dir+'orthologs/CUI_mouse_ortho.pickle')


    CUI2CUI  = CUI2CUI_genes[['CUI_human','CUI_mouse']].rename(columns={'CUI_human':':START_ID','CUI_mouse':':END_ID'})
    CUI2CUI[':TYPE'] = 'has_mouse_ortholog'

    CUI2CUI_inverse = CUI2CUI_genes[['CUI_mouse','CUI_human']].rename(columns={'CUI_mouse':':START_ID','CUI_human':':END_ID'})
    CUI2CUI_inverse[':TYPE'] = 'has_human_ortholog'

    CUI2CUI_all = pd.concat([CUI2CUI,CUI2CUI_inverse])
    CUI2CUI_all['SAB'] = 'HGNC__HGNC_HCOP' 
    CUI2CUI_all.to_pickle(output_dir+'orthologs/CUI_CUI_ortho.pickle')


    CODEs = CUI2CUI_genes[['CodeID_mouse','CODE_mouse']].drop_duplicates() 
    CODEs['SAB'] = 'HGNC_HCOP'
    CODEs = CODEs[['CodeID_mouse','SAB','CODE_mouse']] 
    CODEs.to_pickle(output_dir+'orthologs/CODE_mouse_ortho.pickle')


    CUI_CODEs = CUI2CUI_genes[['CUI_mouse','CodeID_mouse']].drop_duplicates()
    CUI_CODEs.to_pickle(output_dir+'orthologs/CUI_CODE_ortho.pickle')


    CUI2CUI_genes['SUI_mouse_symbol'] = CUIbase64(CUI2CUI_genes['mouse_symbol'])
    CUI2CUI_genes['SUI_mouse_name']  = CUIbase64( CUI2CUI_genes['mouse_name'])
    CUI2CUI_genes['SUI_mgi_id'] = CUIbase64(CUI2CUI_genes['mgi_id'])

    assert len(CUI2CUI_genes['SUI_mouse_symbol'].unique())  ==  len(CUI2CUI_genes['mouse_symbol'].unique()) 
    assert len(CUI2CUI_genes['SUI_mouse_name'].unique())  ==  len(CUI2CUI_genes['mouse_name'].unique()) 
    assert len(CUI2CUI_genes['SUI_mgi_id'].unique())  ==  len(CUI2CUI_genes['mgi_id'].unique()) 

    SUI_mouse_symbol = CUI2CUI_genes[['SUI_mouse_symbol','mouse_symbol']].rename(columns={
                                                'SUI_mouse_symbol':'SUI:ID','mouse_symbol':'name'})

    SUI_mouse_name = CUI2CUI_genes[['SUI_mouse_name','mouse_name']].rename(columns={
                                                'SUI_mouse_name':'SUI:ID','mouse_name':'name'})

    SUI_mgi_id = CUI2CUI_genes[['SUI_mgi_id','mgi_id']].rename(columns={
                                                'SUI_mgi_id':'SUI:ID','mgi_id':'name'})

    SUIs_all = pd.concat([SUI_mgi_id,SUI_mouse_name,SUI_mouse_symbol])


    SUIs_all.to_pickle(output_dir+'orthologs/SUIs_ortho.pickle')





    CODE_SUI_mouse_symbol = CUI2CUI_genes[['CodeID_mouse','SUI_mouse_symbol','CUI_mouse']].rename(columns={
                                                'CodeID_mouse':':START_ID','SUI_mouse_symbol':':END_ID','CUI_mouse':'CUI'})
    CODE_SUI_mouse_symbol[':TYPE'] = 'gene_symbol'



    CODE_SUI_mouse_name = CUI2CUI_genes[['CodeID_mouse','SUI_mouse_name','CUI_mouse']].rename(columns={
                                                'CodeID_mouse':':START_ID','SUI_mouse_name':':END_ID','CUI_mouse':'CUI'})
    CODE_SUI_mouse_name[':TYPE'] = 'gene_name'



    CODE_SUI_mgi_id = CUI2CUI_genes[['CodeID_mouse','SUI_mgi_id','CUI_mouse']].rename(columns={
                                                'CodeID_mouse':':START_ID','SUI_mgi_id':':END_ID','CUI_mouse':'CUI'})
    CODE_SUI_mgi_id[':TYPE'] = 'mgi_id'


    CODE_SUI = pd.concat([CODE_SUI_mgi_id,CODE_SUI_mouse_name,CODE_SUI_mouse_symbol])


    assert  CUI2CUI_genes.nunique()['mouse_name'] + CUI2CUI_genes.nunique()['mouse_symbol'] +                                       CUI2CUI_genes.nunique()['mgi_id'] -  1  == CODE_SUI.nunique()[':END_ID']


    CODE_SUI = CODE_SUI.drop_duplicates()


    CODE_SUI.to_pickle(output_dir+'orthologs/CODE_SUI_ortho.pickle')



