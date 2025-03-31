# connect to database
library(DBI)
library(RMySQL)

con = dbConnect(MySQL(), 
                host = 'localhost',
                dbname = 'sctu_sqldb',
                user = 'root',
                password = rstudioapi::askForPassword("Database password"))

dbGetQuery(con, 'describe study')

################################################################################

# Install required libraries (if not installed)
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

# Load libraries
library(GEOquery)
library(Biobase)

# Start by creating Study-level info
idStudy <- 0
studyName <- 'GSE37250'
Disease <- 'Tuberculosis'

# insert basic study information
query <- sprintf(
  "INSERT INTO study (idStudy, studyName, Disease) VALUES (%d, '%s', '%s')",
  idStudy, studyName, Disease
)

# dbExecute(con, query)

dbDisconnect(con)

# reload and create dataset table
con = dbConnect(MySQL(), 
                host = 'localhost',
                dbname = 'sctu_sqldb',
                user = 'root',
                password = rstudioapi::askForPassword("Database password"))


query <- sprintf(
  "INSERT INTO dataset (Study_idStudy, OmicsDataType, Tissue, Date, Instrument) VALUES (%d, '%s', '%s', '%s', '%s')",
  10, 'RNA-seq', 'whole blood', '2012-04-13', 'Illumina Human HT-12 Beadchips'
)

# dbExecute(con, query)

# Load GEO Data as Expression Set Object
oExp <- getGEO(filename = 'dataExternal/GSE37250_series_matrix.txt.gz', 
               getGPL = FALSE)

saveRDS(oExp, 'GSE37250_ExpressionSet.Rds')


dbDisconnect(con)
