# Name: globals.R
# Auth: u.niazi@soton.ac.uk; C.A.K.Roberts@soton.ac.uk
# Date: 24/04/2025
# Desc: setting global variables in loading config files

library(shiny)
library(DT)
library(shinyWidgets)
## libraries for working with omics data
library(Biobase)
library(BiocGenerics)
library(limma)
source('00_cosmosDB_utilities.R')
source('invertedIndex/createInvertedIndex.R')

dbCon = cosmos_login()

## cleaup on app exit
onStop(function() {
  dbDisconnect(dbCon)
})
