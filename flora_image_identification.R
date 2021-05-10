# Install and load the relevant packages
library(rinat)
library(sf)
library(dplyr)
library(keras)
library(caret)


# Pre-prepared scripts that have been provided to facilitate easier downloading and renaming of images
source("download_images.R") 
gb_ll <- readRDS("gb_simple.RDS")



# Search for images of the common spotted orchid
orchid_recs <-  get_inat_obs(taxon_name  = "Dactylorhiza fuchsii",
                                bounds = gb_ll,
                                quality = "research",
                                # month=6,   # Month can be set.
                                # year=2018, # Year can be set.
                                maxresults = 600)

# The images can then be downloaded and placed into a sub-folder
download_images(spp_recs = orchid_recs, spp_folder = "common spotted orchid")

# Do the same for the remaining two species
# Common Poppy; Papaver rhoeas
poppy_recs <-  get_inat_obs(taxon_name  = "Papaver rhoeas",
                            bounds = gb_ll,
                            quality = "research",
                            maxresults = 600)

download_images(spp_recs = poppy_recs, spp_folder = "poppy")

# Common Dandelion; Taraxacum officinale
dandelion_recs <-  get_inat_obs(taxon_name  = "Taraxacum officinale",
                                bounds = gb_ll,
                                quality = "research",
                                maxresults = 600)

download_images(spp_recs = dandelion_recs, spp_folder = "dandelion")


