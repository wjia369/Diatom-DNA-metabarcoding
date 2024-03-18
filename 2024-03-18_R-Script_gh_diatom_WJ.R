# R script to analyze the output data of OBITools 3
# Written by Weihan Jia
# Date: 18 March 2024

rm(list=ls())

library(readxl)
library(stringr)
library(tidyverse)
library(RColorBrewer)
library(vegan)
library(dplyr)

setwd("E:/Diatom_DNA_MX/obi3_results")

# load all csv data
#df <- read.csv2("Book1.csv", header=TRUE, stringsAsFactors = FALSE, sep=',',encoding="UTF-8")
mydata <- lapply(list.files(pattern="\\.csv$"), read.delim)

# choose the columns we need
mydata_filter <- lapply(mydata, function(df) {
  df %>%
    select(NUC_SEQ, ID, COUNT, BEST_IDENTITY, SCIENTIFIC_NAME, family_name, genus_name, species_name)
})

# rename the sample name
rename_ID <- function(df) {
  df$ID <- sub("_[^_]*$", "", df$ID)
  return(df)
}

mydata_filter_modified <- lapply(mydata_filter, rename_ID)

# combine the rows from all dataframes
combined_df <- do.call(rbind, mydata_filter_modified)

# only select the sequences with identity>=0.98
combined_df_id1 <- subset(combined_df, BEST_IDENTITY >= 0.98)

# spread the dataframe
spread_df <- spread(combined_df_id1, key = ID, value = COUNT, fill = 0)


# check if there are logical values
var_log<- NULL
for (i in 1:dim(spread_df)[2]){
  
  if(is.logical(spread_df[, i])){
    var_log <- c(var_log, i)
  }
  else{i = i+1}
}

# if yes, transfer them to numeric values
for (i in 1:length(var_log)){
  spread_df[, var_log[i]]<-as.numeric(spread_df[, var_log[i]])
  i = i+1
}

str(spread_df)

# remove 'BEST_IDENTITY'
spread_df <- spread_df[,-2]

# save the output table
write.table(spread_df, "diatom_XM_RBCL_id0.98_18.03.2024.csv", sep = ",", row.names=FALSE)

# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------



