# Name: expressionSet_ML.R
# Auth: u.niazi@soton.ac.uk
# Date: 11/03/2025
# Desc: Integrate clinical and omics data (expression set object) and analyse

source('globals.R')

ui <- fluidPage(
  
  # Application title
  titlePanel("Expression Set Matrix Analysis Module"),
  
  # Sidebar with a panel for inputs
  sidebarLayout(
    sidebarPanel(
      # File input
      fileInput("obRDS", "1: Choose RDS File",
                accept = c(
                  ".rds"
                )),
      # Text input for user-defined study and data ids
      numericInput("inStudyID", "2: Enter Study Number", value = 1),
      numericInput("inDataID", "3: Enter Dataset ID", value = 0),
      # Button to trigger data loading
      actionButton("loadData", "4: Load Data"),
      # Button to trigger data summary
      actionButton("process", "5: Summary Data"),
       
      # Dropdown for selecting options from column 2 of dfClinData
      selectInput("inClinicalVariables", "6: Select Clinical Data to Use", 
                  choices = NULL, multiple = T),
      actionButton("mergeClinicalData", "7: Merge Clinical Data"),
      # Dropdown for selecting column for plotting
      selectInput("inEDAcolumn", "8: Select Column for Exploratory plots:", choices = NULL),
      # Button to trigger exploratory analysis
      actionButton("explore", "9: Exploratory Analysis"),
      # Button to trigger linear model analysis
      actionButton("linmodel", "10: Fit Linear Model"),
      
      # Add the level selection UI elements here, just before the download button
      uiOutput("levelSelection"),
      uiOutput("confirmLevels"),
      
      # download the differential expression table
      downloadButton('outDownloadLM', label = '11: Download Linear Model Results'),
      ## add a button to use clinical data or not for the ML steps
      checkboxInput('inClinicalDataUseFlag', label = '12: Use Clinical Data with Random Forest'),
      # Button to trigger Random Forest
      actionButton("ranforest", "13: Random Forest Model"),
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
      # Add a label above the table
      h3("Available Omics data sets"), 
      # Display the data frame
      DT::dataTableOutput("dataOutput"),
      # Text output for displaying results
      verbatimTextOutput("outputText1"),
      verbatimTextOutput("outputText2"),
      verbatimTextOutput("outputText3"),
      # Plot output
      plotOutput("edaPlot1"),
      plotOutput("edaPlot2"),
      plotOutput("edaPlot3"),
      plotOutput("edaPlot4"),
      plotOutput("edaPlot5"),
      ## display linear model output
      DT::dataTableOutput("outLinModel"),
      ## display volcano plot
      plotOutput("volcanoPlot"),
      # display random forest plot
      plotOutput('ranforestplot'),
      ## display RF model output
      DT::dataTableOutput("outRanForResults")
      # Placeholder for output elements
      # ...
    )
  )
)

