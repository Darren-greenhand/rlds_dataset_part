: '
Script for downloading, cleaning and resizing Open X-Embodiment Dataset (https://robotics-transformer-x.github.io/)

Performs the preprocessing steps:
  1. Downloads datasets from Open X-Embodiment
  2. Runs resize function to convert all datasets to 256x256 (if image resolution is larger) and jpeg encoding
  3. Fixes channel flip errors in a few datasets, filters success-only for QT-Opt ("kuka") data

To reduce disk memory usage during conversion, we download the datasets 1-by-1, convert them
and then delete the original.
We specify the number of parallel workers below -- the more parallel workers, the faster data conversion will run.
Adjust workers to fit the available memory of your machine, the more workers + episodes in memory, the faster.
The default values are tested with a server with ~120GB of RAM and 24 cores.
'

BASE_DIR=/data/jcy/data/openx_part
DOWNLOAD_DIR=${BASE_DIR}/origin
CONVERSION_DIR=${BASE_DIR}/convered
# FINAL_DIR=/data/jcy/data/openx_part/final
N_WORKERS=20                  # number of workers used for parallel conversion --> adjust based on available RAM
MAX_EPISODES_IN_MEMORY=200    # number of episodes converted in parallel --> adjust based on available RAM

# increase limit on number of files opened in parallel to 20k --> conversion opens up to 1k temporary files
# in /tmp to store dataset during conversion
ulimit -n 20000

echo "!!! Warning: This script downloads the Bridge dataset from the Open X-Embodiment bucket, which is currently outdated !!!"
echo "!!! Instead download the bridge_dataset from here: https://rail.eecs.berkeley.edu/datasets/bridge_release/data/tfds/ !!!"

# format: [dataset_name, dataset_version, transforms]
DATASET_TRANSFORMS=(
    # "fractal20220817_data 0.1.0 resize_and_jpeg_encode 0.001"
    "bridge_orig 1.0.0 resize_and_jpeg_encode 0.1"
    # "kuka 0.1.0 resize_and_jpeg_encode,filter_success 0.001"
    # "taco_play 0.1.0 resize_and_jpeg_encode 0.1"
    # "jaco_play 0.1.0 resize_and_jpeg_encode 0.1"
    # "berkeley_cable_routing 0.1.0 resize_and_jpeg_encode 0.1"
    # "roboturk 0.1.0 resize_and_jpeg_encode 0.1"
    # "viola 0.1.0 resize_and_jpeg_encode 0.1"
    # "berkeley_autolab_ur5 0.1.0 resize_and_jpeg_encode,flip_wrist_image_channels 0.01"
    # "toto 0.1.0 resize_and_jpeg_encode 0.1"
    # "language_table 0.1.0 resize_and_jpeg_encode 0.1"
    # "stanford_hydra_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode,flip_wrist_image_channels,flip_image_channels 0.1"
    # "austin_buds_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.1"
    # "nyu_franka_play_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.1"
    # "furniture_bench_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.1"
    # "ucsd_kitchen_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.1"
    # "austin_sailor_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.1"
    # "austin_sirius_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.1"
    # "bc_z 0.1.0 resize_and_jpeg_encode 0.1"
    # "dlr_edan_shared_control_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.1"
    # "iamlab_cmu_pickup_insert_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.1"
    # "utaustin_mutex 0.1.0 resize_and_jpeg_encode,flip_wrist_image_channels,flip_image_channels 0.1"
    # "berkeley_fanuc_manipulation 0.1.0 resize_and_jpeg_encode,flip_wrist_image_channels,flip_image_channels 0.1"
    # "cmu_stretch 0.1.0 resize_and_jpeg_encode 0.1"
    # "dobbe 0.0.1 resize_and_jpeg_encode 0.1"
    # "fmb 0.0.1 resize_and_jpeg_encode 0.1"
    # "droid 1.0.0 resize_and_jpeg_encode 0.1"
)

  

for tuple in "${DATASET_TRANSFORMS[@]}"; do
  # Extract strings from the tuple
  strings=($tuple)
  DATASET=${strings[0]}
  VERSION=${strings[1]}
  TRANSFORM=${strings[2]}
  RATIO=${strings[3]}
  DOWNLOADPATH=gs://gresearch/robotics/${DATASET}/${VERSION}/


  python reconstruct_dataset.py --path=/data/jcy/data/openx_part/origin/bridge_orig/1.0.0
  python3 modify_rlds_dataset.py --dataset=$DATASET --data_dir=$DOWNLOAD_DIR --version=$VERSION --target_dir=$CONVERSION_DIR --mods=$TRANSFORM --n_workers=$N_WORKERS --max_episodes_in_memory=$MAX_EPISODES_IN_MEMORY

done
