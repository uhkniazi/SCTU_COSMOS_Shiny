
# connect to database
library(DBI)
library(RMySQL)

con = dbConnect(MySQL(), 
                host = 'localhost',
                dbname = 'sctu_sqldb',
                user = 'root',
                password = rstudioapi::askForPassword("Database password"))


# Read in Expression Set Object
oExp = readRDS('GSE37250_ExpressionSet.Rds')


sample_info <- pData(oExp)
head(sample_info) #sense check
dim(sample_info) # check that it captures all 537 participants

subject_id = sample_info$geo_accession
subject_id # id needs to be an integer

# Remove 'GSM' prefix
subject_id <- as.integer(gsub("GSM", "", subject_id))

# sense check
subject_id

# create Visit Number - irrelevant here so mark as 0
Visit = 0

# Insert subject IDs in a loop
for (i in seq_along(subject_id)) {
  query <- sprintf(
    "INSERT INTO subject (idAnonymised, Visit, Study_idStudy) VALUES (%d, %d, %d)",
    subject_id[i], Visit, 10 # where studyID = 10
  )
  
  # Debugging step
  print(query)  # See the queries being executed
  
#  dbExecute(con, query)
}

dbDisconnect(con)

