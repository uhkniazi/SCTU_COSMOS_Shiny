#--------------------------------------------------
#        prep data for forming rds object         
#__________________________________________________



# connect to database
library(DBI)
library(RMySQL)

con = dbConnect(MySQL(), 
                host = 'localhost',
                dbname = 'sctu_sqldb',
                user = 'root',
                password = rstudioapi::askForPassword("Database password"))

# load in packages to add gene annotations
library(Biobase)
library(AnnotationDbi)
library(illuminaHumanv4.db) # as our data is HumanHT-12 arrays

# Read in Expression Set Object
oExp = readRDS('GSE37250_ExpressionSet.Rds')

# convert ExpressionSet to a df
expr_data <- as.data.frame(exprs(oExp))
head(expr_data, n = c(1000, 5))

# alter the column names to match the subject IDs we have in the db
colnames(expr_data) <- gsub("GSM", "", colnames(expr_data))

# add Probe IDs as a new column
# we are using illumina probe IDs
# these therefore will need to mapped to gene names later in the pipeline
expr_data$PROBE_ID <- rownames(expr_data)
head(expr_data)


# Add Gene Annotations
annotations <- select(illuminaHumanv4.db,
                      keys = expr_data$PROBE_ID,
                      columns = c("SYMBOL", "GENENAME"),
                      keytype = "PROBEID")

# Merge Annotations
annotated_data <- merge(expr_data, annotations, by.x = "PROBE_ID", 
                        by.y = "PROBEID", all.x = T)

# extract gene symbols
gene_symbols <- annotated_data$SYMBOL
head(gene_symbols)

# Count missing gene symbols
sum(is.na(gene_symbols))  # 11634
annotated_data <- na.omit(annotated_data)

# re-extract and count missing gene symbols again
gene_symbols <- annotated_data$SYMBOL
head(gene_symbols)
sum(is.na(gene_symbols)) # 0



#--------------------------------------------------
#         setting up the data tables
#__________________________________________________

# describe the omics table

con = dbConnect(MySQL(), 
                host = 'localhost',
                dbname = 'sctu_sqldb',
                user = 'root',
                password = rstudioapi::askForPassword("Database password"))

dbGetQuery(con, 'desc omicssample')

df = dbGetQuery(con, 'select * from subject')

idUnit = df$idUnit

# Insert subject IDs in a loop
for (i in seq_along(idUnit)) {
  query <- sprintf(
    "INSERT INTO omicssample (Dataset_idDataset, Subject_idUnit) VALUES (%d, %d)",
    4, idUnit[i] # where idDataset = 4
  )
  
  # Debugging step
  print(query)  # See the queries being executed
  
  # dbExecute(con, query)
}

dbDisconnect(con)









