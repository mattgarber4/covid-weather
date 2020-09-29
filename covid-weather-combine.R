setwd("~/Covid")
library(myUtils) # install from github with devtools::install_github("mattgarber4/myUtils")
library(data.table)
library(dplyr)
library(tidyr)
library(weathermetrics)


### STATIONS
stations <- fread("stations/stations-subset-with-counties.csv")
colnames(stations) <- toupper(colnames(stations))
stations$COUNTY <- gsub(" County$", "", stations$COUNTY)

stateNameToAbb <- function(s) {
  names.vec <- c(state.name, "District of Columbia")
  abb.vec <- c(state.abb, "DC")
  abb.vec[match(s, names.vec)]
}

sum(stations$STATE != stateNameToAbb(stations$STATE2))

stations <- stations[stations$STATE == stateNameToAbb(stations$STATE2), ]

# NYT county exceptions applied here:
stations$COUNTY[stations$COUNTY %in% c('New York', 'Kings', 'Queens', 'Bronx', 'Richmond') & stations$STATE == 'NY'] <- "New York City"
stations$COUNTY[stations$COUNTY %in% c('Cass', 'Clay', 'Jackson', 'Platte') & stations$STATE == 'MO'] <- 'Kansas City'

### WEATHER
weather <- fread("raw/2020-weather.csv", 
                 col.names = c("ID", "DATE", "TYPE", "VAL"),
                 drop = 5:8,
                 nThread = 4)

weather <- weather[weather$TYPE %in% c("PRCP", "TAVG", "TMIN", "TMAX"), ] %>% 
  group_by(ID, DATE, TYPE) %>%
  summarize(VAL = mean(VAL, na.rm = T)) %>%
  ungroup() %>%
  spread(key = TYPE, value = VAL) %>%
  mutate(PRCP = .0393701 * PRCP / 10,
         TMAX = celsius.to.fahrenheit(TMAX / 10),
         TMIN = celsius.to.fahrenheit(TMIN / 10), 
         TAVG = celsius.to.fahrenheit(TAVG / 10), 
         DATE = as.Date(as.character(DATE), format = "%Y%m%d")
         )

# remove clear measurement outliers
inRange <- function(vec, min, max) {
  (min <= vec & vec <= max) | is.na(vec)
}

weather <- weather[inRange(weather$TAVG, -25, 125) &
                     inRange(weather$TMIN, -25, 125) &
                     inRange(weather$TMAX, -25, 125), ]

# temperatures are lining up well with the reported averages :) 
hist(na.omit(weather$TAVG - (weather$TMAX + weather$TMIN) / 2))

summary(weather)



# conduct the merge
weather$ID <- toupper(trimws(weather$ID))
stations$ID <- toupper(trimws(stations$ID))

weather.merged <- merge(weather, 
                        stations[,c("ID", "COUNTY", "STATE")], 
                        by = "ID", all = F)


# aggregate by county
weather.aggregated <- weather.merged %>%
  group_by(DATE, COUNTY, STATE) %>%
  summarize(
    TMAX = mean(na.omit(TMAX)),
    NMAX = length(na.omit(TMAX)),
    TMIN = mean(na.omit(TMIN)),
    NMIN = length(na.omit(TMIN)),
    TAVG = mean(na.omit(TAVG)),
    NAVG = length(na.omit(TAVG)),
    PRCP = mean(na.omit(PRCP)),
    NPRCP = length(na.omit(PRCP)),
    NUM = n()
  )

# sanity checks
idx <- weather.aggregated$COUNTY == 'New York City' & weather.aggregated$STATE == 'NY'
plot(weather.aggregated$DATE[idx], weather.aggregated$TMAX[idx])

summary(weather.aggregated)


# create full dataset
covid <- fread('raw/us-counties-covid.csv', drop = "fips")
colnames(covid) <- toupper(colnames(covid))
covid$STATE <- stateNameToAbb(covid$STATE)
covid <- covid[!is.na(covid$STATE), ]

# NYT adjustments
covid$COUNTY[covid$COUNTY %in% c('Cass', 'Clay', 'Jackson', 'Platte') & covid$STATE == 'MO'] <- 'Kansas City'

covid <- covid %>%
  group_by(DATE, STATE, COUNTY) %>%
  summarize(CASES = sum(CASES, na.rm = T),
            DEATHS = sum(DEATHS, na.rm = T))

# merge all data together -- first, all date x (state/county) combos, 
# left joined with covid data left joined with weather data
out <- merge(data.frame(DATE = unique(weather.aggregated$DATE)),
             covid[!duplicated(covid[, c("COUNTY", "STATE")]), c("COUNTY", "STATE")],
             all = T) %>%
  merge(covid, 
        by = c("DATE", "COUNTY", "STATE"), 
        all.x = T, 
        all.y = F) %>%
  merge(weather.aggregated,
        by = c("DATE", "COUNTY", "STATE"), 
        all.x = T, 
        all.y = F)

out$CASES[is.na(out$CASES)] <- 0
out$DEATHS[is.na(out$DEATHS)] <- 0


# sanity checks
uniqueID(out[, c("DATE", "COUNTY", "STATE")])
summary(out)

write.csv(out, file = "covid-weather-merged.csv", row.names = F)
