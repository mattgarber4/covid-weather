# Covid Weather
Analysis of COVID-19 spread in the US by weather patterns


NOTE: To run the data manipulations, extract `raw/2020-weather.zip` directly to the raw folder as `raw/2020-weather.csv`.

Then, to produce the entire transformation pipeline, run `generate-station-subset.R` then `station-geocode.ipynb` then `covid-weather-combine.R`.


# Data Schema
File: `covid-weather-merged.csv` Weather and COVID case and death data by US county for all 50 states plus DC.
- DATE: Date of observation in YYYY-MM-DD form
- COUNTY: County name (string)
- STATE: State code (includes DC and the 50 states)
- CASES: Cases reported by the New York Times
- DEATHS: Deaths reported by NYT
- TMAX: Maximum temperature (degrees F)
- NMAX: Number of weather stations that measured max temp
- TMIN: Minimum temperature (degrees F)
- NMIN: Number of weather stations that measured min temp
- TAVG: Average temperature (degrees F)
- NAVG: Number of weather stations that measured average temp
- PRCP: Inches of precipitation
- NPRCP: Number of weather stations that measured precipiation
- NUM: Total number of weather stations that reported any measurements 

NOTE: To comply with COVID-19 case and death data from NYT, certain geographic aggregations are made. All five counties encompassing New York City are combined, as are all four counties overlapping Kansas City, MO.
