#------------------------------------------------------------------------------
# AUTHOR: Emily Linebarger
# DATE: November 2018 
# PURPOSE: Calculate budget breakdown by recipient (PR vs SR)
#           in Uganda 2015-2017 grants, to be compared with GOS data. 
#           (could be modified to other grant periods/countries. )   
#
#           View target_gos_interventions to see average absorption numbers 
#           for modules/interventions that were only done by SRs in Q1 and Q2 
#           of 2015-2017 Uganda grants. This data table is calculated using 
#           GOS data from 2012 onwards. 
#-----------------------------------------------------------------------------

# ------------------
# Set up R
# ------------------
rm(list=ls())
library(data.table)
library(doBy)

# ------------------------------------------------
# Read in full prepped dataset from Uganda to 
#   isolate SR activities for target grant period 
# ------------------------------------------------
data = read.csv("J:/Project/Evaluation/GF/resource_tracking/uga/prepped/prepped_budget_data.csv")
data = as.data.table(data)

#---------------------------------------------------------
# identify SR activities, and subset to the grants we want. 
#---------------------------------------------------------

#Subset to 2015-2017
data = data[grant_period == "2018-2020"]

summed_budgets_expenditures = data[, .(tot_budget = sum(budget), tot_expenditure = sum(expenditure) ), by=c('recipient', "grant_number", "grant_period")]

data[, SR:=TRUE]
data$recipient <- trimws(data$recipient)
data$grant_number <- trimws(data$grant_number)
data[grepl('MoFPED', grant_number) & recipient %in% c('MoFPED', 'MoPFED', 'Ministry of Finance, Planning and Economic Development of the Republic of Uganda'), SR:=FALSE]
data[grepl('TASO', grant_number) & recipient %in% c('TASO','taso', 'The AIDS Support Organisation (Uganda) Limited'), SR:=FALSE]


check = data[data_source=="pudr",]
check = check[start_date == "2018-01-01" | start_date == "2018-04-01"]
stopifnot(length(unique(check$fileName))==5)

data <- copy(check)
#--------------------------------------------------
# Split by recipient, and see if there is a difference 
#   in modules/interventions between the two. 
#-------------------------------------------------
data <- data[, c("gf_module", "gf_intervention", "budget", "expenditure", "SR", "start_date")] 

sr <- data[SR == T]
pr <- data[SR == F]

sr = as.data.table(sr)
pr = as.data.table(pr)

# calculate absorption for q1q2 (based on subsetted data above)
sr[, sum(expenditure)/sum(budget)]
pr[, sum(expenditure)/sum(budget)]

# #Subset to q1 and q2 for comparison 
# sr_q1q2 <- sr[start_date == "2018-01-01" | start_date == "2018-04-01"]
# pr_q1q2 <- pr[start_date == "2018-01-01" | start_date == "2018-04-01"]

# sr <- sr[, 1:3] 
# pr <- pr[, 1:3] 
# sr_q1q2 <- sr_q1q2[, 1:3]
# pr_q1q2 <- pr_q1q2[, 1:3]

sr_q1q2 = sr_q1q2[!is.na(absorption)]
pr_q1q2 = pr_q1q2[!is.na(absorption)]

sr_q1q2 = sr_q1q2[, c(1:2, 7)]
pr_q1q2 = pr_q1q2[, c(1:2, 7)]

#Melt and cast data tables to sum absorption by module/intervention 
sr = melt(sr, id = c("gf_module", "gf_intervention"))
sr = dcast(sr, gf_module+gf_intervention ~ variable, fun = sum)
pr = melt(pr, id = c("gf_module", "gf_intervention"))
pr = dcast(pr, gf_module+gf_intervention ~ variable, fun = sum)

sr_q1q2 = melt(sr_q1q2, id = c("gf_module", "gf_intervention"))
sr_q1q2 = dcast(sr_q1q2, gf_module+gf_intervention ~ variable, fun = sum)
pr_q1q2 = melt(pr_q1q2, id = c("gf_module", "gf_intervention"))
pr_q1q2 = dcast(pr_q1q2, gf_module+gf_intervention ~ variable, fun = sum)

#---------------------------------------------------------
#Merge back together to compare, and isolate SR activities 
#---------------------------------------------------------
# identify module/interventions with large proportion budgeted to SRs
combined <- merge(pr, sr, by = c("gf_module", "gf_intervention"), suffixes = c(".pr", ".sr"), all = T)
setDT(combined)g
combined[, sr_fraction:=budget.sr/(budget.sr+budget.pr)]
sr_activities = combined[sr_fraction>.9] 

# identify module/interventions with large proportion budgeted to SRs, q1 and q2 of grants only 
combined <- merge(pr_q1q2, sr_q1q2, by = c("gf_module", "gf_intervention"), suffixes = c(".pr", ".sr"), all = T)
setDT(combined)
combined[, sr_fraction:=budget.sr/(budget.sr+budget.pr)]
sr_activities_q1q2 = combined[sr_fraction>.9] 

rm(pr, sr, pr_q1q2, sr_q1q2, combined) #Clean up workspace 

#-----------------------------------------------------------------
# Calculate average absorption for these activities using GOS data 
#-----------------------------------------------------------------
# root directory for input/average_absorptionput
dir = 'J:/Project/Evaluation/GF/resource_tracking/multi_country/'

# input data
inFile = paste0(dir, 'mapping/total_resource_tracking_data.csv')

allData <- fread(inFile)
gos <- allData[data_source %in% c('gos')]

#Subset to the data we want (Uganda, only GOS data after 2012)
gos <- gos[country %in% c("Uganda")]
gos <- gos[year >= 2012]

#Merge GOS data with sr_activities found above 
target_gos_interventions <- merge(gos, sr_activities, all.y = TRUE, by = c('gf_module', 'gf_intervention'))
target_gos_interventions_q1q2 <- merge(gos, sr_activities_q1q2, all.y = TRUE, by = c('gf_module', 'gf_intervention'))

# compute absorption by module and intervention
byVars = c('disease', 'abbrev_module', 'abbrev_intervention')
target_gos_interventions = target_gos_interventions[, .(expenditure=sum(expenditure, na.rm=T), budget=sum(budget,na.rm=T)), by=byVars]
target_gos_interventions[, absorption:=expenditure/budget]
target_gos_interventions_q1q2 = target_gos_interventions_q1q2[, .(expenditure=sum(expenditure, na.rm=T), budget=sum(budget,na.rm=T)), by=byVars]
target_gos_interventions_q1q2[, absorption:=expenditure/budget]

#Want to collapse on grant_number and module/intervention to get average over time. 
target_gos_interventions = summaryBy(absorption~disease+abbrev_module+abbrev_intervention, FUN=c(mean), data = target_gos_interventions)
target_gos_interventions$absorption.mean <- round(target_gos_interventions$absorption.mean, 2)
target_gos_interventions_q1q2 = summaryBy(absorption~disease+abbrev_module+abbrev_intervention, FUN=c(mean), data = target_gos_interventions_q1q2)
target_gos_interventions_q1q2$absorption.mean <- round(target_gos_interventions_q1q2$absorption.mean, 2)

#Remove one row at end that has "NA" for module/intervention 
target_gos_interventions = target_gos_interventions[!is.na(abbrev_module)]
target_gos_interventions_q1q2 = target_gos_interventions_q1q2[!is.na(abbrev_module)]

#Clean up workspace 
rm(byVars, dir, inFile)

#----------------------------------------------------------------
# View target_gos_interventions and target_gos_interventions_q1q2
#   for final result. 
#----------------------------------------------------------------


