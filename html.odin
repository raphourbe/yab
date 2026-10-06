package yab

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

// Create the post's html file using a html template.
// The resulting file is located into a /blog/subfolder and is named index.html
// to obtain a nice URL in the browser without having "file.html" at the end.
create_blog_post_into_html_template :: proc(p: Post) -> Parsing_Error {
	file := fmt.tprint(BLOG_SOURCE_FILES, "template_post.html", sep=PLATEFORM_PATH_SEPARATOR)
	template, template_error := os.read_entire_file_from_path(
		name=file, allocator=context.temp_allocator
	)
	if template_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(template_error)
		return .Cant_Read_File
	}

	t := string(template)
	lines : []string = strings.split_lines(s=t, allocator=context.temp_allocator)

	// Each file will be in a folder of the same name, and the file will be called "index.html"
	// so the URL in the web is pretty like "myblog.com/blog/post-name"
	new_folder_location := fmt.tprint(
		BLOG_GENERATED_FILES, "blog", strings.trim_suffix(s=p.file_name, suffix=".md"), 
		sep=PLATEFORM_PATH_SEPARATOR
	)
	if !os.is_dir(path=new_folder_location) {
    	create_folder_error := os.make_directory(name=new_folder_location)
		if create_folder_error != os.ERROR_NONE {
			fmt.println("The following error occured while trying to create the folder: ", new_folder_location) 
			fmt.println(create_folder_error)
			return .Write_Error
		}
	}
	new_file_name := fmt.tprint(new_folder_location, "index.html", sep=PLATEFORM_PATH_SEPARATOR)
	new_file_handle, open_error := os.open(name=new_file_name, flags={.Create})
	if open_error != nil {
		fmt.println(open_error)
		return .Open_Error
	}
	beautiful_date, date_error := parse_complete_date_from_string(s=p.date)
	if date_error != nil {
		fmt.println("Problem parsing the date:", p.date)
	}

	for l in lines {
		modified_line := parse_and_replace_main_meta_data(l=l)
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%title%}", new=p.title) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%date%}", new=p.date) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%lastmod%}", new=p.lastmod) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%summary%}", new=p.summary) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%mainurl%}", new=MAIN_URL) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%formatedDate%}", new=beautiful_date)
		
		if l != modified_line { 
			i, write_error := os.write_string(f=new_file_handle, s=modified_line)
			if write_error != nil {
				fmt.println("Error while writing line: ", modified_line)
				return .Write_Error
			}
			continue
		}

		if strings.index(s=l, substr="{%content%}") >= 0 {
			for c in p.content {
				i, write_error := os.write_string(f=new_file_handle, s=c)
				if write_error != nil {
					fmt.println("Error while writing line: ", l)
					return .Write_Error
				}
			}
			continue
		}

		if strings.index(s=l, substr="{%tags%}") >= 0 {
			sane_tag: string
			for c in p.tags {
				sane_tag = strings.to_snake_case(html_sanitize_link(s=c))
				tag_link := fmt.tprint(
					"<a class=\"mr-3 text-sm font-medium uppercase text-teal-400 hover:text-teal-300 dark:hover:text-teal-300\" href=\"/tags/",
					sane_tag,
					"\">",
					c ,
					"</a>",
					 sep=""
				)
				i, write_error := os.write_string(f=new_file_handle, s=tag_link)
				if write_error != nil {
					fmt.println("Error while writing line: ", l)
					return .Write_Error
				}
			}
			continue
		}

		// Nothing has been written yet: copy the old line as such.
		i, write_error := os.write_string(f=new_file_handle, s=l)
		if write_error != nil {
			fmt.println("Error while writing line: ", l)
			return .Write_Error
		}
	}
	closing_error := os.close(f=new_file_handle)
	if closing_error != nil {
		fmt.println("Error while closing: ", new_file_name)
		return .Write_Error
	}
	return .None
}

