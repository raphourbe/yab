package yab

import "core:os"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:time"
import win32 "core:sys/windows"

BLOG_SOURCE_FILES :: "C:\\Users\\super\\Documents\\OdinProjects\\yet_another_blog\\blog_source_files"
BLOG_GENERATED_FILES :: "C:\\Users\\super\\Documents\\OdinProjects\\yet_another_blog\\blog_generated_files"
PLATEFORM_PATH_SEPARATOR :: "\\"  // On windows \\, on Linux / I guess.
MAIN_URL :: "https://rphl.dev"
YOUR_NAME :: "Raphaël Becanne"
YOUR_COMPANY :: "PrimeView"
MAIL_ACCOUNT :: "rbecanne@primeview.fr"
GITHUB_ACCOUNT :: "raphourbe"
X_ACCOUNT :: "rbecanne"
LINKEDIN_ACCOUNT :: "raphaelbecanne"
BLOG_BASELINE :: "Adventures of a self-proclaimed CTO"
BLOG_DESCRIPTION :: "A blog describing the problems I had to take care of as a CTO in a SME, and more."

Post :: struct {
	file_name : string,
	title     : string,
	date      : string,
	lastmod   : string,
	summary   : string,
	tags      : []string,
	content   : [dynamic]string,
	toc       : Table_Of_Content
}

Tag :: struct {
	name: string,
	occurences: uint
}

Parsing_Error :: enum {
	None,
	Cant_Read_File,
	Code_Bloc_Unfinished,
	Html_Bloc_Unfinished,
	Is_Draft,
	Open_Error,
	Write_Error,
	Wrong_Format
}

Table_Of_Content :: struct {
	exists    : bool,
	line_start: uint,
	max_level : uint, 
	titles    : [dynamic]H_Title,
}

H_Title :: struct {
	level: uint,
	value: string,
	href : string
}

