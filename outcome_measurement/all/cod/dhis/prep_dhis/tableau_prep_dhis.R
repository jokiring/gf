# Use prepped SNIS data to create a Tableau data set

# ----------------------------------------------
# Caitlin O'Brien-Carelli
# 9/11/2018
# ----------------------------------------------

# --------------------
# Set up R
rm(list=ls())
library(data.table)
library(ggplot2)
library(dplyr)
library(openxlsx) # does not work on the cluster
library(stringr) 
# --------------------

# --------------------
# set working directories 

# detect if operating on windows or on the cluster 
root = ifelse(Sys.info()[1]=='Windows', 'J:', '/home/j')

# set the directory for input and output
dir <- paste0(root, '/Project/Evaluation/GF/outcome_measurement/cod/dhis/')

# set the folder for 
folder <- 'prepped/'

# import the tableau data sets and rbind them together 
base <- readRDS(paste0(dir, folder, 'tabl_base_no_outliers.rds'))
sigl <- readRDS(paste0(dir, folder, 'tabl_sigl_no_outliers.rds'))
pnls <- readRDS(paste0(dir, folder, 'tabl_pnls_no_outliers.rds'))

# subset pnls - this should now be in the prep code
pnls <- pnls[element_id!='Gv1UQdMw5wL']
x <- pnls[element_id=='jJuipTLZK4o' & category=='Sortie']
pnls <- pnls[element_id!='jJuipTLZK4o']
pnls <- rbind(pnls, x)

base[ ,set:='base']
sigl[ ,set:='sigl']
pnls[ ,set:='pnls']

#-------------------------
# rbind the data sets together

dt1 <- rbind(base, sigl)
dt <- rbind(dt1, pnls)

#----
# report health zone level data as well as facility
# don't run this if it's in the prep code
# dt[level=='health_zone', health_zone1:=org_unit]
# 
# # replace health zone
# dt$health_zone2 <- unlist(lapply(strsplit(dt$health_zone1, " "), "[", 2))
# dt$health_zone3 <- unlist(lapply(strsplit(dt$health_zone1, " "), "[", 3))
# dt[health_zone3!='Zone', health_zone1:=paste(health_zone2, health_zone3) ]
# dt[health_zone3=='Zone', health_zone1:=health_zone2]
# 
# dt[level=='health_zone' ,health_zone:=health_zone1]
# dt[ , c('health_zone1', 'health_zone2', 'health_zone3'):=NULL]

#-------------------------------------------------------------------------
# check the english translations of the elements
# for future downloads, change the english translations in the csv so they are correct after merge

# change order of drug names and dosage to mirror the french elements
dt[element_id=='KEv4JxAgpFK', element_eng:='C2 12.2 Determine HIV 1 + 2 test kit - quantity consumed']
dt[element_id=='QvVGcIERRFc', element_eng:='C1 12.1 Artesunate-amodiaquine (12-59 months) 50mg + 135mg tablet - amount consumed']
dt[element_id=='Wo3vNpLXPPm', element_eng:='C1 12.1 Artesunate-amodiaquine (2-11 months) 25mg + 67.5mg tablet  - amount consumed']
dt[element_id=='jm3jeYdVkBl', element_eng:='C1 12.1 Artesunate-amodiaquine (14 years, 6 and over) 100mg + 270mg tablet - amount consumed']
dt[element_id=='ovziGhkDOKb', element_eng:='C1 12.1 Artesunate-amodiaquine (6-13 years, 3 and over) 100mg + 270mg tablet - amount consumed']
dt[element_id=='ncXfF8VViSh', element_eng:='C1 12.1 Rifampicin isoniazid + Pyrimetham Ethamb (RHZE) 150mg + 75mg + 400mg + 275mg these - amount consumed']

dt[element_id=='WjEIQZvEFqa', element_eng:='C1 12.1 Lumefantrine + Artemether 80mg + 480mg - amount consumed' ]
dt[element_id=='aeTpblK0SVC', element_eng:='C1 12.1 Lumefantrine + Artemether 40mg + 240mg - amount consumed' ]

# fix the english translations
dt[element_id=='DXz4Zxd4fKq', element_eng:='Pregnant or lactating women tested for HIV']
dt[element_id=='gHBcPOF5y3z', element_eng:='Pregnant or lactating women who tested HIV+']

# change amount to quantity
dt$element_eng <- gsub("amount", "quantity", dt$element_eng)

#---------------------------------------
# create a variable for the number of facilities reporting

facilities <- dt[ ,.(facilities_reporting=length(unique(org_unit))), 
                  by=.(set, element, date, health_zone, dps, category, level)]

#-----------------------------------
# sum over health zone to change data to the health zone level 

dt <- dt[ ,.(value=sum(value)), by=.(set, data_set, element_id, element, element_eng, date,
                                     category,  health_zone, dps, level, type)]

# merge in the number of facilities
dt = merge(dt, facilities, by=c('set', 'element', 'date', 
                           'health_zone', 'dps', 'category', 'level'))

#----------------------------
# create age and sex variables 
dt[grep(category, pattern='>5'), age:='5+ years']
dt[grep(category, pattern='<5'), age:='Under 5 years']

# code anc visits as female patients
dt[grep(category, pattern='CPN'), sex:='Female']