server <- function(input, output) { 
  ######### reactive values and globals
  options(shiny.maxRequestSize = 15 * 1024^3) # Increase to 15GB
  # Reactive value to store the uploaded data
  uploadedData <- reactiveVal(NULL) 
  # Function to load the uploaded data
  observeEvent(input$loadData, {
    req(input$obRDS)
    uploadedData(readRDS(input$obRDS$datapath))
  })
  
  ## reactive value to set flag TRUE or FALSE using checkbox
  ## this is used with the random forest step later 
  ## to decide if selected clinical data will be used in the RF step
  bUseClinical <- reactiveVal(FALSE)
  ## function to update this reactive value
  observeEvent(input$inClinicalDataUseFlag, {
    bUseClinical(input$inClinicalDataUseFlag) # update the flag
  })
  
  ############# globals and utility functions
  oExp.global = NULL
  dfLMResults.global = NULL
  cvClinicalDataChoices.global = NULL
  
  ## utility function for volcano plot
  f_plotVolcano2 = function(dfGenes, main='', p.adj.cut = 0.1, fc.lim = c(-3, 3)){
    p.val = -1 * log10(dfGenes$P.Value)
    fc = dfGenes$logFC
    # cutoff for p.value y.axis
    y.cut = -1 * log10(0.05)
    col = rep('lightgrey', times=length(p.val))
    #c = which(dfGenes$adj.P.Val < p.adj.cut)
    c = 1:30 ## top 30 features to label
    col[c] = 'red'
    plot(fc, p.val, pch=20, xlab='Log Fold Change', ylab='-log10 P.Value', col=col, main=main, xlim=fc.lim)
    abline(v = 0, col='grey', lty=2)
    abline(h = y.cut, col='red', lty=2)
    # second cutoff for adjusted p-values
    #y.cut = quantile(p.val[c], probs=0.90)
    #abline(h = y.cut, col='red')
    # identify these features
    g = c#which(p.val > y.cut)
    lab = rownames(dfGenes)[g]
    text(dfGenes$logFC[g], y = p.val[g], labels = lab, pos=2, cex=1)
  }
  
  
  ## check if a numeric only containing character vector
  ## can be converted to numeric data type
  ## this is because the database stores everything at a text format
  ## leaving the end user to decide on specific conversions during the
  ## analysis.
  char_to_numeric_or_factor <- function(char_vec) {
    # Remove leading < or >, trailing non-numeric characters, and trailing + or -
    cleaned_vec <- gsub("^(<|>)+|[^[:digit:].-]+|[+-]+$", "", char_vec)
    
    if (all(grepl("^-?[[:digit:].]+$", cleaned_vec) | is.na(cleaned_vec))) {
      return(as.numeric(cleaned_vec))
    } else {
      return(as.factor(char_vec))
    }
  }
  
  ## old version of function - does not check for non character modifications 
  # to the numeric e.g. having a leading or trailing < > signs and trailing
  # + and - signs
  # char_to_numeric_or_factor = function(char_vec) {
  #   if (all(grepl("^[[:digit:].]+$", char_vec) | is.na(char_vec))) {
  #     return(as.numeric(char_vec))
  #   } else {
  #     return(as.factor(char_vec)) 
  #   }
  # }
  
  # display the data sets from available studies
  dfAvailableStudies <- function(){
    iStudyIDs = cosmos_showStudies(dbCon)[,'idStudy']
    df = data.frame()
    ## todo - add the study name as well?
    for (i in seq_along(iStudyIDs)){
      df = rbind(df, cosmos_showOmicsData(dbCon, iStudyIDs[i]))
    }
    return(df)
  }
  
  ## append clinical data selected to the expression set object
  ## pData pheno data slot
  dfGetSelectedClinicalData = function(cvChoices, dfPdata, id, db){
    ## read selected data from database
    ## append each clinical data to the dfPdata dataframe
    dfRet = dfPdata
    for (i in seq_along(cvChoices)){
      # read selected clinical data for matching omics data from db
      dfCD = cosmos_getAnyTimePointClinicalDataForOmics(db, id, cvChoices[i])  
      dfCD = dfCD[,c('idOmicsSample', 'idUnit_omics', cvChoices[i])]
      # merge the new clinical data column with the existing data
      dfMerged = merge.data.frame(dfPdata, dfCD, by.x='DB_Omics_Sample_id', 
                                  by.y='idOmicsSample')
      dfMerged = dfMerged[,c(colnames(dfPdata), cvChoices[i])]
      if (!identical(dfMerged$DB_Omics_Sample_id, dfRet$DB_Omics_Sample_id)){
        warning('in dfGetSelectedClinicalData - check for mismatch of omics ids')
      }
      # some acrobatics to have clean column names
      cn = colnames(dfRet)
      dfRet = cbind(dfRet, dfMerged[,cvChoices[i]])
      colnames(dfRet) = c(cn, cvChoices[i])
    }
    return(dfRet)
  }
  
  ########################## end globals and utility functions
  # Display the data frame
  output$dataOutput <- DT::renderDataTable({
    DT::datatable(dfAvailableStudies())
  })
  
  # Function to process the data and display output
  observeEvent(input$process, {
    if (!is.null(uploadedData())) {
      # Perform some operations on the data
      iDims <- dim(uploadedData())
      dfPdata = pData(uploadedData())
      
      output$outputText1 = renderPrint(iDims)
      output$outputText2 = renderPrint(head(dfPdata))
      
      # Access user-defined number
      iStudyID <- input$inStudyID
      dfClinData = cosmos_showAvailableClinicalData(dbCon, iStudyID)
      
      # Display a multi selection box based on available clinical variables
      updateSelectInput(inputId = "inClinicalVariables",
                        choices = unique(dfClinData$Type)) 
      
      oExp.global <<- uploadedData()
      
      # # Generate a simple plot (replace with your desired plot)
      # output$edaPlot <- renderPlot({
      #   hist(exprs(uploadedData())[1,]) 
      # })
    } else {
      output$outputText1 <- renderPrint("Please load data first.")
    }
  })
  
  # Function to merge chosen clinical data with omics data
  observeEvent(input$mergeClinicalData, {
    # if the clinical data has been chosen
    if (!is.null(input$inClinicalVariables)){
      iDataID = input$inDataID
      cvChoices = input$inClinicalVariables
      if (is.null(cvChoices)) cvChoices = 'Visit_Type'
      pData(oExp.global) <<- dfGetSelectedClinicalData(cvChoices, pData(oExp.global),
                                                     iDataID, dbCon)
      ## check if data format for choices need updating
      for (i in 1:length(cvChoices)){
        pData(oExp.global)[, cvChoices[i]] <<- char_to_numeric_or_factor(pData(oExp.global)[, cvChoices[i]])
      }
      
      ## update the global variable holding selected clinical data
      ## this will be used later in the random forest step
      cvClinicalDataChoices.global <<- cvChoices
      output$outputText2 = renderPrint(head(pData(oExp.global)))
      output$outputText3 = renderPrint(summary(pData(oExp.global)))
      
      ## populate the selection box of available variables for EDA
      ## choose only factor variables 
      # Read the data frame
      dfSample = pData(oExp.global)
      cn = colnames(dfSample)
      ## select factor columns
      f = sapply(cn, function(x) is.factor(dfSample[,x]))
      cn = cn[f]
      
      # Update the selectInput for factor column selection
      ## in order to prevent auto selection keyword NULL is used in qoutes
      ## this is unlikely to be an actual column name
      updateSelectInput(inputId = "inEDAcolumn", 
                        choices = cn, selected = 'NULL')
    }
  })
  
  
  
  # Function to perform exploratory analysis
  ## this will a some high level plots like PCA
  observeEvent(input$explore, {
    if (!is.null(uploadedData()) && !(input$inEDAcolumn == '')) {
      ## download the library
      library(downloader)
      url = 'https://raw.githubusercontent.com/uhkniazi/CDiagnosticPlots/experimental/CDiagnosticPlots.R'
      download(url, 'CDiagnosticPlots.R')
      
      # load the required packages
      source('CDiagnosticPlots.R')
      # delete the file after source
      unlink('CDiagnosticPlots.R')
      
      # Read the data frame
      dfSample = pData(oExp.global)
      oDiag.1 = CDiagnosticPlots(exprs(oExp.global), 'EDA')
      ## remove random jitter from pca and hca plots
      ## change parameters 
      l = CDiagnosticPlotsGetParameters(oDiag.1)
      l$PCA.jitter = F
      l$HC.jitter = F
      oDiag.1 = CDiagnosticPlotsSetParameters(oDiag.1, l)
      fBatch = dfSample[,input$inEDAcolumn]
      
      df = as.data.frame(table(fBatch))
      colnames(df)[1] = input$inEDAcolumn
      output$outputText1 = renderPrint(df)
      
      # generate the EDA plots
      output$edaPlot1 = renderPlot({
        if (nlevels(fBatch) > 3) par(mfrow=c(1,2))
        boxplot.median.summary(oDiag.1, fBatch, axis.label.cex = 1)
      })
      
      output$edaPlot2 = renderPlot({
        if (nlevels(fBatch) > 3) par(mfrow=c(1,2))
        plot.mean.summary(oDiag.1, fBatch, axis.label.cex = 1)
      })
      
      output$edaPlot3 = renderPlot({
        if (nlevels(fBatch) > 3) par(mfrow=c(1,2))
        plot.sigma.summary(oDiag.1, fBatch, axis.label.cex = 1)
      })
      
      output$edaPlot4 = renderPlot({
        if (nlevels(fBatch) > 3) par(mfrow=c(1,2))
        plot.PCA(oDiag.1, fBatch)
      })
      
      output$edaPlot5 = renderPlot({
        if (nlevels(fBatch) > 3) par(mfrow=c(1,2))
        plot.dendogram(oDiag.1, fBatch, labels_cex = 1)
      })
    } else {
      output$outputText1 <- renderPrint("Please load data and select a column first.")
    }
  })
  
  ## function to fit linear model
  ## todo - currently we are only dealing with 2 level factors as it is the most
  ## common scenario
  observeEvent(input$linmodel, {
    if (!is.null(uploadedData()) && !(input$inEDAcolumn == '')) {
      oExp.local = oExp.global
      ## format the design matrix
      fGroups = pData(oExp.local)[, input$inEDAcolumn]
      ## check if any NA's 
      i = which(is.na(fGroups))
      ## if there are NAs drop those samples
      if (length(i) > 0){
        oExp.local = oExp.local[, -i]
      }
      ## in case removing NAs have left empty factor levels
      fGroups = droplevels(pData(oExp.local)[, input$inEDAcolumn])
      ## if nlevels is only 1
      ## the class grouping still has at least 2 levels 
      ## as too many NAs may create this problem
      if (nlevels(fGroups) < 1) {
        output$outputText1 <- renderPrint("Selected factor has too many missing values")
        return(-1)
      }
      
      ## check if fGroups has more than two levels
      ## ask user to select 2 levels for comparison
      if (nlevels(fGroups) > 2) {
        # Use pickerInput from shinyWidgets
        output$levelSelection <- renderUI({
          pickerInput(
            "selectedLevels",
            "Select Two Levels to Compare:",
            choices = levels(fGroups),
            multiple = TRUE,
            selected = levels(fGroups)[1:2],
            options = list(maxItems = 2)
          )
        })
        
        # Add a button to confirm level selection
        output$confirmLevels <- renderUI({
          actionButton("confirmLevelSelection", "Confirm Level Selection")
        })
        
        # Now, observe the confirm button event
        observeEvent(input$confirmLevelSelection, {
          if (length(input$selectedLevels) == 2) {
            # User has selected two levels, proceed with analysis
            selected_levels <- input$selectedLevels
            #fGroups_subset <- factor(fGroups[fGroups %in% selected_levels])
            oExp.local <- oExp.local[, fGroups %in% selected_levels]
            ## update the pData if any factor levels are not valid
            pData(oExp.local) = droplevels.data.frame(pData(oExp.local))
            fGroups = pData(oExp.local)[, input$inEDAcolumn]
            mData = exprs(oExp.local)
            ## fit limma model
            design = model.matrix(~ fGroups)
            lm.1 = lmFit(mData, design)
            lm.1 = eBayes(lm.1)
            
            dfResults = topTable(lm.1, coef=2, adjust='BH', number=Inf)
            
            # Display the data frame
            output$outLinModel <- DT::renderDataTable({
              DT::datatable(dfResults, caption = paste0(levels(fGroups)[2], ' VS ', levels(fGroups)[1]))
            })
            
            ## update the global variable
            dfLMResults.global <<- dfResults
            
            ## volcano plot of results
            output$volcanoPlot = renderPlot({
              f_plotVolcano2(dfResults, main = 'Volcano Plot', fc.lim = range(dfResults$logFC))
            })
            # Remove the level selection UI elements
            output$levelSelection <- renderUI(NULL)
            output$confirmLevels <- renderUI(NULL)
            
            ## update global value for expression set object
            oExp.global <<- oExp.local
          } else {
            output$outputText1 <- renderPrint("Please select exactly two levels.")
          }
        })
      } else {
      mData = exprs(oExp.local)
      ## fit limma model
      design = model.matrix(~ fGroups)
      lm.1 = lmFit(mData, design)
      lm.1 = eBayes(lm.1)
      
      dfResults = topTable(lm.1, coef=2, adjust='BH', number=Inf)
      
      # Display the data frame
      output$outLinModel <- DT::renderDataTable({
        DT::datatable(dfResults, caption = paste0(levels(fGroups)[2], ' VS ', levels(fGroups)[1]))
      })
      
      ## update the global variable
      dfLMResults.global <<- dfResults
      
      ## volcano plot of results
      output$volcanoPlot = renderPlot({
        f_plotVolcano2(dfResults, main = 'Volcano Plot', fc.lim = range(dfResults$logFC))
      })
      
      }
    } else {
      output$outputText1 <- renderPrint("Please load data and select a feature covariate first.")
    }
  })
  
  ## export the csv of this clinical data for editing
  ## download button
  ## remove this option eventually
  output$outDownloadLM = downloadHandler(filename = function(){
    paste0(gsub('[[:punct:]]', '', runif(1)), '.csv')
  }, 
  content=function(file){
    tryCatch(expr = {
      dfOut = dfLMResults.global
      write.csv(dfOut, file, row.names = T)
    }, error=function(e) return(NULL))
  })
  
  ## function to fit random forest
  ## check if the selected class variable is a 2 level factor
  observeEvent(input$ranforest, {
    if ((!is.null(uploadedData()) && !(input$inEDAcolumn == '')) &&
        nlevels(pData(oExp.global)[, input$inEDAcolumn]) == 2) {
      # load data from global variable
      # check for NAs and remove those
      oExp.local = oExp.global
      ## format the design matrix
      fGroups = pData(oExp.local)[, input$inEDAcolumn]
      ## check if any NA's 
      i = which(is.na(fGroups))
      ## if there are NAs drop those samples
      if (length(i) > 0){
        oExp.local = oExp.local[, -i]
      }
      fGroups = pData(oExp.local)[, input$inEDAcolumn]
      mData = exprs(oExp.local)
      cvTop100 = NA
      if(!require(downloader) || !require(methods)) stop('Library downloader and methods required')
      
      url = 'https://raw.githubusercontent.com/uhkniazi/CCrossValidation/experimental/CCrossValidation.R'
      download(url, 'CCrossValidation.R')
      
      ## select top variables from the differential analysis
      dfResults = dfLMResults.global
      # Find the column name that contains "pvalue" (case-insensitive)
      pvalue_col <- grep("p\\.?value", colnames(dfResults), ignore.case = TRUE, value = TRUE)[1]
      # Check if a matching column was found
      if (!is.na(pvalue_col)) {
        # Sort the data frame by the identified p-value column
        dfResults_sorted <- dfResults[order(dfResults[[pvalue_col]]), ]
        
        # Get the top 100 features
        cvTop100 <- rownames(dfResults_sorted)[1:100]
      } else {
        print("Error: No p-value column found in dfResults.")
      }
      
      mData = mData[rownames(mData) %in% cvTop100, ]
      # load the required packages
      source('CCrossValidation.R')
      # delete the file after source
      unlink('CCrossValidation.R')
      
      dfData = data.frame(t(mData))
      
      ## check if the selected clinical data should also be used for random forest
      bFlag = bUseClinical() # current value of flag
      if (bFlag && !(is.null(cvClinicalDataChoices.global))){
        cvChoices = cvClinicalDataChoices.global[!(cvClinicalDataChoices.global %in% input$inEDAcolumn)]
        cn = colnames(dfData)
        dfData = cbind(dfData, pData(oExp.local)[, cvChoices])
        colnames(dfData) = c(cn, cvChoices)
        ## there may be NAs in the new clinical data added
        ## clean those up - this can be done in previous step as well 
        ## where we create the fGroups variable
        dfData$fGroups = fGroups
        dfData = na.omit(dfData)
        ## if any factors has empty levels after removing NAs
        dfData = droplevels.data.frame(dfData)
        fGroups = dfData$fGroups
        ## drop the last column which was fGroups
        dfData = dfData[, -(ncol(dfData))]
      }
      
      ## check if after adding clinical data
      ## the class grouping still has 2 levels 
      ## as too many NAs may create this problem
      if (nlevels(fGroups) != 2) {
        output$outputText1 <- renderPrint("Selected clinical data has too many missing values")
        return(-1)
      }
      
      df = as.data.frame(table(fGroups))
      colnames(df)[1] = input$inEDAcolumn
      output$outputText1 = renderPrint(df)
      
      oVar.r = CVariableSelection.RandomForest(dfData, fGroups, boot.num = 20, big.warn = F)
      
      ## RF plot of results
      output$ranforestplot = renderPlot({
        plot.var.selection(oVar.r)
      })
      
      ## display variable importance results
      # Display the data frame
      output$outRanForResults <- DT::renderDataTable({
        DT::datatable(CVariableSelection.RandomForest.getVariables(oVar.r)[,1:2],
                      caption = paste0('Variable Importance Plots'))
      })
      
    } else {
      output$outputText1 <- renderPrint("Please load data and select a feature covariate first with only 2 groups.")
    }
  })
  
  # Placeholder for server logic
  # ...
}

# Run the application 
shinyApp(ui = ui, server = server)