// Build your beautiful blog
main :: proc() {
	// Verifies that you have a folder of source files to start.
	if !os.is_dir(path=BLOG_SOURCE_FILES) {
		panic("There is no folder of source files to work with.")
	}

	// Delete the older blog generated files if it exists.
	if os.is_dir(path=BLOG_GENERATED_FILES) {
		remove_error : os.Error = delete_directory_recursively(path=BLOG_GENERATED_FILES)
		if remove_error != os.ERROR_NONE {
			fmt.println("The following error occured while trying to delete the folder: ", BLOG_GENERATED_FILES) 
			fmt.println(remove_error)
			return
		}
	}

	// Create new folder for generated files
	create_folder_error : os.Error = os.make_directory(name=BLOG_GENERATED_FILES)
	if create_folder_error != os.ERROR_NONE {
		fmt.println("The following error occured while trying to create the folder: ", BLOG_GENERATED_FILES) 
		fmt.println(create_folder_error)
		return
	}

	// Open the posts folder
	posts_folder_path := fmt.tprint(BLOG_SOURCE_FILES, "posts", sep=PLATEFORM_PATH_SEPARATOR)
	posts_path_handle, posts_path_handle_error := os.open(name=posts_folder_path)
	if posts_path_handle_error != nil {
		fmt.println("The following error occured while trying to open the folder: ", posts_folder_path) 
		fmt.println(posts_path_handle_error)
		return
	}
	defer os.close(posts_path_handle)

	// read all files in the folder
	file_info, file_info_error := os.read_dir(f=posts_path_handle, n=-1, allocator=context.allocator)

	if len(file_info) == 0 {
		fmt.println("You did not write any blog post yet in the folder: ", posts_folder_path) 
		fmt.println(file_info_error)
		return
	}

	if file_info_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading info of files in the folder: ", posts_folder_path) 
		fmt.println(file_info_error)
		return
	}

	// Generate each post's xxxx.html file -------------------------
	number_of_posts : uint = 0
	blog_dir : string = fmt.tprint(BLOG_GENERATED_FILES, "blog", sep=PLATEFORM_PATH_SEPARATOR)
	posts: [dynamic]Post
	alltags: [dynamic]Tag

    for fi in file_info {
    	fmt.println(fi.name)
        if fi.type == .Directory {
        	continue
        }
        post, post_error := parse_md_file(file=fi.fullpath)
        #partial switch post_error {
        case .Cant_Read_File:
        	fmt.println(fi.name, "can't be read. Not taken into account.")
        	continue
        case .Is_Draft:
        	fmt.println(fi.name, "is a draft. Not taken into account.")
        	continue
        case .Wrong_Format:
        	fmt.println(fi.name, "does not have the proper format. Please use the following format for each blog post's beginning.")
        	// TODO: add the format
        	continue
        case .Code_Bloc_Unfinished:
        	fmt.println("Problem with the end of a code bloc. Check that the final ```")
        	continue
        case .Html_Bloc_Unfinished:
        	fmt.println("Problem with an Html bloc.")
        	continue
    	}
    	// Generate the Table of Content in the post if there is one.
    	if post.toc.exists {
    		parse_toc(p=&post)
    	}

        number_of_posts += 1
    	post.file_name = fi.name
    	if !os.is_dir(path=blog_dir) {
    		create_folder_error = os.make_directory(name=blog_dir)
    		if create_folder_error != os.ERROR_NONE {
				fmt.println("The following error occured while trying to create the folder: ", blog_dir) 
				fmt.println(create_folder_error)
				return
			}
    	}
    	// Copy the blog template
    	copy_error : Parsing_Error = create_blog_post_into_html_template(p=post)
    	if copy_error != .None {    		
			fmt.println("The following error occured while trying to copy into html the post : ", post.title) 
			fmt.println(copy_error)
			return
    	}
    	// Update tags list
    	update_tags_list(alltags=&alltags, post_tags=post.tags)

    	// Content and titles not needed anymore
    	clean_post(p=&post)

    	append(&posts, post)
    }

    sort_posts_by_date_desc_order(&posts)

    // index.html -------------------------------------------
    post_for_index: uint = 5
    if number_of_posts < 5 {
    	post_for_index = number_of_posts
    }
    index_error : Parsing_Error = create_index_with_html_template(posts=posts[:post_for_index])
	if index_error != .None {    		
		fmt.println("The following error occured while trying to create the index page") 
		fmt.println(index_error)
		return
	}

	// blog/index.html --------------------------------------
	blog_error : Parsing_Error = create_posts_listing_with_html_template(posts=posts, tags=alltags)
	if blog_error != .None {    		
		fmt.println("The following error occured while trying to create the blog/index page") 
		fmt.println(blog_error)
		return
	}
	// tags/index.html --------------------------------------
	tags_dir : string = fmt.tprint(BLOG_GENERATED_FILES, "tags", sep=PLATEFORM_PATH_SEPARATOR)
	if !os.is_dir(path=tags_dir) {
		create_folder_error = os.make_directory(name=tags_dir)
		if create_folder_error != os.ERROR_NONE {
			fmt.println("The following error occured while trying to create the folder: ", tags_dir) 
			fmt.println(create_folder_error)
			return
		}
	}
	tags_error : Parsing_Error = create_tags_index_with_html_template(tags=alltags)
	if tags_error != .None {    		
		fmt.println("The following error occured while trying to create the tags/index page") 
		fmt.println(tags_error)
		return
	}

	// tags/xxxxx.html --------------------------------------
	for t in alltags {
		tag_error : Parsing_Error = create_posts_listing_with_html_template(posts=posts, tags=alltags, tag=t.name)
		if tag_error != .None {    		
			fmt.println("The following error occured while trying to create the tag/", t.name) 
			fmt.println(tag_error)
			return
		}
	}

	// about page -------------------------------------------
	about_error : Parsing_Error = create_about_with_html_template()
	if about_error != .None {    		
		fmt.println("The following error occured while trying to create the about page") 
		fmt.println(about_error)
		return
	}

    // Copy static files ------------------------------------
    source_static_dir := fmt.tprint(BLOG_SOURCE_FILES, "static", sep=PLATEFORM_PATH_SEPARATOR)
    dest_static_dir := fmt.tprint(BLOG_GENERATED_FILES, "static", sep=PLATEFORM_PATH_SEPARATOR)
    copy_err := copy_directory_recursively(source_directory=source_static_dir, destination_directory=dest_static_dir)
    if copy_err != nil {
    	fmt.println("Error copying directory:", source_static_dir)
    	fmt.println(copy_err)
    	return
    }
}

// Add new tags to the tags list or increment the number of occurence of a Tag.
update_tags_list :: proc(alltags: ^[dynamic]Tag, post_tags: []string) {
	for pt in post_tags {
		found: bool
		for &tt in alltags {
			if tt.name == pt {
				tt.occurences += 1
				found = true
				break
			}
		}
		if !found {
			append(alltags, Tag{name=pt, occurences=1})
		}
	}
}

// Order the list into a chronological one, but the more recent posts first.
sort_posts_by_date_desc_order :: proc(posts: ^[dynamic]Post) {
    compare_posts :: proc(a, b: Post) -> bool {
        date_a, ok_a := yab_utils_extract_date(a.date)
        if !ok_a {
        	fmt.println("Error with the date of post:" , a.title)
        	return false
        }
        date_b, ok_b := yab_utils_extract_date(b.date)
        if !ok_b {
        	fmt.println("Error with the date of post:" , b.title)
        	return false
        }
        is_a_bigger_than_b := yab_utils_compare_dates(date_a, date_b)
        // Compare dates in descending order (latest first)
        if is_a_bigger_than_b {
            return true
        }
        return false
    }

    slice.sort_by(posts[:], compare_posts)
}

clean_post :: proc(p: ^Post) {
	delete(p.content)
	delete(p.toc.titles)
}