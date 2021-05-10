# Install and load the relevant packages ####
library(rinat)
library(sf)
library(dplyr)
library(keras)
library(caret)


# Pre-prepared scripts that have been provided to facilitate easier downloading and renaming of images
source("download_images.R") 
gb_ll <- readRDS("gb_simple.RDS")

# Search and download species images ####

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


# The images must be divided into 3 groups; Training, Validation and testing ####

# Path to folder with photos
image_files_path <- "images" 

# List of spp to model; these names must match folder names
spp_list <- dir(image_files_path) # Automatically pick up names
#spp_list <- c("common spotted orchid", "poppy", "dandelion") # manual entry

# Number of spp classes (i.e. 3 species in this example)
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

# Configuring the model ####

# Number of training samples
train_samples <- train_image_array_gen$n
# Number of validation samples
valid_samples <- valid_image_array_gen$n

# define batch size and number of epochs
batch_size <- 32 # Useful to define explicitly as we'll use it later
epochs <- 10     # How long to keep training going for

# Define the structure of the CNN
# initialise model
model <- keras_model_sequential()

# Add layers
model %>%
  layer_conv_2d(filter = 32, kernel_size = c(3,3), input_shape = c(img_width, img_height, channels), activation = "relu") %>%
  
  # Second hidden layer
  layer_conv_2d(filter = 16, kernel_size = c(3,3), activation = "relu") %>%
  
  # Use max pooling
  layer_max_pooling_2d(pool_size = c(2,2)) %>%
  layer_dropout(0.25) %>%
  
  # Flatten max filtered output into feature vector and feed into dense layer
  layer_flatten() %>%
  layer_dense(100, activation = "relu") %>%
  layer_dropout(0.5) %>%
  
  # Outputs from dense layer are projected onto output layer
  layer_dense(output_n, activation = "softmax") 

# Check it is running
print(model)

# Compile the model
model %>% compile(
  loss = "categorical_crossentropy",
  optimizer = optimizer_rmsprop(lr = 0.0001, decay = 1e-6),
  metrics = "accuracy"
)

# Train the model ####
# Do this with fit_generator
history <- model %>% fit_generator(
  # training data
  train_image_array_gen,
  
  # epochs
  steps_per_epoch = as.integer(train_samples / batch_size), 
  epochs = epochs, 
  
  # validation data
  validation_data = valid_image_array_gen,
  validation_steps = as.integer(valid_samples / batch_size),
  
  # print progress
  verbose = 2
)

# View the results
plot(history)

# Save the model so it can be used later ####
# The imager package also has a save.image function, so unload it to avoid any confusion
detach("package:imager", unload = TRUE)

# The save.image function saves the whole R workspace
save.image("flora.RData")

# Saves only the model, with all its weights and configuration, in a special
# hdf5 file on its own. You can use load_model_hdf5 to get it back.
#model %>% save_model_hdf5("flora_simple.hdf5")

#For larger models, especially if you are fine-tuning them and want to 
#compare outputs and predictions, it is better to use the dedicated Keras 
#save_model_hdf5 which stores it in a special hdf5 format. You can retrieve a model using the load_model_hdf5 command.

# Test the model ####

path_test <- "test"

test_data_gen <- image_data_generator(rescale = 1/255)

test_image_array_gen <- flow_images_from_directory(path_test,
                                                   test_data_gen,
                                                   target_size = target_size,
                                                   class_mode = "categorical",
                                                   classes = spp_list,
                                                   shuffle = FALSE, # do not shuffle the images around
                                                   batch_size = 1,  # Only 1 image at a time
                                                   seed = 123)

# Takes about 3 minutes to run through all the images
model %>% evaluate_generator(test_image_array_gen, 
                             steps = test_image_array_gen$n)


