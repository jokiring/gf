# -------------------------------------------
# David Phillips
#
# 12/11/2017
# Analyze correlates of absorption
# -------------------------------------------


# ------------------
# Set up R
rm(list=ls())
library(boot)
library(readxl)
library(data.table)
library(stringr)
library(ggplot2)
# ------------------


# -----------------------------------------------------------------
# Files and directories

# root directory for input/output
dir = 'J:/Project/Evaluation/GF/resource_tracking/multi_country/'

# input data
inFile = paste0(dir, 'mapping/gos_programs_mapped_1211.csv')

# output graphs
outFile = paste0(dir, '/visualizations/absorption_correlates.pdf')
# -----------------------------------------------------------------


# ----------------------------------------------------------------------
# Load/prep data

# load
data = fread(inFile)

# collapse to standard program_activities
byVars = c('disease','Country','grant_number','Year','program_activity')
data=data[, list('budget'=sum(budget,na.rm=TRUE), 
			'expenditure'=sum(expenditure,na.rm=TRUE)), by=byVars]

# compute cumulative budget/expenditure by grant-SDA
byVars = c('grant_number','program_activity')
data[, cumulative_budget:=cumsum(budget), by=byVars]
data[, cumulative_expenditure:=cumsum(expenditure), by=byVars]

# budget/expenditure in millions
data[,budget:=budget/1000000]
data[,expenditure:=expenditure/1000000]

# compute absorption
data[, absorption:=cumulative_expenditure/cumulative_budget]

# handle 1's and 0's so logit doesn't drop them
# data[absorption>=1 & is.finite(absorption), absorption:=max(data[absorption<1]$absorption)] 
# data[absorption>=0 & is.finite(absorption), absorption:=min(data[absorption>0]$absorption)] 
data = data[absorption<1 & absorption>0]
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# Generate extra predictor variables

# year within grant and years from end of grant
data[, grant_year:=as.numeric(as.factor(Year)), by='grant_number']
data[, years_from_end:=max(grant_year)-grant_year+1, by='grant_number']

# number of SDAs within grant
data[, num_sdas:=length(unique(program_activity)), by='grant_number']

# grant window 
# (shouldn't matter; already captured in complexity/size/SDA composition)
data[Year<2008, window:=1]
data[Year>=2008 & Year<2011, window:=2]
data[Year>=2011 & Year<2014, window:=3]
data[Year>=2014 & Year<2017, window:=4]
data[Year>=2017 & Year<2020, window:=5]
# ----------------------------------------------------------------------


# ----------------------------------------------------------
# Run regressions

