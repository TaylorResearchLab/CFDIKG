#!/usr/bin/env python



import warnings
warnings.filterwarnings('ignore')

import pandas as pd
import numpy as np
import os
from collections import Counter
import hashlib
from gtfparse import read_gtf
import base64
from matplotlib_venn import venn2
from IPython.display import Image
import  matplotlib.pyplot as plt
from umls_utils import get_paths, CUIbase64



def hgnc_annos_GENCODE(config_path):

    data_dir,helper_data_dir,output_dir,LOCAL_CPU,umls_dir,umls_out_dir = get_paths(config_path)


    if not  os.path.isdir(output_dir+'hgnc_annos'):
        os.mkdir(output_dir+'hgnc_annos')
        print('Creating hgnc_annos directory...')


    df=read_gtf(data_dir+'gencode.v38.chr_patch_hapl_scaff.basic.annotation.gtf')


    cols = ['seqname','feature','start','end','strand','gene_name']
    df = df[cols]

    genecode = df[df['feature'] == 'gene'].drop('feature',axis=1)

    genecode = genecode[genecode['seqname'].str.startswith('chr')]

    genecode.rename(columns={'gene_name':'symbol'},inplace=True)




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

    umls_hgnc_ids2codes = umls_hgnc_ids2codes.drop(['CodeID','SUI:ID',':TYPE','CUI'],axis=1).rename(
                                                                        columns={'name':'symbol'})


    ucsc_hgnc = pd.merge(left=genecode,right=umls_hgnc_ids2codes,how='left',on='symbol').dropna()



    ucsc_hgnc.drop_duplicates('symbol',inplace=True)

    umls_genes['HGNC_ID'] = [i.split(' ')[1] for i in umls_genes['HGNC_ID']]

    ucsc_hgnc_umls = pd.merge(left=ucsc_hgnc,right=umls_genes,how='left',on='HGNC_ID')

    assert ucsc_hgnc_umls.isna().sum().sum() == 0



    ucsc_hgnc_umls.rename(columns={'HGNC_ID':'CodeID_hgnc'})

    ucsc_hgnc_umls['CodeID_hgnc'] = ['HGNC ' + i for i in ucsc_hgnc_umls['HGNC_ID']]


    ucsc_hgnc_umls['strand'] = [i+' strand' for i in ucsc_hgnc_umls['strand']]

    ucsc_hgnc_umls.rename(columns={'seqname':'chrom'},inplace=True)

    ucsc_hgnc_umls['GL_Code'] = ['GL_' + i.split(' ')[1] for i in ucsc_hgnc_umls['CodeID_hgnc']]
    ucsc_hgnc_umls['GL_SAB'] = 'GENE_LOCATION'
    ucsc_hgnc_umls['GL_CodeID'] = ['GL '+ i for i in ucsc_hgnc_umls['GL_Code']]


    CUI_CODEs = ucsc_hgnc_umls[['CUI_hgnc','GL_CodeID']].rename(
                            columns={'CUI_hgnc':':START_ID','GL_Code':':END_ID'}).drop_duplicates()

    CUI_CODEs.to_csv(output_dir+'hgnc_annos/CUI_CODEs_hgncAnno.csv',index=False)

    CODEs = ucsc_hgnc_umls[['GL_CodeID','GL_SAB','GL_Code']].drop_duplicates()

    CODEs.to_csv(output_dir+'hgnc_annos/CODEs_hgncAnno.csv',index=False)


    chrom_SUIs = UMLS_SUIs.loc[(UMLS_SUIs['name'].str.startswith('chromosome').astype(bool)) &                            (UMLS_SUIs['name'].str.len() < 15) & (UMLS_SUIs['name'].str.len() > 10)]

    chrom_SUIs = chrom_SUIs[~chrom_SUIs['name'].str.contains('q|p|chromosomes|chromosome g')]

    chrom_SUIs_mito = UMLS_SUIs[UMLS_SUIs['name'] == 'mitochondrial chromosome']

    chrom_SUIs = pd.concat([chrom_SUIs,chrom_SUIs_mito]).reset_index(drop=True).rename(columns={'name':'chrom'})


    #### There are already chromosome Terms in UMLS, import there names/SUIs here and merge.
    #### MUST GET THIS DATA FROM THE CSVs and not the graph.
    chrom_SUIs = pd.read_csv('/Users/stearb/Desktop/R03_local/data/gtex/UMLS_chromosome_SUIs.csv')
    chrom_SUIs.rename(columns={'chrom':'chrom'},inplace=True)

    chrom = ucsc_hgnc_umls[['chrom','GL_CodeID']]

    chrom['chrom'] = ['chromosome '+ i.split('chr')[1] for i in chrom['chrom'].str.lower()]
    chrom['chrom'].replace('chromosome m','mitochondrial chromosome',inplace=True)

    chrom_terms = pd.merge(chrom,chrom_SUIs)

    chrom_terms.rename(columns={'chrom':'Term'},inplace=True)

    chrom_terms['rel'] = 'on_chromosome'

    assert chrom_terms.nunique()['Term'] == chrom_terms.nunique()['SUI']


    ucsc_hgnc_umls['start'] =ucsc_hgnc_umls['start'].astype(str)
    ucsc_hgnc_umls['end'] =ucsc_hgnc_umls['end'].astype(str)


    chromstart = ucsc_hgnc_umls[['start','GL_CodeID']]

    chromstart['SUI'] = CUIbase64(chromstart['start'])

    chromstart['rel'] = 'gene_start_position'

    assert chromstart.nunique()['start'] == chromstart.nunique()['SUI']
    chromstart.rename(columns={'start':'Term'},inplace=True)




    chromend = ucsc_hgnc_umls[['end','GL_CodeID']]

    chromend['SUI'] = CUIbase64(chromend['end'])

    chromend['rel'] = 'gene_end_position'

    assert chromend.nunique()['end'] == chromend.nunique()['SUI']
    chromend.rename(columns={'end':'Term'},inplace=True)




    strand = ucsc_hgnc_umls[['strand','GL_CodeID']]

    strand['SUI'] = CUIbase64(strand['strand'])
    strand['rel'] = 'strand'

    assert strand.nunique()['strand'] == strand.nunique()['SUI']
    strand.rename(columns={'strand':'Term'},inplace=True)




    CODE_SUIs = pd.concat([chrom_terms,chromstart,chromend,strand])

    assert CODE_SUIs.nunique()['Term'] == CODE_SUIs.nunique()['SUI']


    CODE_SUIs_merge = pd.merge(left=CODE_SUIs,
                  right=ucsc_hgnc_umls[['GL_CodeID','CUI_hgnc']],
                  how='inner',
                  on='GL_CodeID').drop_duplicates()


    CODE_SUIs_merge.rename(columns={'GL_CodeID':':START_ID','SUI':':END_ID','rel':':TYPE','CUI_hgnc':'CUI'},inplace=True)

    CODE_SUIs_2 = CODE_SUIs_merge[[':START_ID',':END_ID','CUI',':TYPE']]

    CODE_SUIs_2.to_csv(output_dir+'hgnc_annos/CODE_SUIs_hgncAnnos.csv',index=False)


    SUIs = CODE_SUIs_merge[[':END_ID','Term']].rename(columns={':END_ID':'SUI:ID','Term':'name'}).drop_duplicates()

    SUIs = SUIs[~(SUIs['SUI:ID'].str.startswith('S')  & (SUIs['name'].str.contains('chrom')))]

    SUIs.to_csv(output_dir+'hgnc_annos/SUIs_hgncAnnos.csv',index=False)