// Create the div block referencing every blog post in the main index.html page.
// Copy the template_index.html page and parse it to add blog's info and the 
// latest blog posts.
// The page is located at https://yoururl.com
create_index_with_html_template :: proc(posts: []Post) -> Parsing_Error {
	file := fmt.tprint(BLOG_SOURCE_FILES, "template_index.html", sep=PLATEFORM_PATH_SEPARATOR)
	template, template_error := os.read_entire_file_from_path(
		name=file, allocator=context.temp_allocator
	)
	if template_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(template_error)
		return .Cant_Read_File
	}

	t := string(template)
	lines : []string = strings.split_lines(s=t, allocator=context.temp_allocator)

	new_file_location := fmt.tprint(BLOG_GENERATED_FILES, "index.html", sep=PLATEFORM_PATH_SEPARATOR)
	new_file_handle, open_error := os.open(name=new_file_location, flags={.Create})
	if open_error != nil {
		fmt.println(open_error)
		return .Open_Error
	}

	for l in lines {
		modified_line := parse_and_replace_main_meta_data(l=l)
		if l != modified_line { 
			i, write_error := os.write_string(f=new_file_handle, s=modified_line)
			if write_error != nil {
				fmt.println("Error while writing line: ", modified_line)
				return .Write_Error
			}
			continue
		}
		
		if strings.index(s=l, substr="{%posts%}") >= 0 {
			for p in posts {
				post_bloc := create_index_article_bloc(p=p) or_return
				i, write_error := os.write_string(f=new_file_handle, s=post_bloc)
				if write_error != nil {
					fmt.println("Error while writing line: ", l)
					return .Write_Error
				}
			}
			continue
		}

		// Nothing has been written yet: copy the old line as such.
		i, write_error := os.write_string(f=new_file_handle, s=l)
		if write_error != nil {
			fmt.println("Error while writing line: ", l)
			return .Write_Error
		}
	}
	
	closing_error := os.close(f=new_file_handle)
	if closing_error != nil {
		fmt.println("Error while closing: ", new_file_location)
		return .Write_Error
	}
	return .None
}

// Create the div bloc for a post that will be in the blog/index.html page.
// The blog page is located at https://yoururl.com/blog
create_index_article_bloc :: proc(p: Post) -> (bloc: string, err:Parsing_Error) {
	file := fmt.tprint(BLOG_SOURCE_FILES, "template_index_article_bloc.html", sep=PLATEFORM_PATH_SEPARATOR)
	template, template_error := os.read_entire_file_from_path(
		name=file, allocator=context.temp_allocator
	)
	if template_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(template_error)
		return bloc, .Cant_Read_File
	}

	t := string(template)
	lines : []string = strings.split_lines(s=t, allocator=context.temp_allocator)

	beautiful_date, date_error := parse_half_date_from_string(s=p.date)
	if date_error != nil {
		fmt.println("Problem parsing the date:", p.date)
	}
	slug, was_allocation := strings.replace(s=p.file_name, old=".md", new="", n=1, allocator=context.temp_allocator)
	if !was_allocation {
		return bloc, .Wrong_Format
	}

	for l in lines {
		modified_line: string
		modified_line, _ = parse_and_replace_inline(l=l, old="{%title%}", new=p.title) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%date%}", new=p.date) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%parseddate%}", new=beautiful_date) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%articledescription%}", new=p.summary) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%link%}", new=slug)
		
		if l != modified_line { 
			bloc = fmt.tprint(bloc, modified_line, sep="\n")
			continue
		}

		if strings.index(s=l, substr="{%tags%}") >= 0 {
			sane_tag: string
			for c in p.tags {
				sane_tag = strings.to_snake_case(html_sanitize_link(s=c))
				tag_link := fmt.tprint(
					"<a class=\"mr-3 text-sm font-medium uppercase text-teal-400 hover:text-teal-300 dark:hover:text-teal-300\" href=\"/tags/",
					sane_tag,
					"\">",
					c,
					"</a>",
					 sep=""
				)
				bloc = fmt.tprint(bloc, tag_link, sep="\n")
			}
			continue
		}
		// Nothing has been written yet: copy the old line as such.
		bloc = fmt.tprint(bloc, l, sep="\n")
	}
	return bloc, .None
}

