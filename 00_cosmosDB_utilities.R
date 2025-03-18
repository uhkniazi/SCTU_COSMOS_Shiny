# Name: 00_cosmosDB_utilities.R
# Auth: u.niazi@soton.ac.uk
# Date: 28/05/2024
# Desc: a collection of utility functions that can be make it easier to query the db

## copied from https://github.com/uhkniazi/SCTU_COSMIC_DB/blob/d1bc64d3119d99b1107ce0ad62ddd712847bde61/00_cosmosDB_utilities.R#L1
## updated on 11-DEC-2024
## note: added get all clinical data query

#### please see here if you get some errors like
# Error: nanodbc/nanodbc.cpp:3170: 07009
# [Microsoft][ODBC SQL Server Driver]Invalid Descriptor Index 
# Warning message:
#   In dbClearResult(rs) : Result already cleared
## https://stackoverflow.com/questions/45001152/r-dbi-odbc-error-nanodbc-nanodbc-cpp3110-07009-microsoftodbc-driver-13-fo
## you can work around it by changing the index of the longer columns to be towards the end of the query

### log in
cosmos_login = function(database = 'cosmos_shiny_demo'){
  # connect to MySQL database using RMySQL
  library(DBI)
  library(RMySQL)
  
  con = DBI::dbConnect(RMySQL::MySQL(),
                       user = rstudioapi::askForPassword("Database user"),
                       password = rstudioapi::askForPassword("Database password"),
                       host = '127.0.0.1', # Replace with your MySQL host
                       dbname = database)
  return(con)
}

### get a list of studies
cosmos_showStudies = function(dbCon){
  dbGetQuery(dbCon, "select idStudy, StudyName, Disease from study")
}

