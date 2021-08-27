#!/usr/bin/env bash

# --------------------------------------------------------------------------------------------------------------------

PYTHON_VERSION="3.9"

# --------------------------------------------------------------------------------------------------------------------

echo "-------------------------------------------------------------------------"
echo "Creating new Conda Environment 'movingpandas'"
echo "-------------------------------------------------------------------------"

# update Conda platform
echo "y" | conda update conda

# WARNING - removes existing environment
conda env remove --name movingpandas

# Create Conda environment
echo "y" | conda create -n movingpandas python=${PYTHON_VERSION}

# activate and setup env
conda activate movingpandas
conda config --env --add channels conda-forge
conda config --env --set channel_priority strict

# reactivate for env vars to take effect
conda activate movingpandas

# install packages for sedona only
echo "y" | conda install -c conda-forge dask movingpandas pyarrow jupyter


# --------------------------
# extra bits
# --------------------------

## activate env
#conda activate movingpandas

## shut down env
#conda deactivate

## delete env permanently
#conda env remove --name movingpandas
