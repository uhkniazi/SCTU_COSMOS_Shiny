# File: level1_prep.R
# Auth: u.niazi@soton.ac.uk
# DESC: expression set object prep for DB
# Date: 4/4/2025

######## 

source('00_cosmosDB_utilities.R')

db = cosmos_login()
cosmos_showStudies(db)

dbGetQuery(db, 'select * from dataset where Study_idStudy=10')

library(Biobase)

idDataSet=4

oExp = readRDS('Level1Data/GSE37250.rds')
dim(oExp)

dfPdata = pData(oExp)

head(dfPdata)

## first populate the metadata table
dfDB = cosmos_showPatients(db, 10)

head(dfDB)

#### this data set is from only one time point i.e. cross-sectional
table(dfDB$Visit_type)
dfDB = dfDB[dfDB$Visit_type == 'Cross-sectional', ]
dim(dfDB)

cSampleNames = rownames(dfPdata)

dfOS = dbGetQuery(db, 'select * from omicssample where dataset_idDataset=4')
dim(dfOS)
head(dfOS)

## merge the two tables from omicssample and patient tables
dfMerged = merge.data.frame(dfOS, dfDB, by.x = 'Subject_idUnit', by.y = 'idUnit')
dim(dfMerged); dim(dfOS); dim(dfDB)

table(duplicated.data.frame(dfMerged))
table(duplicated(dfMerged$Subject_idUnit))

iSampleNames = as.numeric(gsub('GSM', '', cSampleNames))
identical(iSampleNames, as.numeric(dfMerged$idAnonymised))
dfMerged$SampleName = cSampleNames

### fill out the OmicsSampleMetaData table
dfDB_OSMD = data.frame(Type='SampleName',
                       Value=dfMerged$SampleName,
                       OmicsSample_idOmicsSample=dfMerged$idOmicsSample,
                       Description='Sample names given to each sample in GSE37250 data')

dim(dfDB_OSMD)
table(duplicated(dfDB_OSMD$OmicsSample_idOmicsSample))
head(dfDB_OSMD)
## fill this data and get from DB again to update
## do this inside mysql workbench SET GLOBAL local_infile = 'ON';
#dbWriteTable(db, name='omicssamplemetadata', value = dfDB_OSMD, append=T, row.names=F)

dbDisconnect(db)

################ refresh and load again

source('00_cosmosDB_utilities.R')
con = cosmos_login()
cwd = getwd()


### use multi-join query to extract data and merge from
### multiple tables
dfDB = dbGetQuery(con, "select * from subject
inner join
(select * from clinicaldata where Type = 'Visit_type' and Study_idStudy = 10) as cd_sub
on subject.idUnit = cd_sub.Subject_idUnit
inner join omicssample
on subject.idUnit = omicssample.Subject_idUnit
inner join omicssamplemetadata
on omicssample.idOmicsSample = omicssamplemetadata.OmicsSample_idOmicsSample
where omicssample.Dataset_idDataset = 4
and omicssamplemetadata.Type like 'SampleName'")

dim(dfDB)
head(dfDB)

## create a sample info table
dfSample = data.frame(Pt_idAnonymised=dfDB$idAnonymised,
                      SampleName=dfDB[,16],
                      TimePoint=dfDB[,7],
                      DB_Subject_idUnit=dfDB$Subject_idUnit,
                      DB_Omics_Sample_id=dfDB$idOmicsSample)


head(dfSample)

rownames(dfSample) = dfSample$SampleName

oExp = readRDS('Level1Data/GSE37250.rds')
dim(oExp)

mData = exprs(oExp)
dim(mData)

mData[1:10, 1:5]

## make sure the order on the sample table and data matrix are the same
i = match(colnames(mData), dfSample$SampleName)
### make sure this is true
(identical(colnames(mData), as.character(dfSample$SampleName)))

identical(colnames(mData), rownames(dfSample))
dfFeatureData = fData(oExp)
head(dfFeatureData)

oExp.2 = ExpressionSet(assayData = mData, 
                     phenoData = as(dfSample, 'AnnotatedDataFrame'), 
                     featureData = as(dfFeatureData, 'AnnotatedDataFrame'))

dim(oExp.2)

saveRDS(oExp.2, file='Level1Data/GSE37250_dataID_4.rds')
### enter the information into database table for datalevel1 
dbDisconnect(con)
