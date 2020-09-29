setwd("~/Covid")
library(myUtils)
library(data.table)
library(dplyr)
library(tidyr)
library(weathermetrics)


### STATIONS
stations <- fread("stations/stations-subset-with-counties.csv")
stations$county <- gsub(" County$", "", stations$county)

stateNameToAbb <- function(s) {
  names.vec <- c(state.name, "District of Columbia")
  abb.vec <- c(state.abb, "DC")
  abb.vec[match(s, names.vec)]
}

sum(stations$STATE != stateNameToAbb(stations$state2))

stations <- stations[stations$STATE == stateNameToAbb(stations$state2), ]

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

# remove clear outliers
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
                        stations[,c("ID", "county", "STATE")], 
                        by = "ID", all = F)

colnames(weather.merged) <- toupper(colnames(weather.merged))


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
idx <- weather.aggregated$COUNTY == 'King' & weather.aggregated$STATE == 'WA'
plot(weather.aggregated$DATE[idx], weather.aggregated$PRCP[idx])

summary(weather.aggregated)


# create full dataset
covid <- fread('raw/us-counties-covid.csv', drop = "fips")
colnames(covid) <- toupper(colnames(covid))
covid$STATE <- stateNameToAbb(covid$STATE)
covid <- covid[!is.na(covid$STATE), ]


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

uniqueID(out[, c("DATE", "COUNTY", "STATE")])

summary(out)

write.csv(out, file = "covid-weather-merged.csv", row.names = F)
