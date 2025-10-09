package yab

import "core:os"
import "core:fmt"
import win32 "core:sys/windows"

delete_directory_recursively :: proc(path: string) -> os.Error {
	// Delete the older blog generated files if it exists.
	if os.is_dir(path=path) {
		path_handle, path_handle_error := os.open(path=path)
		if path_handle_error != nil {
			fmt.println("The following error occured while trying to open the folder: ", path) 
			fmt.println(path_handle_error)
			return path_handle_error
		}

		// read all files in the folder
		file_info, file_info_error := os.read_dir(fd=path_handle, n=-1)
		if file_info_error != nil {
			return file_info_error
		}
		
		for fi in file_info {
			if fi.is_dir {
				delete_directory_recursively(path=fi.fullpath) or_return
				continue
			}
			remove_error : os.Error = os.remove(name=fi.fullpath)
			if remove_error != os.ERROR_NONE {
				fmt.println("The following error occured while trying to delete the file: ", fi.fullpath)
				return remove_error
			}
		}
		os.close(fd=path_handle)
		os.remove_directory(path=path) or_return
	}
	return os.ERROR_NONE
}

// Careful, this function deletes the destination_directory if it already exists
// before copying the source_directory.
copy_directory_recursively :: proc(source_directory: string, destination_directory: string) -> os.Error {
	delete_directory_recursively(path=destination_directory) or_return
	os.make_directory(path=destination_directory) or_return

	// Copy static folder into destination folder
    source_path_handle := os.open(path=source_directory) or_return
	defer os.close(source_path_handle)

    // read all files in the folder
	file_info : []os.File_Info = os.read_dir(fd=source_path_handle, n=-1) or_return

	for fi in file_info {
		if fi.is_dir {
			rec_d_dir : string = fmt.tprint(destination_directory, fi.name, sep=PLATEFORM_PATH_SEPARATOR)
			copy_directory_recursively(source_directory=fi.fullpath, destination_directory=rec_d_dir) or_return
			continue
		}
		file_name_cstring : [^]u16 = win32.utf8_to_wstring(s=fi.fullpath)
		file_destination : string = fmt.tprint(destination_directory, fi.name, sep=PLATEFORM_PATH_SEPARATOR)
		file_destination_cstring : [^]u16 = win32.utf8_to_wstring(s=file_destination)
		ok : win32.BOOL = win32.CopyFileW(lpExistingFileName=file_name_cstring, lpNewFileName=file_destination_cstring, bFailIfExists=false)
		if !ok {
			return os.ERROR_ACCESS_DENIED
		}
	}
	return os.ERROR_NONE
}

