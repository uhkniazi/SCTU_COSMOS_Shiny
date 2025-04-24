# Name: cosmos_interactive_query_tool.R
# Auth: u.niazi@soton.ac.uk; C.A.K.Roberts@soton.ac.uk
# Date: 24/04/2025
# Desc: a user-friendly interface that simplifies database interaction


source('globals.R')

ui = fluidPage(
  titlePanel("COSMOS Interactive Query Tool"),
  sidebarLayout(
    sidebarPanel(
      textInput("inSearchTerms", "Search for appropriate query e.g clinical data"),
      uiOutput("outMatchingTerms"),
      uiOutput("outFunctionArgs"),
      actionButton("inQueryButton", "Execute Query")
    ),
    mainPanel(
      DTOutput("outQueryTable")
    )
  ),
  downloadButton('outDownload')
)

server = function(input, output){
  reOutMatchingTerms = reactive({
    ## more to add here 
    #print('reOutMatchingTerms called')
    ## get full list of optional queries if query has not
    ## been typed by user
    if (input$inSearchTerms == '') {
      return(Reduce(union, lCosmos_Index))
    }
    cvSplit = cvParseUserInput(input$inSearchTerms)
    lIndex = lCosmos_Index[cvSplit]
    lIndex = lIndex[!sapply(lIndex, is.null)]
    Reduce(intersect, lIndex)
  })
  
  ### render function choices 
  output$outMatchingTerms = renderUI({
    ## this is an input,  should this be in UI or Here?
    ##print('renderUI outMatchingTerms called')
    selectInput('inSelectedTerm', 'Select a matching query for Database', 
                choices = reOutMatchingTerms())
  })
  
  ### after selecting function choice
  ### provide user with optional arguments
  reOutFunctionArgs = reactive({
    #print(input$inSelectedTerm)
    ##if (is.null(input$inSelectedTerm)) return(list('dbCon'='dbCon'))
    ##
    ## if first function has not yet been selected on 
    ## start of app, call to formals can give error 
    ## use try catch to send back default value
    tryCatch(expr = as.list(formals(get(input$inSelectedTerm))),
             error=function(e)list('dbCon'='dbCon'))
  })
  
  output$outFunctionArgs = renderUI({
    ## the number of boxes displayed will depend on number of arguments
    lArgs = reOutFunctionArgs()
    #print(lArgs)
    ## display text input boxes
    lapply(1:length(lArgs), function(i) {
      ## check if first input is the dbCon as it is a global variable
      ## no need for user to input
      if (names(lArgs)[i] == 'dbCon'){
        textInput(paste0('inFunctionArgs', i), paste0(names(lArgs)[i]), value = 'dbCon')
      } else textInput(paste0('inFunctionArgs', i), paste0(names(lArgs)[i]))
    })
  })
  
  ## after pressing the query DB button
  ## the event reactive is called to extract the arguments
  ## from the boxes and run the query
  reQueryButton = eventReactive(input$inQueryButton, {
    lArgs = reOutFunctionArgs()
    inputValues = lapply(1:length(lArgs), function(i) {
      input[[paste0("inFunctionArgs", i)]]
    })
    # data.frame(Input = inputValues)
    inputValues[[1]] = dbCon
    do.call(get(input$inSelectedTerm), inputValues)
  })
  
  ## function to display the table
  output$outQueryTable = renderDT({
    reQueryButton()
  })
  
  ## download button
  output$outDownload = downloadHandler(filename = function(){
    paste0(gsub('[[:punct:]]', '', runif(1)), '.csv')
  }, 
  content=function(file){
    tryCatch(expr = {
      dfOut = reQueryButton()
      write.csv(dfOut, file, row.names = F)
      }, error=function(e) return(NULL))
  })
  
}

## run app
shinyApp(ui, server)
