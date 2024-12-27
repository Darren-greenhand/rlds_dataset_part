#!/usr/bin/env python3
import os
import re
import argparse
import json

def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Reconstruct a TensorFlow dataset from partial data.')
    parser.add_argument('--path', required=True, help='Path to the dataset directory')
    args = parser.parse_args()
    path = args.path

    # Compile the regex pattern to match shard filenames
    pattern = re.compile(r'(.*)-(\d+)-of-\d+')

    # Collect shard files and their indices
    file_list = []
    for filename in os.listdir(path):
        match = pattern.match(filename)
        if match:
            base_name = match.group(1)
            index = int(match.group(2))
            file_list.append((index, filename))

    if not file_list:
        print('No shard files found matching the pattern in the specified directory.')
        return

    # Sort the file list by indices
    file_list.sort()
    indices = [index for index, _ in file_list]

    # Calculate total numBytes of the shard files
    total_num_bytes = 0
    for index, filename in file_list:
        filepath = os.path.join(path, filename)
        num_bytes = os.path.getsize(filepath)
        total_num_bytes += num_bytes

    # Read the dataset_info.json file
    dataset_info_path = os.path.join(path, 'dataset_info.json')


    with open(dataset_info_path, 'r', encoding='utf-8') as f:
        dataset_info = json.load(f)
        splits = dataset_info.get('splits', [])
        for split in splits:
            if split.get('name') != 'train':
                splits.remove(split)
        dataset_info['splits'] = splits

    # Update the 'train' split in dataset_info.json
    splits = dataset_info.get('splits', [])
    for split in splits:
        if split.get('name') == 'train':
            train_split = split
            break
    else:
        print('No split named "train" found in dataset_info.json.')
        return
    
    

    # Update 'numBytes' and 'shardLengths' in the 'train' split
    train_split['numBytes'] = str(total_num_bytes)
    original_shard_lengths = train_split.get('shardLengths', [])
    try:
        new_shard_lengths = [original_shard_lengths[i] for i in indices]
    except IndexError:
        print('Error: Shard indices exceed the length of original shardLengths.')
        return
    train_split['shardLengths'] = new_shard_lengths

    # Write the updated dataset_info.json back to the file
    with open(dataset_info_path, 'w', encoding='utf-8') as f:
        json.dump(dataset_info, f, ensure_ascii=False, indent=2)

    # Rename the shard files in sequential order
    num_shards = len(file_list)
    for new_index, (old_index, filename) in enumerate(file_list):
        old_filepath = os.path.join(path, filename)
        # Extract the original base name and suffix from the filename
        match = pattern.match(filename)
        if not match:
            print(f'Error: Filename {filename} does not match the expected pattern.')
            return
        base_name = match.group(1)
        # suffix = filename[match.end(2):]  # The remaining part after the index
        # Construct the new filename
        new_filename = f"{base_name}-{new_index:05d}-of-{num_shards:05d}"
        new_filepath = os.path.join(path, new_filename)
        # Rename the file
        os.rename(old_filepath, new_filepath)

    print('Dataset reconstruction completed successfully.')

if __name__ == '__main__':
    main()
