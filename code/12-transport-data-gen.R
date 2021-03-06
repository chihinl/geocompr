# Aim: download, preprocess, save input data - todo: save as R script
devtools::install_github("ropensci/osmdata")
library(osmdata)
region = getbb("Bristol", format_out = "sf_polygon") %>%
  st_set_crs(4326)
region = st_sf(data.frame(Name = "Bristol (OSM)"), geometry = region$geometry)
saveRDS(region, "extdata/bristol-region.rds")
devtools::install_github("robinlovelace/ukboundaries")
library(ukboundaries)
region_ttwa = ttwa_simple %>% 
  filter(grepl("Bristol", ttwa11nm)) %>% 
  select(Name = ttwa11nm)
region_ttwa$Name = "Bristol (TTWA)"
saveRDS(region_ttwa, "extdata/bristol-ttwa.rds")
zones_cents = st_centroid(msoa2011_vsimple)[region_ttwa, ]
plot(zones_cents$geometry)
zones = msoa2011_vsimple[msoa2011_vsimple$msoa11cd %in% zones_cents$msoa11cd, ] %>% 
  select(geo_code = msoa11cd, name = msoa11nm) %>% 
  mutate_at(1:2, as.character)
plot(zones$geometry, add = TRUE)
# Add travel data to the zones
# using wicid open data - see http://wicid.ukdataservice.ac.uk/
unzip("~/Downloads/wu03ew_v2.zip")
od_all = read_csv("wu03ew_v2.csv")
file.remove("wu03ew_v2.csv")
od = od_all %>% 
  select(o = `Area of residence`, d = `Area of workplace`, all = `All categories: Method of travel to work`, bicycle = Bicycle, foot = `On foot`, car_driver = `Driving a car or van`, train = Train) %>%
  filter(o %in% zones$geo_code & d %in% zones$geo_code, all > 19)
summary(zones$geo_code %in% od$d)
summary(zones$geo_code %in% od$o)
saveRDS(zones, "extdata/bristol-zones.rds")
saveRDS(od, "extdata/bristol-od.rds")
bb = st_bbox(region_ttwa)
ways_road = opq(bbox = bb) %>% 
  add_osm_feature(key = "highway", value = "motorway|cycle|primary|secondary", value_exact = FALSE) %>% 
  osmdata_sf()
ways_rail = opq(bbox = bb) %>% 
  add_osm_feature(key = "railway", value = "rail") %>% 
  osmdata_sf()
res = c(ways_road, ways_rail)

summary(res)

rail_stations = res$osm_points %>% 
  filter(railway == "station" | name == "Bristol Temple Meads")
# most important vars:
map_int(rail_stations, ~ sum(is.na(.))) %>% 
  sort() %>% 
  head()
rail_stations = rail_stations %>% select(name)
saveRDS(rail_stations, "extdata/rail_stations.rds")

ways = st_intersection(res$osm_lines, region_ttwa)
ways$highway = as.character(ways$highway)
ways$highway[ways$railway == "rail"] = "rail"
ways$highway = gsub("_link", "", x = ways$highway) %>% 
  gsub("motorway|primary|secondary", "road", x = .) %>% 
  as.factor()
ways = ways %>% 
  select(highway, maxspeed, ref)
summary(st_geometry_type(ways))
# convert to linestring
ways = st_cast(ways, "LINESTRING")
summary(st_geometry(ways))
saveRDS(ways, "extdata/ways.rds") # save for future reference