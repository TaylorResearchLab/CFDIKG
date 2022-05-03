



import pandas as pd
import numpy as np
import os
import warnings
warnings.filterwarnings('ignore')

import matplotlib.pyplot as plt
from matplotlib_venn import venn2, venn3
from collections import Counter
from IPython.display import Image
from umls_utils import get_paths, CUIbase64
from cmapPy.pandasGEXpress.parse_gct import parse

def GTEx(config_path):


    data_dir,helper_data_dir,output_dir,LOCAL_CPU,umls_dir,umls_out_dir = get_paths(config_path)

    if not  os.path.isdir(output_dir+'GTEx'):
        os.mkdir(output_dir+'GTEx')



    if LOCAL_CPU:
        samp_annos = pd.read_csv('gtex_sample_annotations.txt',sep='\t')
    else:
        samp_annos = pd.read_csv(helper_data_dir+'gtex_sample_annotations.txt',sep='\t')






    SAMPID_2_TISSUE = samp_annos[['SMTS','SMTSD','SMUBRID']] # 'SAMPID',

    SAMPID_2_TISSUE['SMTSD'] = SAMPID_2_TISSUE['SMTSD'].str.replace(' - ',' ').str.replace('\(','').str.replace('\)','')

    SAMPID_2_TISSUE_unique = SAMPID_2_TISSUE.drop_duplicates('SMTSD')  # .drop('SAMPID',axis=1)
    SAMPID_2_TISSUE_unique.rename(columns={'SMTSD':'tissue'},inplace=True)





    UMLS_CUI_CODEs = pd.read_csv(umls_dir+'CUI-CODEs.csv')

    umls_genes = UMLS_CUI_CODEs[UMLS_CUI_CODEs[':END_ID'].str.startswith('HGNC')].rename(
                                        columns={':START_ID':'CUI_hgnc',':END_ID':'HGNC_ID'})

    umls_genes.reset_index(drop=True).to_pickle('HGNC_CUI_CODEs.pickle')





    if LOCAL_CPU: hgnc_master = pd.read_csv('hgnc_master.txt',sep='\t')
    else: hgnc_master =  pd.read_csv(helper_data_dir+'hgnc_master.txt',sep='\t')




    if LOCAL_CPU: eqtl_path =  '/Users/stearb/desktop/R03_local/data/gtex/GTEx_Analysis_v8_eQTL/egenes/'
    else: eqtl_path =  data_dir+'/egenes/'


    eqtl_columns = ['gene_id','gene_name','gene_chr','pval_true_df',
                                     'variant_id','rs_id_dbSNP151_GRCh38p7']


    eqtl = pd.DataFrame(columns=eqtl_columns)

    tissue_eqtl_dict = {}


    for i,filename in enumerate(os.listdir(eqtl_path)):

        tissue = filename.split(".")[0].replace('_',' ') # get tissue name from filename

        df = pd.read_csv(eqtl_path+filename,'\t')[eqtl_columns] # import and select columns

        df['tissue'] = [tissue]*df.shape[0] # add tissue type to tissue col.


        tissue_eqtl_dict[tissue] = df.shape[0]

        if i == 0: eqtl=df # initialize eqtl dataframe if its the
        else:  eqtl = eqtl.append(df)

            

    eqtl_ub  = pd.merge(left=SAMPID_2_TISSUE_unique,
                                         right=eqtl,
                                         on='tissue',
                                         how='right')

    assert eqtl_ub.shape == eqtl_ub.dropna().shape

    eqtl_ub.rename(columns={'gene_name': 'symbol'},inplace=True)

    eqtl_ub['SAB'] = 'GTEX_EQTL'

    eqtl_ub['gene_chr'] = eqtl_ub['gene_chr'].str.replace('chr','')


    eqtl_ub.rename(columns={'SMUBRID':'UBERON_code'},inplace=True)



    eqtl_HGNC  = eqtl_ub[eqtl_ub['symbol'].isin(hgnc_master['symbol'])]

    eqtl_noHGNC  = eqtl_ub[~eqtl_ub['symbol'].isin(hgnc_master['symbol'])]





    eqtl_HGNC_merged = pd.merge(left=hgnc_master[['symbol','hgnc_id']],
                             right=eqtl_HGNC,
                             on='symbol',
                             how='left').dropna()

    assert eqtl_HGNC_merged.shape[0] == eqtl_HGNC.shape[0]


    umls_genes['hgnc_id'] = [i.split(' ')[1] for i in umls_genes['HGNC_ID']]
    umls_genes.drop('HGNC_ID',axis=1,inplace=True)
    umls_genes[['CUI_hgnc','hgnc_id']].rename(columns={'CUI_hgnc':'CUI_human'},inplace=True)




    eqtl_HGNC_merged_2 = pd.merge(left=umls_genes,right=eqtl_HGNC_merged,on='hgnc_id')#,how='outer')#,indicator=True)



    eqtl_noHGNC['hgnc_id'] = np.nan
    eqtl_noHGNC['CUI_hgnc'] = np.nan

    eqtl_all_GTEx = pd.concat([eqtl_HGNC_merged_2,eqtl_noHGNC])

    UMLS_CODE_SUIs = pd.read_csv(umls_dir+'CODE-SUIs.csv')
    UMLS_CODE_SUIs.rename(columns={':START_ID':'CODE',':END_ID':'SUI'},inplace=True)

    UBERON_CODE_SUIs = UMLS_CODE_SUIs[UMLS_CODE_SUIs['CODE'].str.contains('UBERON')]

    UBERON_CODE_SUIs_PT = UBERON_CODE_SUIs[UBERON_CODE_SUIs[':TYPE'] == 'PT']

    UBERON_CODE_SUIs_PT['CODE'] = [i.split(' ')[1] for i in UBERON_CODE_SUIs_PT['CODE']]


    umls_uberon = UBERON_CODE_SUIs_PT[['CODE','CUI']].rename(
        columns={'CODE':'UBERON_code','CUI':'UBERON_CUI'})


    eqtl_all_GTEx = eqtl_all_GTEx[~eqtl_all_GTEx['UBERON_code'].str.contains('EFO')]


    umls_uberon_xref = umls_uberon


    eqtl_all_GTEx = pd.merge(left=eqtl_all_GTEx,right=umls_uberon_xref,on='UBERON_code')

    assert eqtl_all_GTEx.shape[0] == eqtl_all_GTEx.shape[0]



    eqtl_all_GTEx = eqtl_all_GTEx[eqtl_all_GTEx['rs_id_dbSNP151_GRCh38p7'] != '.']


    eqtl_all_GTEx['unique_hash_string'] = eqtl_all_GTEx['rs_id_dbSNP151_GRCh38p7'] + ':' +                                 eqtl_all_GTEx['tissue']     + ':' +                                       eqtl_all_GTEx['symbol'] 

    eqtl_all_GTEx.rename(columns={'unique_hash_string':'CODE_gtex'},inplace=True)


    eqtl_all_GTEx.drop_duplicates('CODE_gtex',inplace=True)



    eqtl_all_GTEx['CodeID'] = ['GTEX_EQTL '+i for i in eqtl_all_GTEx['CODE_gtex']]



    eqtl_all_GTEx['CUI'] = CUIbase64(eqtl_all_GTEx['CodeID'])
    assert eqtl_all_GTEx['CUI'].isna().sum() == 0


    assert eqtl_all_GTEx['CODE_gtex'].nunique() == len(eqtl_all_GTEx)
    assert eqtl_all_GTEx['CODE_gtex'].unique().shape == eqtl_all_GTEx['CodeID'].unique().shape 
    assert  eqtl_all_GTEx['CODE_gtex'].unique().shape== eqtl_all_GTEx['CUI'].unique().shape

    eqtl_all_GTEx.rename(columns={'CUI':'CUI_gtex','CodeID':'CodeID_gtex'},inplace=True)



    eqtl_all_GTEx['CodeID_snp'] = ['DBSNP_151 '+ i for i in eqtl_all_GTEx['rs_id_dbSNP151_GRCh38p7']]

    eqtl_all_GTEx['CUI_snp'] = CUIbase64(eqtl_all_GTEx['CodeID_snp'])

    assert  len(eqtl_all_GTEx['CUI_snp'].unique()) == len(eqtl_all_GTEx['rs_id_dbSNP151_GRCh38p7'].unique())

    assert len(set(eqtl_all_GTEx['CUI_gtex']).intersection(set(eqtl_all_GTEx['CUI_snp']))) ==  0


    assert eqtl_all_GTEx['CUI_gtex'].shape[0] == len(eqtl_all_GTEx['CUI_gtex'].unique())


    CUIs_all_eqtl = eqtl_all_GTEx['CUI_gtex'].append(eqtl_all_GTEx['CUI_snp'].drop_duplicates()) 


    assert eqtl_all_GTEx['CodeID_gtex'].shape[0] == len(eqtl_all_GTEx['CodeID_gtex'].unique())


    dbsnp_codes  = eqtl_all_GTEx[['CodeID_snp','rs_id_dbSNP151_GRCh38p7']]
    dbsnp_codes['SAB'] = 'DBSNP_151'
    dbsnp_codes = dbsnp_codes[['CodeID_snp', 'SAB','rs_id_dbSNP151_GRCh38p7']]

    dbsnp_codes.rename(columns={'CodeID_snp':'CodeID','rs_id_dbSNP151_GRCh38p7':'CODE'},inplace=True)

    gtex_codes = eqtl_all_GTEx[['CodeID_gtex','SAB','CODE_gtex']]
    gtex_codes.rename(columns={'CodeID_gtex':'CodeID','CODE_gtex':'CODE'},inplace=True)

    gtex_codes_eqtl = gtex_codes.append(dbsnp_codes.drop_duplicates())




    GTEX_eqtl_CUI_CODEs = pd.DataFrame(np.concatenate([eqtl_all_GTEx[['CUI_gtex','CodeID_gtex']].values,
                                 eqtl_all_GTEx[['CUI_snp','CodeID_snp']].values]),columns=['CUI','CODE']).drop_duplicates()

    assert len(set(GTEX_eqtl_CUI_CODEs['CODE']).intersection(set(gtex_codes_eqtl['CodeID']))) == len(gtex_codes_eqtl)




    CUI_eqtls_hgnc = eqtl_all_GTEx[['CUI_gtex','CUI_hgnc']].dropna().rename(columns={'CUI_gtex':':START_ID','CUI_hgnc': ':END_ID'})
    CUI_eqtls_hgnc[':TYPE'] = 'eqtl_in_gene'
    CUI_eqtls_hgnc['SAB']  =  'GTEX_EQTL__HGNC'

    CUI_hgnc_eqtls = eqtl_all_GTEx[['CUI_hgnc','CUI_gtex']].dropna().rename(columns={'CUI_gtex':':END_ID','CUI_hgnc': ':START_ID'})
    CUI_hgnc_eqtls[':TYPE'] = 'gene_has_eqtl'
    CUI_hgnc_eqtls['SAB']  =  'GTEX_EQTL__HGNC'


    CUI_eqtls_uberon = eqtl_all_GTEx[['CUI_gtex','UBERON_CUI']].rename(columns={'CUI_gtex':':START_ID','UBERON_CUI': ':END_ID'}) 
    CUI_eqtls_uberon[':TYPE'] = 'eqtl_in_tissue'
    CUI_eqtls_uberon['SAB']  =  'GTEX_EQTL__UBERON'

    CUI_uberon_eqtls = eqtl_all_GTEx[['UBERON_CUI','CUI_gtex']].rename(columns={'CUI_gtex':':END_ID','UBERON_CUI': ':START_ID'}) 
    CUI_uberon_eqtls[':TYPE'] = 'tissue_has_eqtl'
    CUI_uberon_eqtls['SAB']  =  'GTEX_EQTL__UBERON'


    CUI_eqtls_variant = eqtl_all_GTEx[['CUI_gtex','CUI_snp']].rename(columns={'CUI_gtex':':START_ID','CUI_snp': ':END_ID'}) 
    CUI_eqtls_variant[':TYPE'] = 'eqtl_in_variant'
    CUI_eqtls_variant['SAB']  =  'GTEX_EQTL__DBSNP_151'

    CUI_variant_eqtls = eqtl_all_GTEx[['CUI_snp','CUI_gtex']].rename(columns={'CUI_gtex':':START_ID','CUI_snp': ':END_ID'}) 
    CUI_variant_eqtls[':TYPE'] = 'variant_has_eqtl'
    CUI_variant_eqtls['SAB']  =  'GTEX_EQTL__DBSNP_151'


    CUI_CUI_eqtls = pd.concat([ CUI_eqtls_hgnc,CUI_hgnc_eqtls,
                               CUI_eqtls_uberon,CUI_uberon_eqtls,
                               CUI_eqtls_variant,CUI_variant_eqtls])

    assert 0 == CUI_CUI_eqtls.isna().sum().sum()


    terms_geneIDs = eqtl_all_GTEx[['gene_id','CodeID_gtex']]

    terms_geneIDs['SUI'] = CUIbase64(terms_geneIDs['gene_id'])
    terms_geneIDs['rel'] = 'gene_id'

    assert terms_geneIDs.nunique()['gene_id'] == terms_geneIDs.nunique()['SUI']
    terms_geneIDs.rename(columns={'gene_id':'Term'},inplace=True)



    UMLS_SUIs = pd.read_csv(umls_dir+'SUIs.csv')

    chrom_SUIs = UMLS_SUIs.loc[(UMLS_SUIs['name'].str.startswith('chromosome ').astype(bool)) &                            (UMLS_SUIs['name'].str.len() < 14)]


    chrom_SUIs = chrom_SUIs[~chrom_SUIs['name'].str.contains('p|q|g')]

    mito_chrom = UMLS_SUIs[UMLS_SUIs['name'] == 'mitochondrial chromosome']

    chrom_SUIs = pd.concat([chrom_SUIs,mito_chrom])

    chrom_SUIs = chrom_SUIs.sort_values('name').reset_index(drop=True)
    assert len(chrom_SUIs) == 25

    chrom_SUIs.rename(columns={'SUI:ID':'SUI','name':'gene_chr'},inplace=True)


    chrom_codes = eqtl_all_GTEx[['gene_chr','CodeID_gtex']]

    chrom_codes['gene_chr'] = ['chromosome '+i for i in chrom_codes['gene_chr'].str.lower()]


    terms_chr = pd.merge(chrom_codes,chrom_SUIs,how='inner')

    assert len(chrom_codes) == len(terms_chr) # Check that no rows were lost

    terms_chr['rel'] = 'on_chromosome'

    assert terms_chr.nunique()['gene_chr'] == terms_chr.nunique()['SUI']
    terms_chr.rename(columns={'gene_chr':'Term'}, inplace=True)



    terms_eqtl_location  = eqtl_all_GTEx[['variant_id','CodeID_gtex']]

    terms_eqtl_location['Term'] = [i.split('_')[1] for i in terms_eqtl_location['variant_id']]

    terms_eqtl_location.drop('variant_id',axis=1,inplace=True)

    terms_eqtl_location['rel'] = 'eqtl_location'


    terms_eqtl_location['SUI'] = CUIbase64(terms_eqtl_location['Term'])

    assert terms_eqtl_location.nunique()['Term'] == terms_eqtl_location.nunique()['SUI']





    terms_varid = eqtl_all_GTEx[['variant_id','CodeID_gtex']]

    terms_varid['SUI'] = CUIbase64(terms_varid['variant_id'])
    terms_varid['rel'] = 'variant_id'

    assert terms_varid.nunique()['variant_id'] == terms_varid.nunique()['SUI']
    terms_varid.rename(columns={'variant_id':'Term'},inplace=True)





    terms_rs = eqtl_all_GTEx[['rs_id_dbSNP151_GRCh38p7','CodeID_gtex']]

    terms_rs['SUI'] = CUIbase64(terms_rs['rs_id_dbSNP151_GRCh38p7'])
    terms_rs['rel'] = 'rs_id_dbSNP151_GRCh38p7'

    assert terms_rs.nunique()['rs_id_dbSNP151_GRCh38p7'] == terms_rs.nunique()['SUI']
    terms_rs.rename(columns={'rs_id_dbSNP151_GRCh38p7':'Term'},inplace=True)




    terms_pval = eqtl_all_GTEx[['pval_true_df','CodeID_gtex']]

    bins = [0,1e-12,1e-11,1e-10,1e-9,1e-8,1e-7,1e-6,1e-5,1e-4,1e-3,.005,.01,.02,.03,.04,.05,.06]

    terms_pval['bin'] = pd.cut(terms_pval['pval_true_df'], bins)






    bin_strings_preclip = terms_pval['bin'].astype(str) 

    bin_strings = [i[1:-1].replace(' ','') for i in bin_strings_preclip]





    terms_pval['SUI'] = CUIbase64(pd.Series(bin_strings))


    terms_pval['rel'] = 'p_value'

    assert terms_pval.nunique()['bin'] == terms_pval.nunique()['SUI']

    terms_pval.rename(columns={'bin':'Term'},inplace=True)

    terms_pval['Term'] = [str(i.left)+','+str(i.right) for i in terms_pval['Term']]

    assert terms_pval[terms_pval['Term'] == '1e-11,1e-10']['SUI'].nunique() == 1







    CODE_SUIs = pd.concat([terms_geneIDs,
                           terms_chr,
                           terms_eqtl_location, #terms_start, #terms_end,
                           terms_rs,
                           terms_varid,
                           terms_pval[['Term','CodeID_gtex','SUI','rel']]],axis=0)   #,terms_maf,],axis=0)

    assert CODE_SUIs.nunique()['Term'] == CODE_SUIs.nunique()['SUI']

    GTEX_EQTL_SUIs = CODE_SUIs[['SUI','Term']].rename(columns={'SUI':'SUI:ID','Term':'name'}).drop_duplicates()

    GTEX_EQTL_SUIs = GTEX_EQTL_SUIs[~(GTEX_EQTL_SUIs['SUI:ID'].str.startswith('S') & GTEX_EQTL_SUIs['name'].str.contains('chromosome'))]


    GTEX_EQTL_CODE_SUIs = pd.merge(CODE_SUIs,eqtl_all_GTEx[['CodeID_gtex','CUI_gtex']],on='CodeID_gtex')

    GTEX_EQTL_CODE_SUIs = GTEX_EQTL_CODE_SUIs.rename(columns={'CodeID_gtex':':START_ID','SUI':':END_ID',
                                       'rel':':TYPE','CUI_gtex':'CUI'}).drop('Term',axis=1)



    if LOCAL_CPU:
        gene_median_tpm = '/Users/stearb/desktop/R03_local/data/gtex/GTEx_Analysis_2017-06-05_v8_RNASeQCv1.1.9_gene_median_tpm.gct'
    else:
        gene_median_tpm = data_dir+'GTEx_Analysis_2017-06-05_v8_RNASeQCv1.1.9_gene_median_tpm.gct'

    gct_obj=parse(gene_median_tpm)

    df = gct_obj.data_df



    medgene_flat = df.stack().reset_index().rename(columns={'rid':'Transcript ID',
                                                            'cid':'tissue',0:'Median_TPM'})

    medgene_flat['tissue'] = medgene_flat['tissue'].str.replace(' - ',' ').str.replace('\(','').str.replace('\)','')



    gtx_genes = gct_obj.row_metadata_df['Description'].to_frame()
    gtx_genes['Transcript ID'] = gtx_genes.index
    gtx_genes.rename(columns={'Description':'symbol'},inplace=True)
    gtx_genes.reset_index(drop=True, inplace=True)




    cols2include = ['symbol','hgnc_id','name','locus_group','locus_type','location']
                                            #,'entrez_id','ensembl_gene_id','uniprot_ids']

    symbols_hgnc=pd.merge(left=gtx_genes,right=hgnc_master[cols2include],   # include more gene IDs/gene data here
                               how='inner',
                               on='symbol')#.dropna()#.drop_duplicates('Transcript ID')






    medgene_flat_ub = pd.merge(left=medgene_flat,right=SAMPID_2_TISSUE_unique,on='tissue')




    medgene_merge  = pd.merge(left=medgene_flat_ub,
                         right=symbols_hgnc,
                         how='inner',
                         on='Transcript ID').dropna()



    medgene_merge_2  =  pd.merge(left=umls_genes,right=medgene_merge,on='hgnc_id')


    medgene_merge_2.rename(columns={'SMUBRID':'UBERON_code'},inplace=True)

    medgene_merge_2 = medgene_merge_2[~medgene_merge_2['UBERON_code'].str.contains('EFO')]


    umls_uberon_xref_2 = umls_uberon_xref




    umls_uberon_xref_2[umls_uberon_xref_2['UBERON_code'].duplicated() == True]
    umls_uberon_xref_2[umls_uberon_xref_2['UBERON_code'] == '0001676']

    umls_uberon_xref_2[umls_uberon_xref_2['UBERON_code'] == '0004760']

    umls_uberon_xref_2[umls_uberon_xref_2['UBERON_code'] == '0001085']

    medgene_merge_3  =  pd.merge(left=medgene_merge_2,right=umls_uberon_xref_2,on='UBERON_code') 


    median_tpm_strs = [str(i) for i in medgene_merge_3['Median_TPM']]

    medgene_merge_3['CODE_GTEX_Expression'] = medgene_merge_3['Transcript ID'] + ':' +                                           medgene_merge_3['tissue'] + ':' +                                            medgene_merge_3['UBERON_CUI'] +':' +                                            median_tpm_strs

    medgene_merge_3.drop_duplicates('CODE_GTEX_Expression',inplace=True)



    medgene_merge_3['CodeID_GTEX_Expression'] = ['GTEX_EXP '+i for i in medgene_merge_3['CODE_GTEX_Expression']]


    medgene_merge_3['CUI_GTEX_Expression'] = CUIbase64(medgene_merge_3['CodeID_GTEX_Expression'])


    assert len(medgene_merge_3['CODE_GTEX_Expression'].unique()) == medgene_merge_3.shape[0]
    assert medgene_merge_3['CODE_GTEX_Expression'].unique().shape == medgene_merge_3['CodeID_GTEX_Expression'].unique().shape 
    assert  medgene_merge_3['CODE_GTEX_Expression'].unique().shape== medgene_merge_3['CUI_GTEX_Expression'].unique().shape




    medgene_select = medgene_merge_3[['CUI_GTEX_Expression','CODE_GTEX_Expression','CodeID_GTEX_Expression','CUI_hgnc','Median_TPM','UBERON_CUI']]


    GTEX_Ex_CUIs = pd.DataFrame(np.transpose([medgene_select['CUI_GTEX_Expression'].drop_duplicates().values]
                                              ),columns=['CUI:ID']) 

    CUIs_all_eqtl_2=CUIs_all_eqtl.to_frame().rename(columns={0:'CUI:ID'})#,inplace=True)

    CUIs_all = CUIs_all_eqtl_2.append(GTEX_Ex_CUIs)

    assert CUIs_all.shape  == CUIs_all.drop_duplicates().shape 


    CUIs_all.to_pickle(output_dir+'GTEx/CUIs_GTEx.pickle')



    GTEX_Ex_2_HGNC = medgene_select[['CUI_GTEX_Expression','CUI_hgnc']].rename(columns={'CUI_GTEX_Expression':':START_ID','CUI_hgnc':':END_ID'})
    GTEX_Ex_2_HGNC[':TYPE'] = 'median_expression_in_gene'
    GTEX_Ex_2_HGNC['SAB'] = 'GTEX_EXP__HGNC'

    HGNC_2_GTEX_Ex = medgene_select[['CUI_hgnc','CUI_GTEX_Expression']].rename(columns={'CUI_GTEX_Expression':':END_ID','CUI_hgnc':':START_ID'})
    HGNC_2_GTEX_Ex[':TYPE'] = 'gene_has_median_expression'
    HGNC_2_GTEX_Ex['SAB'] = 'GTEX_EXP__HGNC'

    GTEX_Ex_2_UBERON  = medgene_select[['CUI_GTEX_Expression','UBERON_CUI']].rename(columns={'CUI_GTEX_Expression':':START_ID','UBERON_CUI':':END_ID'})
    GTEX_Ex_2_UBERON[':TYPE'] = 'median_expression_in_tissue'
    GTEX_Ex_2_UBERON['SAB'] = 'GTEX_EXP__UBERON'


    UBERON_2_GTEX_Ex  = medgene_select[['UBERON_CUI','CUI_GTEX_Expression']].rename(columns={'CUI_GTEX_Expression':':END_ID','UBERON_CUI':':START_ID'})
    UBERON_2_GTEX_Ex[':TYPE'] = 'tissue_has_median_expression'
    UBERON_2_GTEX_Ex['SAB'] = 'GTEX_EXP__UBERON'


    GTEX_Ex_CUI_CUI = pd.concat([GTEX_Ex_2_HGNC,HGNC_2_GTEX_Ex,GTEX_Ex_2_UBERON,UBERON_2_GTEX_Ex])

    CUI_CUIs_all = pd.concat([GTEX_Ex_CUI_CUI, CUI_CUI_eqtls]) 

    assert CUI_CUIs_all.duplicated().sum() == 0


    CUI_CUIs_all.to_pickle(output_dir+'GTEx/CUI_CUI_GTEx.pickle')



    GTEX_Ex_CODEs = medgene_select[['CodeID_GTEX_Expression','CODE_GTEX_Expression']].rename(columns={'CodeID_GTEX_Expression':'CodeID',
                                                                                       'CODE_GTEX_Expression':'CODE'})
    GTEX_Ex_CODEs['SAB'] = 'GTEX_EXP'

    GTEX_Ex_CODEs = GTEX_Ex_CODEs[['CodeID','SAB','CODE']]

    CODEs_all = pd.concat([GTEX_Ex_CODEs,gtex_codes_eqtl])

    assert CODEs_all.shape == CODEs_all.drop_duplicates().shape
    assert CODEs_all.nunique()['CodeID'] == CODEs_all.nunique()['CODE']


    CODEs_all.to_pickle(output_dir+'GTEx/CODEs_GTEx.pickle')


    GTEX_Ex_CUI_CODE  = medgene_select[['CUI_GTEX_Expression',
                                        'CodeID_GTEX_Expression']].rename(columns={'CUI_GTEX_Expression':'CUI',
                                                                                   'CodeID_GTEX_Expression':'CODE'})
    GTEX_CUI_CODEs_all  = pd.concat([GTEX_Ex_CUI_CODE,GTEX_eqtl_CUI_CODEs])

    assert GTEX_CUI_CODEs_all.shape == GTEX_CUI_CODEs_all.drop_duplicates().shape

    assert set() == set(GTEX_eqtl_CUI_CODEs['CUI']).intersection(set(GTEX_Ex_CUI_CODE['CUI']))


    GTEX_CUI_CODEs_all.to_pickle(output_dir+'GTEx/CUI_CODEs_GTEx.pickle')


    tpm_bins = list([0.0000000,7e-4,8e-4,9e-4]) + list(np.linspace(1e-3,9e-3,9)) +            list(np.round(np.linspace(1e-2,9e-2,9),2)) + list(np.round(np.linspace(.1,1,10),2)) +            list(np.linspace(2,100,99)) + list(np.arange(100,1100,100)[1:]) +              list(np.arange(2000,11000,1000)) + list(np.arange(20000,110000,10000)) + [300000]

    tpm_0s = medgene_select[medgene_select['Median_TPM'] == 0.00] 
    tpm_intervals = medgene_select[medgene_select['Median_TPM'] != 0.00] 

    tpm_intervals['tpm_bins'] = pd.cut(tpm_intervals['Median_TPM'], tpm_bins)


    bin_strings_exp_preclip = tpm_intervals['tpm_bins'].astype(str)


    bin_strings_exp = [i[1:-1].replace(' ','') for i in bin_strings_exp_preclip]

    tpm_intervals['SUI_tpm_bins'] = CUIbase64(pd.Series(bin_strings_exp))


    tpm_intervals['bins_lowerbound'] = [i.left if type(i) is not float else 0.0 for i in tpm_intervals['tpm_bins'] ]
    tpm_intervals['bins_upperbound'] = [i.right if type(i) is not float else 0.0 for i in tpm_intervals['tpm_bins'] ]

    tpm_intervals.drop('tpm_bins',axis=1,inplace=True)



    bin_strings_exp_0 = tpm_0s['Median_TPM'].astype(str)

    tpm_0s['SUI_tpm_bins'] = CUIbase64(bin_strings_exp_0)

    tpm_0s['bins_upperbound'] = 0.0
    tpm_0s['bins_lowerbound'] = 0.0

    tpm_all_intervals =  pd.concat([tpm_intervals,tpm_0s]).reset_index(drop=True)




    tpm_all_intervals['name'] = tpm_all_intervals['bins_lowerbound'].astype(str) +','+ tpm_all_intervals['bins_upperbound'].astype(str)

    tpm_all_intervals.drop(['bins_lowerbound','bins_upperbound'],axis=1,inplace=True)


    GTEX_EXP_SUIs = tpm_all_intervals[['SUI_tpm_bins','name']].rename(columns={'SUI_tpm_bins':'SUI:ID'
                                                                   }).drop_duplicates()

    GTEX_SUIs = pd.concat([GTEX_EXP_SUIs,GTEX_EQTL_SUIs]).drop_duplicates()

    assert len(GTEX_SUIs[GTEX_SUIs['SUI:ID'].duplicated()]) == 0


    GTEX_SUIs.to_pickle(output_dir+'GTEx/SUIs_GTEx.pickle')

    GTEX_EXP_CODE_SUIs = tpm_all_intervals[['CodeID_GTEX_Expression',
                                         'SUI_tpm_bins',
                                         'CUI_GTEX_Expression']].rename(columns={
                                                                'CodeID_GTEX_Expression':':START_ID',
                                                                'SUI_tpm_bins':':END_ID',
                                                                'CUI_GTEX_Expression':'CUI'}).drop_duplicates()


    GTEX_EXP_CODE_SUIs[':TYPE'] = 'TPM'

    GTEX_CODE_SUIs= pd.concat([GTEX_EQTL_CODE_SUIs,GTEX_EXP_CODE_SUIs])

    GTEX_CODE_SUIs.to_pickle(output_dir+'GTEx/CODE_SUIs_GTEx.pickle')


