# Convert_PALWx.R
#
# Created 11/23/15 by J.R.C.
#
# Purpose: Parse Palmer Station, Antarctica, 1 or 2-minute weather data in multiple files and generate a single table. Data currently exist as daily .txt files.
#
################ Caveats and prerequisites #############
#
# Requires R packages "stringr", "RSEIS"
#

library(stringr)
library(RSEIS)

# setwd("/Users/jrcollins/Dropbox/Cruises & projects/High-Lat Lipid Peroxidation/Palmer 2015-2016/Wx data/")
setwd("/Users/jrcollins/Dropbox/Cruises & projects/High-Lat Lipid Peroxidation/Palmer 2015-2016/Wx data/Past seasons/")

# assumes user wants to read in all files in the directory, which may contain a mixture of 1- and 2-minute files

################ 1-minute files #############

file_list.1min = list.files(recursive=TRUE, full.names=FALSE, pattern="_BASE.txt") # get list of daily 1-minute files to be parsed

if (length(file_list.1min)>0) { # let's not do this if there aren't any 1-minute files...

for (i in 1:length(file_list.1min)) {
  
  this.Wxfile = read.delim(file_list.1min[i], header = TRUE, sep="\t", colClasses = "character")
      
  if (i==1) { # it's the first file
        
    allWx.1min = this.Wxfile
    
  } else { # it's not the first file, so rbind
    
    allWx.1min = rbind(allWx.1min,this.Wxfile)
    
  }
  
}

# export to .csv

startdate.1min = str_extract(file_list.1min[i], "[0-9]+")
enddate.1min = str_extract(file_list.1min[length(file_list.1min)], "[0-9]+")

write.csv(allWx.1min, paste("PALWx_1min_",startdate.1min,"-",enddate.1min,".csv",sep=""))

}

################ 2-minute files #############

file_list.2min = list.files(recursive=TRUE, full.names=FALSE, pattern=".100") # get list of 2-minute data files to be parsed

if (length(file_list.2min)>0) { # let's not do this if there aren't any 2-minute files...

for (i in 1:length(file_list.2min)) {
  
  this.Wxfile = read.delim(file_list.2min[i], header = TRUE, sep="\t", colClasses = "character", skip = 1)
  
  if (i==1) { # it's the first file
    
    allWx.2min = this.Wxfile
    
  } else { # it's not the first file, so rbind
    
    allWx.2min = rbind(allWx.2min,this.Wxfile)
    
  }
  
}

# export to .csv

startdate.2min = str_extract(file_list.2min[i], "[0-9]+")
enddate.2min = str_extract(file_list.2min[length(file_list.2min)], "[0-9]+")

write.csv(allWx.2min, paste("PALWx_2min_",startdate.2min,"-",enddate.2min,".csv",sep=""))

}

################ Generate some useful date-time related fields for plotting #############

# create some timestamps in a format R understands as timestamps (POSIXct), then append to allWx.2min

allWx.2min_timestamps = as.POSIXlt(strptime(allWx.2min[,1], "%Y/%m/%d %I:%M:%S %p"),format='%Y-%m-%d %T')
allWx.2min = cbind(allWx.2min,allWx.2min_timestamps)
colnames(allWx.2min)[30] = c("Local.Date.and.Time_POSIXct")

# generate, append some decimal julian days (year-agnostic)
# requires package RSEIS

dec_Jdays = JtimL(list(jd = as.POSIXlt(allWx.2min$Local.Date.and.Time_POSIXct)$yday,
                       hr = as.POSIXlt(allWx.2min$Local.Date.and.Time_POSIXct,format='%Y-%m-%d %H:%M:%S')$hour,
                       mi = as.POSIXlt(allWx.2min$Local.Date.and.Time_POSIXct)$min,
                       sec = as.POSIXlt(allWx.2min$Local.Date.and.Time_POSIXct)$sec))

allWx.2min = cbind(allWx.2min,dec_Jdays)
colnames(allWx.2min)[31] = c("Decimal.Jday")

################ Some subsetting #############

# some additional code to create subsets by date, using the allWx.2min data

# subset by select dates, days, months, etc
# some examples here that work

# extract data from a select date range

allWx.2min_select.dates = subset(allWx.2min, Local.Date.and.Time_POSIXct >= 2010-04-01 | Local.Date.and.Time_POSIXct <= 2011-03-01)

# extract data from all years falling between the same two days of the year

allWx.2min_allyears.28Oct.to.23Nov = subset(allWx.2min, (as.POSIXlt(Local.Date.and.Time_POSIXct)$mon>=1 & as.POSIXlt(Local.Date.and.Time_POSIXct)$mon==10) | (as.POSIXlt(Local.Date.and.Time_POSIXct)$mday<24 & as.POSIXlt(Local.Date.and.Time_POSIXct)$mon==11))

# plot wind data from allWx.2min_allyears.28Oct.to.23Nov according to Decimal.Jday
# WS.avg.2min*1.94 for m/s to knots

plot(allWx.2min_allyears.28Oct.to.23Nov$Decimal.Jday,as.numeric(allWx.2min_allyears.28Oct.to.23Nov$WS.avg.2min)*1.94,pch=19,cex=0.2)

# plot by year, overlayed

# get list of years in this subset
yearstoplot = unique(as.POSIXlt(allWx.2min_allyears.28Oct.to.23Nov$Local.Date.and.Time_POSIXct)$year+1900)

# generate some colors to plot
color_ramp <- colorRampPalette(c("#00007F", "blue", "#007FFF", "cyan","#7FFF7F", "yellow", "#FF7F00", "red", "#7F0000"))
colors = color_ramp(length(yearstoplot))

# plot each successive year

dev.off()

for (i in 1:length(yearstoplot)) {
  
  this.year = allWx.2min_allyears.28Oct.to.23Nov[(as.POSIXlt(allWx.2min_allyears.28Oct.to.23Nov$Local.Date.and.Time_POSIXct)$year+1900)==yearstoplot[i],]
  
  if (i==1) {
    
    plot(this.year$Decimal.Jday,as.numeric(this.year$WS.avg.2min)*1.94,type="l",cex=0.2,col=colors[i],
         ylab="Wind speed (knots)",xlab="Day of year")
    
    # superimpose lines at 34, 40 knots
    
    abline(40,0,col="grey",lwd=3)
    abline(34,0,col="grey",lwd=3)
    
  } else {
    
    lines(this.year$Decimal.Jday,as.numeric(this.year$WS.avg.2min)*1.94,pch=19,cex=0.2,col=colors[i])
  
  }
    
}