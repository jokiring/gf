# ----------------------------------------------
# Caitlin O'Brien-Carelli
# Prep the QR outlier screened data for use
# Examine different thresholds
# ----------------------------------------------

# --------------------
# Set up R
rm(list=ls())
library(data.table)
library(quantreg)
library(ggplot2)
library(RColorBrewer)
library(stringr)
#------------------------------------
# set directories

# detect if operating on windows or on the cluster 
j = ifelse(Sys.info()[1]=='Windows', 'J:', '/home/j')

# set the directory for input and output
dir = paste0(j, '/Project/Evaluation/GF/outcome_measurement/cod/dhis_data/')

# read in the file
dt = readRDS(paste0(dir, 'pnls_outliers/qr_results_full.rds'))

#------------------------------------
# merge in the facility names to label the graphs 

facilities = readRDS(paste0(dir, 'meta_data/master_facilities.rds'))
facilities = facilities[ ,.(org_unit_id, org_unit)]
dt = merge(dt, facilities, by='org_unit_id', all.x=T)

#------------------------------------
# identify outliers at various levels/thresholds
<<<<<<< HEAD
=======
#Hi Audrey, we had a merge conflict with lines 38-40 vs. lines 42-44. We kept them both, which one would you like to keep? -Emily and Jen 

>>>>>>> 000d22b4b6abbd9d72fe31d0711bdf364e7d9f23
dt[ ,thresh5:=median(resid)+(5*sd(resid)), by=.(org_unit_id, element)]
dt[ ,thresh10:=median(resid)+(10*sd(resid)), by=.(org_unit_id, element)]
dt[ ,thresh20:=median(resid)+(20*sd(resid)), by=.(org_unit_id, element)]

# select outliers 
# the value is 100 or more and greater than 10 times the SD of the residuals 
dt[thresh10 < value & 100 <=value, outlier:=TRUE]
dt[(value <= thresh10 | value < 100), outlier:=FALSE]

# set lower and upper bounds
<<<<<<< HEAD
=======
#Hi Audrey, we had a merge conflict with lines 54-59 vs. lines 61-66. We kept them both, which one would you like to keep? -Emily and Jen 
>>>>>>> 000d22b4b6abbd9d72fe31d0711bdf364e7d9f23
dt[ ,upper:=median(resid)+(10*sd(resid)), by=.(org_unit_id, element)]
dt[ ,lower:=(median(resid)-(10*sd(resid))), by=.(org_unit_id, element)]

# add a 5 SD bound just to be sure
dt[ ,upper_mid:=median(resid)+(5*sd(resid)), by=.(org_unit_id, element)]
dt[ ,lower_mid:=(median(resid)-(5*sd(resid))), by=.(org_unit_id, element)]
<<<<<<< HEAD
=======

>>>>>>> 000d22b4b6abbd9d72fe31d0711bdf364e7d9f23

# typically no values are below lower, but check
dt[value < lower, outlier:=TRUE]

#----------------------------
# create an alternate org_unit name for the graphs

dt[ ,facility:=word(org_unit, 2, -1)]

#------------------------------------
# subset to only the sexes within facilities and elements that have outliers

#One more merge conflict! -Emily and Jen 
# subset to the health facilities with outliers and visualize 

# subet to the health facilities, sexes, and variables with outliers
dt[ , combine:=paste0(org_unit_id, sex, element)]
out_orgs = dt[outlier==T, unique(combine)]
out = dt[combine %in% out_orgs]
<<<<<<< HEAD
=======

 # # subset to only the sexes within facilities and elements that have outliers

# dt[ , combine:=paste0(org_unit_id, sex, element)]
# out_sex = dt[outlier==T, unique(combine)]
# out = dt[combine %in% out_sex]

>>>>>>> 000d22b4b6abbd9d72fe31d0711bdf364e7d9f23
out[ , combine:=NULL]

#----------------------------
# eliminate outliers that are part of an emerging trend

# create a unique identifier to drop out emerging trends
out[ , combine2:=paste0(org_unit_id, sex, element, subpop, age)]