// Create the blog/index.html page.
// Copy the template_blog_index.html page and parse it to add blog's index.html 
// or a tag posts listing.
// The page is located at https://yoururl.com/blog
create_posts_listing_with_html_template :: proc(posts: [dynamic]Post, tags: [dynamic]Tag, tag: string = "") -> Parsing_Error {
	file := fmt.tprint(BLOG_SOURCE_FILES, "template_blog_index.html", sep=PLATEFORM_PATH_SEPARATOR)
	template, template_error := os.read_entire_file_from_path(
		name=file, allocator=context.temp_allocator
	)
	if template_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(template_error)
		return .Cant_Read_File
	}

	t := string(template)
	lines : []string = strings.split_lines(s=t, allocator=context.temp_allocator)

	new_file_location: string
	if tag != "" {
		sane_tag := html_sanitize_link(s=tag)
		snaked_tag := strings.to_snake_case(sane_tag)
		new_folder_location := fmt.tprint(
		BLOG_GENERATED_FILES, "tags", snaked_tag, 
		sep=PLATEFORM_PATH_SEPARATOR
		)
		if !os.is_dir(path=new_folder_location) {
	    	create_folder_error := os.make_directory(name=new_folder_location)
			if create_folder_error != os.ERROR_NONE {
				fmt.println("The following error occured while trying to create the folder: ", new_folder_location) 
				fmt.println(create_folder_error)
				return .Write_Error
			}
		}
		new_file_location = fmt.tprint(BLOG_GENERATED_FILES, "tags", snaked_tag, "index.html", sep=PLATEFORM_PATH_SEPARATOR)
	
	} else {
		new_file_location = fmt.tprint(BLOG_GENERATED_FILES, "blog", "index.html", sep=PLATEFORM_PATH_SEPARATOR)
	}
	new_file_handle, open_error := os.open(name=new_file_location, flags={.Create})
	if open_error != nil {
		fmt.println(open_error)
		return .Open_Error
	}

	for l in lines {
		modified_line := parse_and_replace_main_meta_data(l=l)
		if tag != "" {
			modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%blogtag%}", new=tag) 
		} else {
			modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%blogtag%}", new="Blog")
		}
		
		if l != modified_line { 
			i, write_error := os.write_string(f=new_file_handle, s=modified_line)
			if write_error != nil {
				fmt.println("Error while writing line: ", modified_line)
				return .Write_Error
			}
			continue
		}

		if strings.index(s=l, substr="{%static%}") >= 0 {
			static_relative := "../../static"
			modified_line: string
			if tag == "" {
				static_relative = "../static"
			}
			modified_line, _ = parse_and_replace_inline(l=l, old="{%static%}", new=static_relative)
			i, write_error := os.write_string(f=new_file_handle, s=modified_line)
			if write_error != nil {
				fmt.println("Error while writing line: ", l)
				return .Write_Error
			}
		}
		
		if strings.index(s=l, substr="{%posts%}") >= 0 {
			post_bloc: string
			for p in posts {
				if tag =="" {
					// Blog page: display all
					post_bloc = create_blog_index_article_bloc(p=p, tag=tag) or_return
					i, write_error := os.write_string(f=new_file_handle, s=post_bloc)
					if write_error != nil {
						fmt.println("Error while writing line: ", l)
						return .Write_Error
					}
				} else if slice.contains(p.tags, tag) {
					post_bloc = create_blog_index_article_bloc(p=p, tag=tag) or_return
					i, write_error := os.write_string(f=new_file_handle, s=post_bloc)
					if write_error != nil {
						fmt.println("Error while writing line: ", l)
						return .Write_Error
					}
				} else {
					continue
				}
			}
			continue
		}

		if strings.index(s=l, substr="{%tags%}") >= 0 {
			for t in tags {
				aria_label := fmt.tprint("View posts tagged", t.name)
				sane_tag := html_sanitize_link(s=t.name)
				snaked_tag := strings.to_snake_case(sane_tag)
				html_link := fmt.tprint("/tags/", snaked_tag, sep="")
				css_class := "px-3 py-2 text-sm font-medium uppercase text-gray-500 hover:text-teal-300 dark:text-gray-300 dark:hover:text-teal-300"
				tag_link: string
				if tag != t.name {
					tag_link = fmt.tprint(
						"<li class=\"my-3\">",
						"<a class=\"",
						css_class,
						"\" aria-label=\"",
						aria_label,
						"\" href=\"",
						html_link,
						"\">", 
						t.name,
						" (",
						t.occurences,
						")</a></li>",
						 sep=""
					)
				} else {
					css_class = "px-3 py-2 text-sm font-medium uppercase text-teal-400"
					tag_link = fmt.tprint(
						"<li class=\"my-3\">",
						"<span class=\"",
						css_class,
						"\" aria-label=\"",
						aria_label,
						"\" href=\"",
						html_link,
						"\">", 
						t.name,
						" (",
						t.occurences,
						")</span></li>",
						 sep=""
					)
				}
				
				
				i, write_error := os.write_string(f=new_file_handle, s=tag_link)
				if write_error != nil {
					fmt.println("Error while writing line: ", tag_link)
					return .Write_Error
				}
			}
			
			continue
		}

		// Nothing has been written yet: copy the old line as such.
		i, write_error := os.write_string(f=new_file_handle, s=l)
		if write_error != nil {
			fmt.println("Error while writing line: ", l)
			return .Write_Error
		}
	}
	
	closing_error := os.close(f=new_file_handle)
	if closing_error != nil {
		fmt.println("Error while closing: ", new_file_location)
		return .Write_Error
	}
	return .None
}