### use the study id to find related level 1 data sets
cosmos_showOmicsData = function(dbCon, studyID){
  if (is.null(studyID)) stop('Error Give study ID')
  dbGetQuery(dbCon, paste("select idDataset, Study_idStudy, OmicsDataType, 
                          Tissue, idDataLevel1, dl1.Type, dl1.FileName, 
                          dl1.Location from dataset inner join 
                          datalevel1 dl1 on 
                          dataset.idDataset = dl1.Dataset_idDataset
                          where dataset.Study_idStudy =",  studyID))
}

### use study id to find all available subjects and time points
cosmos_showPatients = function(dbCon, studyID){
  if (is.null(studyID)) stop('Error Give study ID')
  
  ## save result and use appropriate column names
  df = dbGetQuery(dbCon, paste("select subject.Study_idStudy, idUnit, idAnonymised,
  cd.idClinicalData, cd.Type, cd.Value, cd.Description from subject inner join
  clinicaldata cd on subject.idUnit = cd.Subject_idUnit where 
  subject.Study_idStudy =", studyID, "and cd.Type='Visit_type'"))
  
  if (nrow(df) == 0) stop('No matching study')
  
  i = which(colnames(df) == 'Value')
  colnames(df)[i] = df[1, 'Type']
  i = which(colnames(df) == 'Type')
  df = df[, -i]
  return(df)
}

## get a list of all available clinical variables
cosmos_showAvailableClinicalData = function(dbCon, studyID){
  if (is.null(studyID)) stop('Error Give study ID')
  
  dbGetQuery(dbCon, paste("select count(*) counts, Type, Description from 
  clinicaldata where Study_idStudy =", studyID, "and Type is not null
                          group by Type, Description order by Type"))
}

## get a list of all available metadata for omics samples associated with dataset
cosmos_showAvailableOmicsMetadata = function(dbCon, dataID){
  if (is.null(dataID)) stop('Error Give omics dataset ID')
  
  dbGetQuery(dbCon, paste("select count(*) counts, Type, Description,
  os.Dataset_idDataset idDataset from omicssamplemetadata inner join 
  (select * from omicssample where omicssample.Dataset_idDataset =", dataID, ")
  as os on omicssamplemetadata.OmicsSample_idOmicsSample = os.idOmicsSample 
                          group by omicssamplemetadata.Type,
                          omicssamplemetadata.Description, os.Dataset_idDataset"))
}

## get clinical data of specific type given study id
cosmos_getClinicalDataForStudy = function(dbCon, studyID, clinicalData){
  if (is.null(studyID)) stop('Error give study id')
  if (is.null(clinicalData)) stop('Error give clinical data type')
  
  df = dbGetQuery(dbCon, paste0("select subject.Study_idStudy idStudy, idUnit, idAnonymised, 
  cd.Value timepoint, cd.Description timepoint_des, 
  cd2.Type, cd2.Value, cd2.Description from subject 
  inner join clinicaldata cd 
  on subject.idUnit = cd.Subject_idUnit 
  inner join clinicaldata cd2 
  on subject.idUnit = cd2.Subject_idUnit 
  where subject.Study_idStudy =", studyID, "and cd.Type='Visit_type' 
  and cd2.Type='", clinicalData, "'"))
  
  # rearrange column names, tidy up
  i = which(colnames(df) == 'Value')
  colnames(df)[i] = df[1, 'Type']
  i = which(colnames(df) == 'Type')
  df = df[, -i]
  return(df)
}

## get all clinical data for specific study
## this table can be very large in size
cosmos_getAllClinicalDataForStudy = function(dbCon, studyID){
  ## read all the available clinical data first
  dfAllData = cosmos_showAvailableClinicalData(dbCon, studyID)
  ## sanity check if there is any data
  if (nrow(dfAllData) == 0) stop('Error - no clinical data for given study id')
  
  ## remove visit types first, as this is filled separately later
  i = which(dfAllData$Type %in% c('Visit_type'))
  dfAllData = dfAllData[-i, ]
  
  dfTime = cosmos_getClinicalDataForStudy(dbCon, studyID, 'Visit_type')
  dfTime = dfTime[, c('idStudy', 'idUnit', 'idAnonymised', 'Visit_type', 'Description')]
  
  ## fill the rest of the clinical variables one at a time
  for (i in 1:nrow(dfAllData)){
    cType = dfAllData[i, 'Type']
    dfData = cosmos_getClinicalDataForStudy(dbCon, studyID, cType)
    dfData = dfData[,c('idUnit', cType)]
    dfTime = merge.data.frame(dfTime, dfData, by='idUnit', all.x=T) # doing left outer join
  }
  return(dfTime)
}



## get clinical data of specific type given omics/translational data set
## NOTE: if the clinical data does not exist for the time point matching
## with the omics data time point, the query will return empty
cosmos_getMatchingTimePointClinicalDataForOmics = function(dbCon, dataID, clinicalData){
  if (is.null(dataID)) stop('Error give dataset id')
  if (is.null(clinicalData)) stop('Error give clinical data type')
  
  df = dbGetQuery(dbCon, 
                  paste0("select subject.Study_idStudy idStudy, 
                  omicssample.Dataset_idDataset idDataset, 
                  omicssample.idOmicsSample, osd1.Value SampleName,
                  omicssample.Subject_idUnit idUnit, 
                  subject.idAnonymised, cd1.Value timepoint, 
                  cd1.Description timepoint_des, 
                  cd2.Value ", clinicalData, ", cd2.Description
                  from omicssample 
                  inner join subject 
                  on omicssample.Subject_idUnit = subject.idUnit 
                  inner join 
                  (select * from clinicaldata where Type='Visit_type') as cd1 
                  on omicssample.Subject_idUnit = cd1.Subject_idUnit 
                  inner join (select * from clinicaldata where 
                  Type='", clinicalData, "') as cd2 
                  on omicssample.Subject_idUnit = cd2.Subject_idUnit 
                  inner join (select * from omicssamplemetadata where
                  Type='SampleName') as osd1 on 
                  omicssample.idOmicsSample = osd1.OmicsSample_idOmicsSample 
                  where omicssample.Dataset_idDataset = ", dataID, ""))
  
  return(df)
}

## get clinical data of specific type given omics/translational data set
## NOTE: if the clinical data does exists for ANY time point by matching the
## Omics Sample IDs, Subject anonymised id (regardless of the actual time point
## the omics sample was taken) it will be reported
cosmos_getAnyTimePointClinicalDataForOmics = function(dbCon, dataID, clinicalData){
  if (is.null(dataID)) stop('Error give dataset id')
  if (is.null(clinicalData)) stop('Error give clinical data type')
  df = dbGetQuery(dbCon, 
                  paste0("select subject.Study_idStudy idStudy, 
                  os.Dataset_idDataset idDataset, 
                  os.idOmicsSample idOmicsSample, 
                  os.Subject_idUnit idUnit_omics, 
                  subject.idAnonymised idAnonymised, 
                  cdvisit.Value omics_timepoint, 
                  sub2.idUnit idUnit_matched_timepoint, 
                  cdvisit2.Value clinical_timepoint, 
                  cdsel.Value ", clinicalData, " from subject 
                  inner join omicssample os 
                  on subject.idUnit = os.Subject_idUnit 
                  inner join 
                  (select * from clinicaldata where Type like 'Visit%') as cdvisit 
                  on os.Subject_idUnit = cdvisit.Subject_idUnit 
                  inner join 
                  (select * from subject) as sub2 
                  on subject.idAnonymised = sub2.idAnonymised 
                  inner join 
                  (select * from clinicaldata where Type like 'Visit%') as cdvisit2 
                  on sub2.idUnit = cdvisit2.Subject_idUnit 
                  inner join 
                  (select * from clinicaldata where Type='", clinicalData,"') as cdsel 
                  on sub2.idUnit = cdsel.Subject_idUnit where 
                         os.Dataset_idDataset=", dataID))
  return(df)
}


## get all available clinical data for a subject
## sorted by time point
cosmos_getAllClinicalDataForSubject = function(dbCon, studyID, idAnonymised){
  if (is.null(studyID)) stop('Error give study id')
  if (is.null(idAnonymised)) stop('Error give anonymised subject id')
  
  df = dbGetQuery(dbCon, 
                  paste0("select subject.Study_idStudy idStudy, 
                  idAnonymised, cdv.Value timepoint, 
                  cdv.Description timepoint_des, 
                  notcdv.Type, notcdv.Value, notcdv.Description 
                  from subject 
                  inner join
                  (select * from clinicaldata where Type like 'visit%') cdv 
                  on subject.idUnit = cdv.Subject_idUnit 
                  inner join
                  (select * from clinicaldata where Type not like 'visit%') notcdv
                  on subject.idUnit = notcdv.Subject_idUnit 
                  where subject.idAnonymised = ", idAnonymised, 
                         " and subject.Study_idStudy = ", studyID, " order by cdv.Value"))
  return(df)
}