# all confounding variables to SDA
form1 = as.formula('logit(absorption) ~ 
					years_from_end + disease + Country + 
					log(cumulative_budget) + num_sdas')
lmFit1 = lm(form1, data=data)
summary(lmFit1)

# program activity controlling for all confounders
form2 = as.formula('logit(absorption) ~ program_activity + 
					years_from_end + disease + Country + 
					log(cumulative_budget) + num_sdas')
lmFit2 = lm(form2, data=data)
# ----------------------------------------------------------


# -------------------------------------------------------------------------------------------------
# Store regression results

# regression coefficients from model 1 (all but SDA)
coefs1 = data.table(cbind(names(coef(lmFit1)), summary(lmFit1)$coefficients, confint(lmFit1)))
setnames(coefs1, c('variable','est','se','t','p','lower','upper'))
coefs1 = coefs1[, lapply(.SD, as.numeric), .SDcols=c('est','p','lower','upper'), by='variable']
# coefs1 = coefs1[, lapply(.SD, inv.logit), .SDcols=c('est','lower','upper'), by=c('variable','p')]

# predictions from model 2 (full model) 
# set to the most central categories for all other variables
coefs2 = data.table(unique(data$program_activity))
setnames(coefs2, 'program_activity')
coefs2[, years_from_end:=1]
coefs2[, disease:='hiv']
coefs2[, Country:='Congo (Democratic Republic)']
coefs2[, cumulative_budget:=median(data$cumulative_budget)]
coefs2[, num_sdas:=median(data$num_sdas)]
coefs2 = cbind(coefs2, inv.logit(predict(lmFit2, newdata=coefs2, interval='confidence')))
# -------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------
# Set up to graph

# labels
coefs1[variable=='(Intercept)', label:='Intercept']
coefs1[variable=='years_from_end', label:='Years from Grant End']
coefs1[variable=='diseasemalaria', label:='Component: Malaria']
coefs1[variable=='diseasetb', label:='Component: TB']
coefs1[variable=='CountryGuatemala', label:='Country: Guatemala']
coefs1[variable=='CountryUganda', label:='Country: Uganda']
coefs1[variable=='log(cumulative_budget)', label:='Log-Cumulative Budget']
coefs1[variable=='num_sdas', label:='Number of SDAs']
# coefs2[, label:=str_wrap(program_activity, 32)]
coefs2[, label:=program_activity]
coefs2[label=='HIV/TB collaborative interventions', label:='HIV/TB collaborative\ninterventions']
data[, label:=str_wrap(program_activity, 22)]

# identify highly-comoditized program areas
commodities = c('Case detection and diagnosis', 'Treatment', 'Malaria indoor residual spraying', 'MDR-TB treatment', 'Malaria bed nets', 'MDR-TB case detection and diagnosis', 'MDR-TB treatment', 'Prevention')
coefs2[, commoditized:=ifelse(program_activity %in% commodities, 'Commoditized', 'Programmatic')]

# store aggregate absorption
agg = sum(data$expenditure)/sum(data$budget)

# store average absorption by sda
means = data[, list(absorption=mean(absorption)), by=label]

# colors
cols = c('#008080','#70a494','#b4c8a8','#f6edbd','#edbb8a','#de8a5a','#ca562c')

# other settings
b = 14
# -------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------
# Graphs

# graph data
p1 = ggplot(data, aes(y=absorption*100, x=grant_year, group=grant_number, color=Year)) + 
	geom_line(alpha=.85) + 
	geom_point(alpha=.85, aes(size=budget)) + 
	geom_hline(data=means, aes(yintercept=absorption*100, linetype='Mean')) + 
	facet_wrap(~label, ncol=7) + 
	scale_color_gradientn(colors=cols) + 
	scale_linetype_manual('', values=c('Mean'='solid')) + 
	labs(title='Absorption by Grant and Service Delivery Area', 
			y='Absorption %', x='Year within Grant', size='Budget $\n(Millions)') + 
	theme_bw(base_size=b) + 
	theme(plot.title=element_text(hjust=.5), strip.text=element_text(size=9))

# graph model 1 coefficients
p2 = ggplot(coefs1[label!='Intercept'], aes(y=est, ymin=lower, ymax=upper, x=label)) + 
	geom_bar(stat='identity', fill='#6d819c') + 
	geom_errorbar(width=.2, size=1.1, color='gray25') + 
	labs(title='Regression Coefficients', subtitle='Model 1', caption='Model Intercept not Shown', 
			y='Correlation with Absorption (logit)', x='') + 
	theme_bw(base_size=b) + 
	theme(plot.title=element_text(hjust=.5), plot.subtitle=element_text(hjust=.5), 
			axis.text.x = element_text(angle=45, hjust=1), plot.margin=unit(c(.5,5,.1,5),'cm'))

# graph model 2 predictions
p3 = ggplot(coefs2, aes(y=fit, ymin=lwr, ymax=upr, x=reorder(label,fit))) + 
	geom_bar(stat='identity', aes(fill=commoditized)) + 
	geom_errorbar(width=.25, size=1.1, color='gray25') + 
	geom_hline(yintercept=agg, color='red', lty='longdash') + 
	scale_fill_manual('', values=c('#55967e','#6d819c')) + 
	annotate('text', x=coefs2[fit==max(fit)]$label, y=agg, 
			label='Overall Absorption', hjust=.9, vjust=1.2, size=5) + 
	labs(title='Mean Absorption by Service Delivery Area', 
			caption='Estimates controlling for all variables in model 1', y='Mean Absorption', x='') + 
	theme_bw(base_size=b) + 
	theme(plot.title=element_text(hjust=.5), axis.text.x = element_text(angle=45, hjust=1))
# -------------------------------------------------------------------------------------------------


# -----------------------------
# Save graphs
pdf(outFile, height=6, width=10.5)
p1
p2
p3
dev.off()
# -----------------------------