// Create the html div bloc for the post on the landing page of the blog.
// The page is located at https://yoururl.com/blog
create_blog_index_article_bloc :: proc(p: Post, tag: string = "") -> (bloc: string, err:Parsing_Error) {
	file := fmt.tprint(BLOG_SOURCE_FILES, "template_blog_index_article_bloc.html", sep=PLATEFORM_PATH_SEPARATOR)
	template, template_error := os.read_entire_file_from_path(
		name=file, allocator=context.temp_allocator
	)
	if template_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(template_error)
		return bloc, .Cant_Read_File
	}

	t := string(template)
	lines : []string = strings.split_lines(s=t, allocator=context.temp_allocator)

	beautiful_date, date_error := parse_half_date_from_string(s=p.date)
	if date_error != nil {
		fmt.println("Problem parsing the date:", p.date)
	}
	slug, was_allocation := strings.replace(s=p.file_name, old=".md", new="", n=1, allocator=context.temp_allocator)
	if !was_allocation {
		return bloc, .Wrong_Format
	}

	for l in lines {
		modified_line: string
		modified_line, _ = parse_and_replace_inline(l=l, old="{%title%}", new=p.title) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%date%}", new=p.date) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%parseddate%}", new=beautiful_date) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%articledescription%}", new=p.summary) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%link%}", new=slug)

		if l != modified_line { 
			bloc = fmt.tprint(bloc, modified_line, sep="\n")
			continue
		}

		if strings.index(s=l, substr="{%tags%}") >= 0 {
			sane_tag: string
			for c in p.tags {
				sane_tag = strings.to_snake_case(html_sanitize_link(s=c))
				tag_link := fmt.tprint(
					"<a class=\"mr-3 text-sm font-medium uppercase text-teal-400 hover:text-teal-300 dark:hover:text-teal-300\" href=\"/tags/",
					sane_tag,
					"\">",
					c,
					"</a>",
					 sep=""
				)
				bloc = fmt.tprint(bloc, tag_link, sep="\n")
			}
			continue
		}
		// Nothing has been written yet: copy the old line as such.
		bloc = fmt.tprint(bloc, l, sep="\n")
	}
	return bloc, .None
}

// Create the tags/index.html page using template_tags_index.html
// The tags page is located at https://yoururl.com/tags
create_tags_index_with_html_template :: proc(tags: [dynamic]Tag) -> Parsing_Error {
	file := fmt.tprint(BLOG_SOURCE_FILES, "template_tags_index.html", sep=PLATEFORM_PATH_SEPARATOR)
	template, template_error := os.read_entire_file_from_path(name=file, allocator=context.temp_allocator)
	if template_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(template_error)
		return .Cant_Read_File
	}

	t := string(template)
	lines : []string = strings.split_lines(s=t, allocator=context.temp_allocator)

	new_file_location := fmt.tprint(BLOG_GENERATED_FILES, "tags", "index.html", sep=PLATEFORM_PATH_SEPARATOR)
	new_file_handle, open_error := os.open(name=new_file_location, flags={.Create})
	if open_error != nil {
		fmt.println(open_error)
		return .Open_Error
	}

	for l in lines {
		modified_line := parse_and_replace_main_meta_data(l=l)
		if l != modified_line { 
			i, write_error := os.write_string(f=new_file_handle, s=modified_line)
			if write_error != nil {
				fmt.println("Error while writing line: ", modified_line)
				return .Write_Error
			}
			continue
		}
		
		if strings.index(s=l, substr="{%tags%}") >= 0 {
			for tag in tags {
				tag_bloc := create_tags_tag_bloc(tag=tag) or_return
				i, write_error := os.write_string(f=new_file_handle, s=tag_bloc)
				if write_error != nil {
					fmt.println("Error while writing line: ", l)
					return .Write_Error
				}
			}
			continue
		}

		// Nothing has been written yet: copy the old line as such.
		i, write_error := os.write_string(f=new_file_handle, s=l)
		if write_error != nil {
			fmt.println("Error while writing line: ", l)
			return .Write_Error
		}
	}
	
	closing_error := os.close(f=new_file_handle)
	if closing_error != nil {
		fmt.println("Error while closing: ", new_file_location)
		return .Write_Error
	}
	return .None
}

