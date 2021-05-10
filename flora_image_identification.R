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


# The images must be divided into 3 groups; Training, Validation and testing

image_files_path <- "images" # path to folder with photos

# list of spp to model; these names must match folder names
spp_list <- dir(image_files_path) # Automatically pick up names
#spp_list <- c("common spotted orchid", "poppy", "dandelion") # manual entry

# number of spp classes (i.e. 3 species in this example)
output_n <- length(spp_list)

# Create test, and species sub-folders
for(folder in 1:output_n){
  dir.create(paste("test", spp_list[folder], sep="/"), recursive=TRUE)
}

# Copy over spp_501.jpg to spp_600.jpg using two loops, deleting the photos
# from the original images folder after the copy ensuring the same photos are not used for multiple processes
for(folder in 1:output_n){
  for(image in 501:600){
    src_image  <- paste0("images/", spp_list[folder], "/spp_", image, ".jpg")
    dest_image <- paste0("test/"  , spp_list[folder], "/spp_", image, ".jpg")
    file.copy(src_image, dest_image)
    file.remove(src_image)
  }
}

# Scale down the image size
img_width <- 150
img_height <- 150
target_size <- c(img_width, img_height)

# Full-colour Red Green Blue = 3 channels
channels <- 3

# Rescale from 255 (max colour hue) to between zero and 1 and define the proportion of images used for Validation, here 20%
train_data_gen = image_data_generator(
  rescale = 1/255,
  validation_split = 0.2
)

# Training images
train_image_array_gen <- flow_images_from_directory(image_files_path, 
                                                    train_data_gen,
                                                    target_size = target_size,
                                                    class_mode = "categorical",
                                                    classes = spp_list,
                                                    subset = "training",
                                                    seed = 42)

# Validation images
valid_image_array_gen <- flow_images_from_directory(image_files_path, 
                                                    train_data_gen,
                                                    target_size = target_size,
                                                    class_mode = "categorical",
                                                    classes = spp_list,
                                                    subset = "validation",
                                                    seed = 42)

# Check that correct number of images have been read in for each process
cat("Number of images per class:")

table(factor(train_image_array_gen$classes))

cat("Class labels vs index mapping")

train_image_array_gen$class_indices

# Look at one of the images to view the sort of difficulties you may be encountering
plot(as.raster(train_image_array_gen[[1]][[1]][8,,,]))