dt[category=='5 and over', age:='5 +']
dt[category=='Under 5', age:='Under 5']
dt[category=='F�minin, 1 et 4 ans', age:='1 - 4 years']
dt[category=='F�minin, 10 et 14 ans', age:='10 - 14 years']
dt[category=='F�minin, 15 et 19 ans', age:='15 - 19 years']
dt[category=='F�minin, 20 et 24 ans', age:='20 - 24 years']
dt[category=='F�minin, 25 et 49 ans', age:='25 - 49 years']
dt[category=='F�minin, 5 et 9 ans', age:='5 - 9 years']
dt[category=='F�minin, 50 ans et plus', age:='50 +']
dt[category=='F�minin, Moins d\'un an', age:='< 1 year']

dt[category=="F�minin, Moins de 14 ans", age:='< 14 years']
dt[category=="F�minin, 15 et 24 ans", age:='15 - 24 years']
dt[category=="F�minin, 25 ans et plus", age:='25+ years']

dt[category=="Masculin, Moins de 14 ans", age:='< 14 years']
dt[category=="Masculin, 15 et 24 ans", age:='15 - 24 years']
dt[category=="Masculin, 25 ans et plus", age:='25+ years']

dt[category=='Masculin, 1 et 4 ans', age:='1 - 4 years']
dt[category=='Masculin, 10 et 14 ans', age:='10 - 14 years']
dt[category=='Masculin, 15 et 19 ans', age:='15 - 19 years']
dt[category=='Masculin, 20 et 24 ans', age:='20 - 24 years']
dt[category=='Masculin, 25 et 49 ans', age:='25 - 49 years']
dt[category=='Masculin, 5 et 9 ans', age:='5 - 9 years']

dt[category=='Masculin, 50 ans et plus', age:='50 +']
dt[category=='Masculin, Moins d\'un an', age:='< 1 year']
dt[category=='CPN, 15 et 19 ans', age:='15 - 19 years']
dt[category=='CPN, 20 et 24 ans', age:='20 - 24 years']
dt[category=='CPN, 25 et 49 ans', age:='25 - 49 years']
dt[category=='CPN, 50 ans et plus', age:='50 +']
dt[category=='CPN, Moins de 15 ans', age:='< 15 years']
dt[category=='SA/PP, 15 et 19 ans', age:='15 - 19 years']
dt[category=='SA/PP, 20 et 24 ans', age:='20 - 24 years']
dt[category=='SA/PP, 25 et 49 ans', age:='25 - 49 years']
dt[category=='SA/PP, 50 ans et plus', age:='50+']
dt[category=='SA/PP, Moins de 15 ans', age:='< 15 years'] 

# only stock data should be missing sex
dt[is.na(sex), unique(category)]
dt[is.na(sex), unique(category)]

# fix type
dt[set=='pnls', type:='hiv']
dt[type=='malaria ', type:='malaria']
#-------------------------------
# test graphs to confirm it worked

pdf(paste0(dir,'tableau/tableau_indicators.pdf'), height=6, width=12)

base <- dt [set=='base',.(count=sum(value, na.rm=T)), by=.(element_eng, date)]

ggplot(base, aes(x=date, y=count, color=element_eng)) +
  geom_point() +
  geom_line() +
  theme_bw() +
  scale_y_continuous(labels = scales::comma)

sigl <- dt [set=='sigl',.(count=sum(value, na.rm=T)), by=.(element_eng, date)]

ggplot(sigl, aes(x=date, y=count, color=element_eng)) +
  geom_point() +
  geom_line() +
  theme_bw() +
  scale_y_continuous(labels = scales::comma)


pnls <- dt [set=='pnls',.(count=sum(value, na.rm=T)), by=.(element_eng, element_id, date, category)]

ggplot(pnls[element_id=='jJuipTLZK4o' | element_id=='Gv1UQdMw5wL'], aes(x=date, y=count, color=category)) +
  geom_point() +
  geom_line() +
  theme_bw() +
  facet_wrap(~element_eng) +
  scale_y_continuous(labels = scales::comma)

ggplot(pnls[element_id=="DXz4Zxd4fKq"], aes(x=date, y=count, color=category)) +
  geom_point() +
  geom_line() +
  theme_bw() +
  facet_wrap(~element_eng) +
  scale_y_continuous(labels = scales::comma)

ggplot(pnls[element_id=="gHBcPOF5y3z"], aes(x=date, y=count, color=category)) +
  geom_point() +
  geom_line() +
  theme_bw() +
  facet_wrap(~element_eng) +
  scale_y_continuous(labels = scales::comma)

dev.off()

#------------------------------
# add umlauts to merge with tableau

dt[dps=='Kasai', dps:='Kasa�']
dt[dps=='Kasai Central', dps:='Kasa� Central']
dt[dps=='Kasai Oriental', dps:='Kasa� Oriental']
dt[dps=='Mai-Ndombe', dps:='Ma�-Ndombe']

#--------------------------------------------------------

# change type to disease
setnames(dt, 'type', 'disease')
#----------------------------------------------------

#-------------------------------
# Export as an Excel document 

# save as a RDS file 
saveRDS(dt, paste0(dir, 'tableau/tableau_01_2017_06_2018.rds'))

# read in the RDS file so you don't have to rerun the code
#tabl <- readRDS(paste0(dir, 'tableau_01_2017_04_2018.rds'))

#------------------------------
# use xlsx instead of csv because it preserves the french special characters
# use the openxlsx package (not xlsx!) as the java in xlsx cannot accomodate size
# openxlsx works on the cluster (no need to install)

# start and end date are both inclusive
write.xlsx(dt, paste0(dir, 'tableau/tableau_01_2017_06_2018.xlsx'))

#-------------------------------



