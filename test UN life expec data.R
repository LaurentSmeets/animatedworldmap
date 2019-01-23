

# load libraries
library(curl)
library(readxl)
library(data.table)
library(rworldmap)
library(ggplot2)
library(dplyr)
library(tweenr)
library(ggthemes)
library(viridis)
library(rgeos)
library(countrycode)
library(devtools)
#install_github("dgrtwo/gganimate", ref = "26ec501")
library(gganimate)


# DATA: Download data
URL <- "https://population.un.org/wpp/DVD/Files/1_Indicators%20(Standard)/EXCEL_FILES/3_Mortality/WPP2017_MORT_F07_1_LIFE_EXPECTANCY_0_BOTH_SEXES.xlsx"
curl_download(url=URL, destfile="LIFE_EXPECTANCY_0_BOTH_SEXES.xlsx", quiet=FALSE, mode="wb")


# Read historic data
df1 <- read_excel( path= "LIFE_EXPECTANCY_0_BOTH_SEXES.xlsx", sheet="ESTIMATES", skip = 16)
# Read projected data
df2 <- read_excel( path= "LIFE_EXPECTANCY_0_BOTH_SEXES.xlsx", sheet="MEDIUM VARIANT", skip = 16)

# Merge historic and projected data
setDT(df2)[, Notes := NULL][, Variant := NULL]
df <- left_join(df1, df2, by=c("Index", "Region, subregion, country or area *", "Country code"))
setDT(df)

# change name of column
colnames(df)[3] <- c("country")

# drop first 14 rows with information aggregated for continents etc
df <- df[-c(1:14),]

# get standard country codes for latter merge with spatial data
df[, country_iso3c := countrycode(country, 'country.name', 'iso3c')]

# quick note: these UN data don't bring life expectancy data for Greenland, Kosovo, San Marino, Somaliland and Taiwan.



# data in wide format
head(df)

# Reshape to long format
# get name of columns with years of reference
year_cols <- colnames(df)[6:35]

# Reshape data
dt <- melt(df, id.vars = c("country", "country_iso3c"),
           measure.vars = year_cols,
           variable.name= "year",
           value.name= "life_expect")

# data in long format
head(dt)

# get Min and Max values of life expectancy
vmax <- max(dt$life_expect, na.rm=T)
vmin <- min(dt$life_expect, na.rm=T)


wmap <- getMap()

# small edits
wmap <- spTransform(wmap, CRS("+proj=robin")) # reproject
wmap <-   subset(wmap, !(NAME %like% "Antar")) # Remove Antarctica

# get centroids of countries
centroids <- gCentroid( wmap , byid=TRUE, id = wmap@data$ISO3)
centroids <- data.frame(centroids)
setDT(centroids, keep.rownames = TRUE)[]
setnames(centroids, "rn", "country_iso3c")

#join data to map
wmap_df <- fortify(wmap, region = "ISO3")
wmap_df <- left_join(wmap_df, dt, by = c('id'='country_iso3c'))        # data
wmap_df <- left_join(wmap_df, centroids, by = c('id'='country_iso3c')) # centroids



# plot
o <- ggplot(data=wmap_df) +
  geom_polygon(aes(x = long, y = lat, group = group, fill=life_expect, frame = year), color="gray90") +
  geom_text(aes(x = x, y = y, label = round(life_expect), frame = year), hjust=0, vjust=0, size = 4.5) +
  scale_fill_viridis(name="Life Expectancy", begin = 0, end = 1, limits = c(vmin,vmax), na.value="gray99") +
  theme_void() +
  guides(fill = guide_colorbar(title.position = "top")) +
  labs(title = "Life Expectancy, ") +
  labs(caption = "Map by Rafael H M Pereira, @UrbanDemog\nsource: UN World Population Prospects 2015 Revision") +
  theme(plot.title = element_text(hjust = 0.5, vjust = 0.05, size=25)) +
  theme(plot.caption = element_text(hjust = 0, color="gray40", size=15)) +
  coord_cartesian(xlim = c(-11807982, 14807978)) +
  theme( legend.position = c(.5, .08), 
         legend.direction = "horizontal", 
         legend.title.align = 0,
         legend.key.size = unit(1.3, "cm"),
         legend.title=element_text(size=17), 
         legend.text=element_text(size=13) )

# save gif
gg_animate(o, "output4020_old.gif", title_frame =T, 
           ani.width=1600, ani.height=820, dpi=800, interval = .4)
