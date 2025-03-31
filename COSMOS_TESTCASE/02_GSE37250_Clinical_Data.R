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
sample_info

## Segregate Clinical Characteristics
disease_state <- sample_info$characteristics_ch1
hiv_status <- sample_info$characteristics_ch1.1
geographical_region <- sample_info$characteristics_ch1.2

## Clean Data
disease_state <- factor(disease_state,
                        levels = c("disease state: active tuberculosis",
                                   "disease state: latent TB infection",
                                   "disease state: other disease"),
                        labels = c("ATB", "LTB", "Other"))

hiv_status <- factor(hiv_status,
                     levels = c("hiv status: HIV positive",
                                "hiv status: HIV negative"),
                     labels = c("positive", "negative"))

geographical_region <- factor(geographical_region,
                              levels = c("geographical region: South Africa",
                                         "geographical region: Malawi"),
                              labels = c("South Africa", "Malawi"))

# sense check
disease_state
hiv_status
geographical_region

## attach back to sample_info to use for clincialdata tables
sample_info$disease_state = disease_state
sample_info$hiv_status = hiv_status
sample_info$geographical_region = geographical_region


################################################################################

## describe the clinical data table
dbGetQuery(con, 'desc clinicaldata') #Type, Value, Subject_idUnit, Study_idUnit, Description

## prep dataframe for insert
df = dbGetQuery(con, 'select * from subject where Visit = 0 and Study_idStudy = 10')

dfClin = data.frame(Type = 'Visit_type',
                    Value = 'Cross-sectional',
                    Subject_idUnit = df$idUnit,
                    Study_idStudy = df$Study_idStudy,
                    Description = 'All data is cross-sectional'
                    )

table(duplicated.data.frame(dfClin)) # sense check

#dbWriteTable(con, name = 'clinicaldata', 
#             value = dfClin, append = T, row.names = F)

## lets check that here
## you should see the new type added
## along with its value
dbGetQuery(con, 'select * from clinicaldata') 

# now to repeat with the other clinical data.
# reload data
df = dbGetQuery(con, 'select * from subject where Visit = 0 and Study_idStudy = 10')
dfChar1 = data.frame(Type = 'Disease_state',
                    Value = gsub(' ', '', sample_info$disease_state),
                    Subject_idUnit = df$idUnit,
                    Study_idStudy = df$Study_idStudy,
                    Description = 'Subject Characteristics - Disease State')

#dbWriteTable(con, name = 'clinicaldata', value = dfChar1, 
#             append = T, row.names = F)


df = dbGetQuery(con, 'select * from subject where Visit = 0 and Study_idStudy = 10')
dfChar2 = data.frame(Type = 'hiv_status',
                     Value = gsub(' ', '', sample_info$hiv_status),
                     Subject_idUnit = df$idUnit,
                     Study_idStudy = df$Study_idStudy,
                     Description = 'Subject Characteristics - HIV Status')

#dbWriteTable(con, name = 'clinicaldata', value = dfChar2, 
#             append = T, row.names = F)

df = dbGetQuery(con, 'select * from subject where Visit = 0 and Study_idStudy = 10')
dfChar3 = data.frame(Type = 'Geographical_region',
                     Value = gsub(' ', '', sample_info$geographical_region),
                     Subject_idUnit = df$idUnit,
                     Study_idStudy = df$Study_idStudy,
                     Description = 'Subject Characteristics - Geographical Region')

#dbWriteTable(con, name = 'clinicaldata', value = dfChar3, 
#             append = T, row.names = F)


# sense check what we have just done
dbGetQuery(con, 'select * from clinicaldata')


dbDisconnect(con)
