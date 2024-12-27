[Darren-greenhand/LLaVA_OpenVLA: Converted the training data of OpenVLA into general form of multimodal training instructions and then used with LLaVA-OneVision](https://github.com/Darren-greenhand/LLaVA_OpenVLA/tree/main)

👆LLaVA_OpenVLA项目的part1

需要翻墙使用，droid dataset需要单独处理，原文里说规模小好像没用，就没处理了（注释掉了

`prepare_bridge.sh` 是单独处理bridge的，这个数据集好像更新了，在别的地方下载，所以不需要下载步骤，只需要后处理

* 支持设定比例后再进行下载
* 去掉了本来的resize操作，后面llava直接用原本的size训练
* 修改了tfds dataset_info，把部分数据集重设为新的完整数据

自己搞了一套mix，也可以修改，直接改prepare_open_x.sh的DATASET_TRANSFORMS，不要的注释起来，后面的小数是比例

ps：详细实现可见笔记：https://darren-dong.notion.site/OpenVLA-LLaVA-11a471fbaea480839ee6ca55f122a187?pvs=4
LLaVA-OV库更改 -> rlds download



| Registered Dataset Name                               | # Episodes | ratio | File Size (GB) |
| ----------------------------------------------------- | ---------- | ----- | -------------- |
| fractal20220817_data                                  | 73,499     | 0.15  | 111.06         |
| kuka                                                  | 580,392    | 0.07  | 778.02         |
| bridge                                                | 25,460     | 0.2   | 387.49         |
| taco_play                                             | 3,242      | 0.2   | 47.77          |
| jaco_play                                             | 976        | 0.3   | 9.24           |
| berkeley_cable_routing                                | 1,482      | 0.3   | 4.67           |
| roboturk                                              | 2,144      | 0.2   | 45.39          |
| viola                                                 | 135        | 0.5   | 10.4           |
| berkeley_autolab_ur5                                  | 896        | 0.3   | 76.39          |
| toto                                                  | 901        | 0.3   | 127.66         |
| language_table                                        | 442,226    | 0.1   | 399.22         |
| stanford_hydra_dataset_converted_externally_to_rlds   | 550        | 0.4   | 72.48          |
| austin_buds_dataset_converted_externally_to_rlds      | 50         | 0.5   | 1.49           |
| nyu_franka_play_dataset_converted_externally_to_rlds  | 456        | 0.3   | 5.18           |
| furniture_bench_dataset_converted_externally_to_rlds  | 5100       | 0.15  | 110            |
| ucsd_kitchen_dataset_converted_externally_to_rlds     | 150        | 0.5   | 1.33           |
| austin_sailor_dataset_converted_externally_to_rlds    | 250        | 0.5   | 18.85          |
| austin_sirius_dataset_converted_externally_to_rlds    | 600        | 0.4   | 6.55           |
| bc_z                                                  | 39,350     | 0.2   | 80.54          |
| dlr_edan_shared_control_converted_externally_to_rlds  | 100        | 0.5   | 3.09           |
| iamlab_cmu_pickup_insert_converted_externally_to_rlds | 520        | 0.4   | 50.29          |
| utaustin_mutex                                        | 1,500      | 0.2   | 20.79          |
| berkeley_fanuc_manipulation                           | 415        | 0.4   | 8.85           |
| cmu_stretch                                           | 135        | 0.5   | 0.71           |
| dobbe                                                 | 5208       | 0.1   | 21.1           |
| <s>fmb</s>                                            | 1804       | 0.2   | 356.5          |

现在：113,178条轨迹  450G




# RLDS Dataset Modification

This repo contains scripts for modifying existing RLDS datasets. 
By running [`modify_rlds_dataset.py`](modify_rlds_dataset.py), you will load an existing RLDS dataset, apply the specified
modifications to each sample, reshard the resulting dataset and store it in a new directory. Apart from a number of simple
modification functions, this repo implements a parallelized `AdhocTFDSBuilder` that can perform the data modifications
in parallel for increased conversion speed.

## Installation

First create a conda environment using the provided environment.yml file (use `environment_ubuntu.yml` or `environment_macos.yml` depending on the operating system you're using):
```
conda env create -f environment_ubuntu.yml
```

Then activate the environment using:
```
conda activate rlds_env
```

If you want to manually create an environment, the key packages to install are `tensorflow` and `tensorflow_datasets`.

To download datasets from the [Open X-Embodiment Dataset](https://robotics-transformer-x.github.io/) Google cloud bucket, 
please install `gsutil` using the [installation instructions](https://cloud.google.com/storage/docs/gsutil_install).


## Modifying RLDS Datasets

The command below resizes all RGB and depth images to a max. size of 336 and encodes RGB images as jpeg. 
This can e.g. be useful for reducing the storage size of datasets in the [Open X-Embodiment Dataset](https://robotics-transformer-x.github.io/).
```
python3 modify_rlds_dataset.py --dataset=<name_of_your_tfds_dataset> --mods=resize_and_jpeg_encode --target_dir=<path_where_mod_data_is_written>
```

This creates a new dataset with smaller, jpeg encoded images in the `target_dir`. 

You can switch out the `resize_and_jpeg_encode` mod for other functions in [mod_functions.py](rlds_dataset_mod/mod_functions.py).


## Command Arguments

The [`modify_rlds_dataset.py`](modify_rlds_dataset.py) script supports the following command line arguments:
```
modify_rlds_dataset.py:
  --data_dir: Directory where source data is stored.
  --dataset: Dataset name.
  --max_episodes_in_memory: Number of episodes converted & stored in memory before writing to disk.
    (default: '100')
    (an integer)
  --mods: List of modification functions, applied in order.
    (a comma separated list)
  --n_workers: Number of parallel workers for data conversion.
    (default: '10')
    (an integer)
  --target_dir: Directory where modified data is stored.
```
You can increase the `n_workers` and `max_episodes_in_memory` parameters based on the resources of your machine. 
The larger the respective value, the faster the dataset conversion. 

A list of all supported dataset modifications ("mods") can be found in [mod_functions.py](rlds_dataset_mod/mod_functions.py).


## Adding New Mods

You can add your own custom modification functions in [mod_functions.py](rlds_dataset_mod/mod_functions.py) by implementing 
the `TfdsModFunction` interface. Your mod function needs to provide one function that modifies the dataset feature spec
and one map function that modifies an input `tf.data.Dataset`. You can use the existing mod functions as examples.
Make sure to register your new mod in the `TFDS_MOD_FUNCTIONS` object.


## Download Open X-Embodiment Dataset
To download the Open X-Embodiment dataset and convert it for training, run `bash prepare_open_x.sh`. You can
specify the download directory at the top of the script.


## FAQ / Troubleshooting

- **No new tempfile could be created**: The script stores large datasets in intermediate temporary files in the 
`\tmp` directory. Depending on the dataset size it can store up to 1000 such temp files. The default number of 
files openable in parallel in Ubuntu is 1024, so this limit can lead to the error above. You can increase the limit by
running `ulimit -n 200000`.