// Create a div bloc representing a tag used on our blog for our posts in the tags page.
// The tags page is located at https://yoururl.com/tags
create_tags_tag_bloc :: proc(tag: Tag) -> (bloc: string, err:Parsing_Error) {
	file := fmt.tprint(BLOG_SOURCE_FILES, "template_tags_index_tag_bloc.html", sep=PLATEFORM_PATH_SEPARATOR)
	template, template_error := os.read_entire_file_from_path(name=file, allocator=context.temp_allocator)
	if template_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(template_error)
		return bloc, .Cant_Read_File
	}

	t := string(template)
	lines : []string = strings.split_lines(s=t, allocator=context.temp_allocator)
	sane_tag := html_sanitize_link(s=tag.name)
	snaked_tag := strings.to_snake_case(sane_tag)

	for l in lines {
		modified_line: string 
		modified_line, _ = parse_and_replace_inline(l=l, old="{%tagname%}", new=tag.name)		
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%sanitizedtag%}", new=snaked_tag) 
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%occurences%}", new=fmt.tprint(tag.occurences)) 
		
		if l != modified_line { 
			bloc = fmt.tprint(bloc, modified_line, sep="\n")
			continue
		}

		// Nothing has been written yet: copy the old line as such.
		bloc = fmt.tprint(bloc, l, sep="\n")
	}
	return bloc, .None
}

// Create the About page with the template_about.html
// The about page is located at https://yoururl.com/about
create_about_with_html_template :: proc() -> Parsing_Error {
	file := fmt.tprint(BLOG_SOURCE_FILES, "template_about.html", sep=PLATEFORM_PATH_SEPARATOR)
	template, template_error := os.read_entire_file_from_path(name=file, allocator=context.temp_allocator)
	if template_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(template_error)
		return .Cant_Read_File
	}

	t := string(template)
	lines : []string = strings.split_lines(s=t, allocator=context.temp_allocator)
	new_folder_location := fmt.tprint(BLOG_GENERATED_FILES, "about", sep=PLATEFORM_PATH_SEPARATOR)
	if !os.is_dir(path=new_folder_location) {
    	create_folder_error := os.make_directory(name=new_folder_location)
		if create_folder_error != os.ERROR_NONE {
			fmt.println("The following error occured while trying to create the folder: ", new_folder_location) 
			fmt.println(create_folder_error)
			return .Write_Error
		}
	}

	new_file_location := fmt.tprint(new_folder_location, "index.html", sep=PLATEFORM_PATH_SEPARATOR)
	new_file_handle, open_error := os.open(name=new_file_location, flags={.Create})
	if open_error != nil {
		fmt.println(open_error)
		return .Open_Error
	}

	for l in lines {
		modified_line := parse_and_replace_main_meta_data(l=l)
		modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%company%}", new=YOUR_COMPANY)
		if l != modified_line { 
			i, write_error := os.write_string(f=new_file_handle, s=modified_line)
			if write_error != nil {
				fmt.println("Error while writing line: ", modified_line)
				return .Write_Error
			}
			continue
		}

		// Nothing has been written yet: copy the old line as such.
		i, write_error := os.write_string(f=new_file_handle, s=l)
		if write_error != nil {
			fmt.println("Error while writing line: ", l)
			return .Write_Error
		}
	}
	
	closing_error := os.close(f=new_file_handle)
	if closing_error != nil {
		fmt.println("Error while closing: ", new_file_location)
		return .Write_Error
	}
	return .None
}

html_sanitize_link :: proc(s: string) -> string {
	sane_string, _ := strings.replace(s=s, old="&", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old=":", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="?", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old=",", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="#", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="[", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="]", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="{", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="}", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old=".", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="!", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="%", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="*", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="+", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="=", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="(", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old=")", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="~", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="\"", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old="'", new="", n=-1)
	sane_string, _ = strings.replace(s=sane_string, old=" ", new="", n=-1)
	return sane_string
}