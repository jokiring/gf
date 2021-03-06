# ----------------------------------------------
# Irena Chen
#
# 11/8/2017
# Template for prepping GF summary page only budget data
# Inputs:
# inFile - name of the file to be prepped
# Outputs:
# budget_dataset - prepped data.table object
# ----------------------------------------------
# 
# dir = file_dir
# sheet_name = "RESUME BUDGET V2 CONSOLIDE"
# inFile = "official_budgets/BUDGET SANRUGF CONSOLIDE  ROUTINE CAMPAGNE.xlsx"
# start_date = "2018-01-01"
# period = 90
# qtr_num = 12


prep_summary_budget = function(dir, inFile, sheet_name, start_date, 
                                   qtr_num, disease, loc_id, period, grant, recipient, source, lang){
  
  
  ######## TROUBLESHOOTING HELP
  ### fill in variables below with information from line where the code breaks (use file list to find variables)
  ### uncomment by "ctrl + shift + c" and run code line-by-line
  ### look at gf_data and find what is being droped where.
  ########
  
  # file_dir <- 'official_budgets/COD-M-SANRU_SB2.xlsx'
  # dir = file_dir
  # inFile = 'official_budgets/COD-M-SANRU_SB2.xlsx'
  # sheet_name = "Y compris EnquêteMortalité 822k"
  # start_date = "2015-01-01"
  # qtr_num = 12
  # period = 90
  # disease = "malaria"
  # recipient = "MoH"
  # lang = "fr"
  # grant = "COD-M-SANRU"
  # source = "fpm"
  # loc_id = "cod"
  
  
  # ----------------------------------------------
  ##set up functions to handle french and english budgets differently
  # ----------------------------------------------
  ## create a vector of start_dates that correspond to each quarter in the budget 
  
  str_replace(start_date, "\\\\", "")
  start_date = substring(start_date, 2, 11) 
  start_date = as.Date(start_date)
  
  dates <- rep(start_date, qtr_num) # 
  for (i in 1:length(dates)){
    if (i==1){
      dates[i] <- start_date
    } else {
      dates[i] <- dates[i-1]%m+% months(3)
    }
  }
  
  # ----------------------------------------------
  ##read the data: 
  # ----------------------------------------------
  
  if(!is.na(sheet_name)){
    gf_data <- data.table(read_excel(paste0(dir, inFile), sheet=as.character(sheet_name), col_names = FALSE))
  } else {
    gf_data <- data.table(read_excel(paste0(dir, inFile)))
  }
  # print(start_date)
  # str_replace(start_date, "\\\\", "")
  # print(start_date)
  # start_date = substring(start_date, 2, 11)
  # print(start_date)
  # start_date = as.Date(start_date)
  
  colnames(gf_data)[1] <- "cost_category"
  ##only keep data that has a value in the "category" column 
  gf_data <- na.omit(gf_data, cols=1, invert=FALSE)
  
  if(sheet_name == "RESUME BUDGET V2 CONSOLIDE"){
    #grab the sda values
    gf_data <- gf_data[c((grep("Module",gf_data$cost_category)):nrow(gf_data)),]
    #drop Total
    gf_data <- head(gf_data,-1)
    #dropping this becuase it's duplicate of first colum
    gf_data$X__2 = NULL
  
    
  }else{
    ## grab the SDA data
    gf_data <- gf_data[c((grep("Module",gf_data$cost_category)):(grep("Cost Grouping", gf_data$cost_category))),]
    ##drop the last two rows (we don't need them)
    gf_data <- head(gf_data,-2)
  }
  
  
  ## rename the columns 
  colnames(gf_data) <- as.character(gf_data[1,])
  gf_data <- gf_data[-1,]
  toMatch <- c("Ann","Year", "RCC", "%", "Phase", "Implem", "Total")
  drop.cols <- grep(paste(toMatch, collapse="|"), ignore.case=TRUE, colnames(gf_data))
  gf_data <- gf_data[, (drop.cols) := NULL]

  ## also drop columns containing only NA's
  gf_data<- Filter(function(x) !all(is.na(x)), gf_data)
  
  ## invert the dataset so that budget expenses and quarters are grouped by category
  ##library(reshape)
  setDT(gf_data)
  if(sheet_name == "RESUME BUDGET V2 CONSOLIDE"){
    #only keep quarters 1 - 12
  gf_data = gf_data[,c(1:13)]
  gf_data1<- melt(gf_data,id="By Module - Intervention" , variable.name = "qtr", value.name="budget")
  }else{
  gf_data1<- melt(gf_data,id="By Module", variable.name = "qtr", value.name="budget")
  }
  
  ## make sure that you have a date for each quarter - will tell you if you're missing any 
  if(length(dates) != length(unique(gf_data1$qtr))){
    stop('Error: quarters were dropped!')
  }
  ##turn the list of dates into a dictionary (but only for quarters!) : 
  dates <- setNames(dates,unique(gf_data1$qtr))
  
  
  ## now match quarters with start dates 
  kDT = data.table(qtr = names(dates), value = TRUE, start_date = unname(dates))
  budget_dataset <-gf_data1[kDT, on=.(qtr), start_date := i.start_date]
  
  ##rename the category column 
  colnames(budget_dataset)[1] <- "module"
  
  if(sheet_name == "RESUME BUDGET V2 CONSOLIDE"){
    budget_dataset = separate(budget_dataset, module, into=c("module", "intervention"), sep="-")
  }else{
    budget_dataset$intervention <- "All"  
  }
  
  ##add all of the other RT variables 
  budget_dataset$disease <- disease
  budget_dataset$sda_activity <- "All"
  budget_dataset$loc_name <- loc_id
  budget_dataset$period <- period
  budget_dataset$grant_number <- grant
  budget_dataset$recipient <- recipient
  budget_dataset$qtr <- NULL
  budget_dataset$expenditure <- 0 
  budget_dataset$cost_category <- "all"
  budget_dataset$data_source <- source
  budget_dataset$year <- year(budget_dataset$start_date)
  budget_dataset$lang <- lang
  
  return(budget_dataset)
  
}