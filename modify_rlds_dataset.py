"""Modifies TFDS dataset with a map function, updates the feature definition and stores new dataset."""
from functools import partial
import os,re
from absl import app, flags
import tensorflow as tf
import tensorflow_datasets as tfds

from rlds_dataset_mod.mod_functions import TFDS_MOD_FUNCTIONS
from rlds_dataset_mod.multithreaded_adhoc_tfds_builder import (
    MultiThreadedAdhocDatasetBuilder,
)

FLAGS = flags.FLAGS

flags.DEFINE_string("dataset", None, "Dataset name.")
flags.DEFINE_string("data_dir", None, "Directory where source data is stored.")
flags.DEFINE_string("version", None, "Dataset version.")
flags.DEFINE_string("target_dir", None, "Directory where modified data is stored.")
flags.DEFINE_list("mods", None, "List of modification functions, applied in order.")
flags.DEFINE_integer("n_workers", 10, "Number of parallel workers for data conversion.")
flags.DEFINE_integer(
    "max_episodes_in_memory",
    100,
    "Number of episodes converted & stored in memory before writing to disk.",
)


def mod_features(features):
    """Modifies feature dict."""
    for mod in FLAGS.mods:
        features = TFDS_MOD_FUNCTIONS[mod].mod_features(features)
    return features


def mod_dataset_generator(builder, split, mods):
    """Modifies dataset features."""
    ds = builder.as_dataset(split=split)
    for mod in mods:
        ds = TFDS_MOD_FUNCTIONS[mod].mod_dataset(ds)
    for episode in tfds.core.dataset_utils.as_numpy(ds):
        yield episode


def main(_):
    builder = tfds.builder(FLAGS.dataset, data_dir=FLAGS.data_dir)

    features = mod_features(builder.info.features)
    print("############# Target features: ###############")
    print(features)
    print("##############################################")
    assert FLAGS.data_dir != FLAGS.target_dir   # prevent overwriting original dataset

    # 获得数据集的部分列表
    dataset_path = os.path.join(FLAGS.data_dir, FLAGS.dataset, FLAGS.version)
    pattern = re.compile(r'.*-([0-9]+)-of-[0-9]+')
    
    # 保存处理后的编号的列表
    train_file_ids = []
    
    # 遍历目录中的文件
    for filename in os.listdir(dataset_path):
        match = pattern.match(filename)
        if match:
            # 提取编号并去除前导零
            number = int(match.group(1))
            train_file_ids.append(number)
    print("############# Train file ids: ###############")
    print(train_file_ids)

    mod_dataset_builder = MultiThreadedAdhocDatasetBuilder(
        name=FLAGS.dataset,
        version=builder.version,
        features=features,
        split_datasets={split: builder.info.splits[split] for split in builder.info.splits},
        config=builder.builder_config,
        data_dir=FLAGS.target_dir,
        description=builder.info.description,
        generator_fcn=partial(mod_dataset_generator, builder=builder, mods=FLAGS.mods),
        n_workers=FLAGS.n_workers,
        max_episodes_in_memory=FLAGS.max_episodes_in_memory,
        train_file_ids=train_file_ids,
        new_dataset_size = builder.info.dataset_size,        
    )
    mod_dataset_builder.download_and_prepare()


if __name__ == "__main__":
    app.run(main)