# subset to only the age categories, subpops with outliers
out[ , count:=sum(outlier), by=combine2]
drop = out[1 < count]

# create a simpler data tabledrop
drop = drop[ ,.(combine2, org_unit_id, element, sex, age, subpop, date, outlier, value)]

# order by the unique identifier and then by date 
drop[order(combine2, date)]

# the subsequent or previous data point is within 50 of the past data point
drop[ , value_lag:=shift(value, type='lag')]
drop[ , value_lead:=shift(value, type='lead')]
drop[outlier==T & (abs(value_lead - value) <= 50), dif:=T]
drop[outlier==T & (abs(value_lag - value) <= 50), dif:=T]
drop[is.na(dif), dif:=F]
drop = drop[dif==T]

# convert outliers to FALSE 
drop[ , combine3:=paste0(as.character(date), combine2)]
out[ , combine3:=paste0(as.character(date), combine2)]
emerging_trends = drop$combine3
out[combine3 %in% emerging_trends, outlier:=F]

# drop the unecessary variables
out[ ,c('combine2', 'combine3'):=NULL]

# subset again to only the sexes, facilities, variables with outliers
out[ , combine:=paste0(org_unit_id, sex, element)]
out_new = out[outlier==T, unique(combine)]
out = out[combine %in% out_new]

#----------------------------
# create the graphs

# create a palette
greys = brewer.pal(9, 'Greys')

# create a list of plots
list_of_plots = NULL
i=1

# loop through the graphs 
for (e in unique(out$element)) {
  for (o in unique(out[element==e]$org_unit_id)) {
    for (s in unique(out[element==e & org_unit_id==o]$sex)) {
      
      # title states variable, sex, facility
      name = out[org_unit_id==o, unique(facility)]
      title = paste0(e,' (', s, '): ', name)
      
      # create a subtitle with the outlier and the fitted value to impute
      out_point = out[element==e & org_unit_id==o & sex==s & outlier==TRUE, unique(value)]
      fit_point = out[element==e & org_unit_id==o & sex==s & outlier==TRUE, unique(fitted_value)]
      subtitle = paste0('Outlier value=', out_point, '; Fitted value=', round(fit_point, 1))
      
      # create the plot
      list_of_plots[[i]] = ggplot(out[element==e & org_unit_id==o & sex==s], aes(x=date, y=value, color=age)) +
        geom_line() +
        geom_point(data = out[element==e & org_unit_id==o & sex==s & outlier==TRUE], color='#d73027', size=3, alpha=0.8) +
        geom_point(data = out[element==e & org_unit_id==o & sex==s & outlier==TRUE], aes(x=date, y=fitted_value), 
                   color='#4575b4', size=3, alpha=0.8) +
        facet_wrap(~subpop) +
        scale_color_manual(values=greys)+
        geom_ribbon(data = out[element==e & org_unit_id==o & sex==s], aes(ymin=lower_mid, ymax=upper_mid), 
                    alpha=0.2, fill='#feb24c', color=NA) +
        geom_ribbon(data = out[element==e & org_unit_id==o & sex==s], aes(ymin=lower, ymax=upper), 
                    alpha=0.2, fill='#feb24c', color=NA) +
        labs(title=title, subtitle=subtitle, x='Date', y='Count',
             color='Age') +
        theme_bw()
      
      i=i+1
      
    }}}

#--------------------------------
# print out the list of plots into a pdf
pdf(paste0(dir, 'pnls_outliers/pnls_outputs/arv_outliers.pdf'), height=6, width=10)

for(i in seq(length(list_of_plots))) { 
  print(list_of_plots[[i]])
} 

dev.off()

#--------------------------------
# create a data set exclusively of the outliers to remove
# save it to remove from the full data 

out[ , c('combine', 'count'):=NULL]
out = out[outlier==T]

saveRDS(out, paste0(dir, 'pnls_outliers/list_of_arv_outliers.rds'))

#--------------------------------





