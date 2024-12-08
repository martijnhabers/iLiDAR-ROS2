# =========================
# iLiDAR
# utils.py
# Created by Bo Liang on 2024/12/8.
# =========================
import os
import shutil

def classification_by_event(input_folder, output_folder):

    os.makedirs(output_folder, exist_ok=True)
    files = os.listdir(input_folder)
    for file in files:
        if file.endswith(('.jpg', '.bin')):
            event_timestamp = file.split('_')[0] + '_' + file.split('_')[1]
            event_dir = os.path.join(output_folder, event_timestamp)
            os.makedirs(event_dir, exist_ok=True)
            file_path = os.path.join(input_folder, file)
            new_file_path = os.path.join(event_dir, file)
            shutil.move(file_path, new_file_path)

        if file.endswith('.csv'):
            event_timestamp, extension = os.path.splitext(file)
            event_dir = os.path.join(output_folder, event_timestamp)
            os.makedirs(event_dir, exist_ok=True)
            file_path = os.path.join(input_folder, file)
            new_file_path = os.path.join(event_dir, file)
            shutil.move(file_path, new_file_path)

    print(f"Processed and moved {len(files)} files into event folders.")

def delete_files_in_folder(folder_path):
    for filename in os.listdir(folder_path):
        file_path = os.path.join(folder_path, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)  # delete sub-folders
        except Exception as e:
            print(f'Failed to delete {file_path}. Reason: {e}')


if __name__ == '__main__':  
    # Specify the folder containing your files
    input_folder = './uploads'
    output_folder = './uploads'
    classification_by_event(input_folder, output_folder)
