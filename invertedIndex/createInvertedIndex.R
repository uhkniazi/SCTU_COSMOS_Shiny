# Name: createInvertedIndex.R
# Auth: u.niazi@soton.ac.uk
# Date: 26/11/2024
# Desc: load a csv file of dictionary terms and postings and create an inverted index

## use the logic explained in chapter 1 of 
## introduction to information retreival
lCreateInvertedIndex = function(dfIndex){
  ## some error checks
  if (colnames(dfIndex)[1] != 'term' || colnames(dfIndex)[2] != 'posting'){
    stop('Column names of index data frame should be term and posting')
  }
  # Sort the data frame by the 'term' column
  dfIndex = dfIndex[order(dfIndex$term), ]
  
  # create empty list
  lInvertedIndex = list()
  
  ## populate the list
  # Iterate over each row and add to the inverted index
  for (i in 1:nrow(dfIndex)) {
    term = dfIndex$term[i]
    posting = dfIndex$posting[i]
    
    ## if term is not i.e. already in list
    if (term %in% names(lInvertedIndex)) {
      # Check if not duplicate postings within the same term
      if (!(posting %in% lInvertedIndex[[term]])) {
        lInvertedIndex[[term]] = c(lInvertedIndex[[term]], posting)
      }
    } else {
      lInvertedIndex[[term]] = posting
    }
  }
  return(lInvertedIndex)
}

## function to parse and clean input statement
cvParseUserInput = function(cvInput){
  # make text lower case
  cvInput = tolower(cvInput)
  # remove stop letters
  cvInput = gsub('[[:punct:]]', '', cvInput)
  return(unlist(strsplit(cvInput, ' ')))
}

# Load the CSV file for COSMOS db search 
data = read.csv("invertedIndex/dbSearch_dictionaryTerms_postings.csv", 
                stringsAsFactors = F)

## make sure column names are correct
if (!any(colnames(data) %in% c('term', 'posting'))) {
  colnames(data) = c('term', 'posting')
}

lCosmos_Index = lCreateInvertedIndex(data)

