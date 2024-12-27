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
    "fractal20220817_data 0.1.0 resize_and_jpeg_encode 0.15"
    "bridge 0.1.0 resize_and_jpeg_encode 0.2"
    "kuka 0.1.0 resize_and_jpeg_encode,filter_success 0.07"
    "taco_play 0.1.0 resize_and_jpeg_encode 0.2"
    "jaco_play 0.1.0 resize_and_jpeg_encode 0.3"
    "berkeley_cable_routing 0.1.0 resize_and_jpeg_encode 0.3"
    "roboturk 0.1.0 resize_and_jpeg_encode 0.2"
    "viola 0.1.0 resize_and_jpeg_encode 0.5"
    "berkeley_autolab_ur5 0.1.0 resize_and_jpeg_encode,flip_wrist_image_channels 0.3"
    "toto 0.1.0 resize_and_jpeg_encode 0.3"
    "language_table 0.1.0 resize_and_jpeg_encode 0.1"
    "stanford_hydra_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode,flip_wrist_image_channels,flip_image_channels 0.4"
    "austin_buds_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.5"
    "nyu_franka_play_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.3"
    "furniture_bench_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.15"
    "ucsd_kitchen_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.5"
    "austin_sailor_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.5"
    "austin_sirius_dataset_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.4"
    "bc_z 0.1.0 resize_and_jpeg_encode 0.2"
    "dlr_edan_shared_control_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.5"
    "iamlab_cmu_pickup_insert_converted_externally_to_rlds 0.1.0 resize_and_jpeg_encode 0.4"
    "utaustin_mutex 0.1.0 resize_and_jpeg_encode,flip_wrist_image_channels,flip_image_channels 0.2"
    "berkeley_fanuc_manipulation 0.1.0 resize_and_jpeg_encode,flip_wrist_image_channels,flip_image_channels 0.4"
    "cmu_stretch 0.1.0 resize_and_jpeg_encode 0.5"
    "dobbe 0.0.1 resize_and_jpeg_encode 0.1"
    "fmb 0.0.1 resize_and_jpeg_encode 0.2"
    # "droid 1.0.0 resize_and_jpeg_encode 0.03" 
)

  # 懒得删就打开这条，把原有的旧文件先清理一下
  # echo "▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ WARNING ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲"
  # echo " WARNING: This script will delete all files in the download and conversion directories."
  # rm -rf ${DOWNLOAD_DIR}/*
  # rm -rf ${CONVERSION_DIR}/*
  # echo "▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ WARNING ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲"

for tuple in "${DATASET_TRANSFORMS[@]}"; do
  # Extract strings from the tuple
  strings=($tuple)
  DATASET=${strings[0]}
  VERSION=${strings[1]}
  TRANSFORM=${strings[2]}
  RATIO=${strings[3]}
  DOWNLOADPATH=gs://gresearch/robotics/${DATASET}/${VERSION}/
  mkdir -p ${DOWNLOAD_DIR}/${DATASET}/
  mkdir -p ${DOWNLOAD_DIR}/${DATASET}/${VERSION}
  # gsutil -m cp -r gs://gresearch/robotics/${DOWNLOADPATH} ${DOWNLOAD_DIR}/${DATASET}

  # 获取文件列表
  file_list=$(gsutil ls "$DOWNLOADPATH")
  echo Now downloading ${DATASET}/${VERSION}:

  # 初始化数组
  train_files=()
  json_files=()

  # 遍历文件列表
  for file in $file_list; do
      # 提取文件名
      filename=$(basename "$file")
      
      if [[ $filename == *.json ]]; then
          json_files+=("$file")
      fi

      if [[ $filename == *train* ]]; then
      # if [[ $filename == *train* && $filename == *00256 ]]; then # dobbe 用
          train_files+=("$file")
      fi
  done

  echo "Number of JSON files: ${#json_files[@]}"
  echo "Number of train files: ${#train_files[@]}"

  total_train_files=${#train_files[@]}
  download_count=$(echo "$total_train_files * $RATIO" | bc | awk '{print int($1+0.5)}')

  shuffled_train_files=($(shuf -e "${train_files[@]}"))
  selected_train_files=("${shuffled_train_files[@]:0:$download_count}")
  echo "Number of selected train files: ${#selected_train_files[@]}"


  # 下载所有的.json文件
  for file in "${json_files[@]}"; do
      echo "$file"
      gsutil cp -r "$file" ${DOWNLOAD_DIR}/${DATASET}/${VERSION}
  done


  total_files=${#selected_train_files[@]}
  current_file=0

  for file in "${selected_train_files[@]}"; do
      current_file=$((current_file + 1))
      echo "Processing file $current_file of $total_files: $file"
      
      # 显示简单的进度条
      progress=$((current_file * 100 / total_files))
      echo -ne "Progress: ["
      for ((i=0; i<progress; i+=2)); do echo -ne "#"; done
      for ((i=progress; i<100; i+=2)); do echo -ne " "; done
      echo -ne "] $progress%\r"

      # 执行文件拷贝
      gsutil cp -r "$file" "${DOWNLOAD_DIR}/${DATASET}/${VERSION}"
  done

  echo -e "\nAll files processed."

  python reconstruct_dataset.py --path=${DOWNLOAD_DIR}/${DATASET}/${VERSION}
  python3 modify_rlds_dataset.py --dataset=$DATASET --data_dir=$DOWNLOAD_DIR --version=$VERSION --target_dir=$CONVERSION_DIR --mods=$TRANSFORM --n_workers=$N_WORKERS --max_episodes_in_memory=$MAX_EPISODES_IN_MEMORY

done
