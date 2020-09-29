setwd("~/Covid")
library(myUtils)
library(data.table)

weather.by.state <- fread("raw/2020-weather.csv")
ghcnd.stations <- readLines("raw/ghcnd-stations.txt")


ghcnd.stations <-  data.frame(
    ID = trimws(substr(ghcnd.stations, 1, 11)),
    LAT = as.numeric(substr(ghcnd.stations, 13, 20)),
    LON = as.numeric(substr(ghcnd.stations, 22, 30)),
    ELEVATION = as.numeric(substr(ghcnd.stations, 32, 37)),
    STATE = trimws(substr(ghcnd.stations, 39, 40))
  )

ghcnd.stations <- ghcnd.stations[ghcnd.stations$ID %in% weather.by.state$V1, ]
ghcnd.stations <- ghcnd.stations[ghcnd.stations$STATE %in% c("DC", state.abb), ]

write.csv(ghcnd.stations, file = "stations/stations-subset.csv", row.names = F)

