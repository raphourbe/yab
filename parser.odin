package yab

import "core:os"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:time"
import datetime "core:time/datetime"


parse_and_replace_inline :: proc(l: string, old:string, new: string) -> (string, bool) {
	return strings.replace(s=l, old=old, new=new, n=2, allocator=context.temp_allocator)
}

parse_and_replace_main_meta_data :: proc(l: string) -> string{
	modified_line: string
	modified_line, _ = parse_and_replace_inline(l=l, old="{%blogbaseline%}", new=BLOG_BASELINE) 
	modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%blogdescription%}", new=BLOG_DESCRIPTION) 
	modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%yourname%}", new=YOUR_NAME) 
	modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%mailaccount%}", new=MAIL_ACCOUNT) 
	modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%githubaccount%}", new=GITHUB_ACCOUNT) 
	modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%xaccount%}", new=X_ACCOUNT) 
	modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%linkedinaccount%}", new=LINKEDIN_ACCOUNT)
	return modified_line 
}

parse_md_file :: proc(file:string) -> (p: Post, err: Parsing_Error) {
	data, data_error := os.read_entire_file_from_path(name=file, allocator=context.temp_allocator)
	if data_error != os.ERROR_NONE {
		fmt.println("The following error occured while reading the file: ", file) 
		fmt.println(data_error)
		return p, .Cant_Read_File
	}
	content := string(data)
	lines : []string = strings.split_lines(s=content, allocator=context.temp_allocator)

	path := strings.split(s=file, sep=PLATEFORM_PATH_SEPARATOR)
	p.file_name = strings.trim_suffix(s=path[len(path) - 1], suffix=".md")
	parse_post_metadata(lines=lines[0:8], p=&p) or_return
	parse_post_content(lines=lines[8:], p=&p) or_return
	return
}

// Post Metadata are at the top of the .md file and are stored between two "---" lines.
// They are always the same and should be put in the same order everytime.
// The number of metadata is fixed.
// If you want to add metadata, enhance this function.
// :param lines: All the metadata lines, including the "---".
parse_post_metadata :: proc(lines: []string, p: ^Post) -> Parsing_Error {
	parsing_metadata_string_line :: proc(line: string) -> (s: string, err: Parsing_Error) {
		first_quote_index : int = strings.index(s=line, substr="\"")
		if first_quote_index == -1 {
	        fmt.println("Invalid format: missing first quote")
			return s, .Wrong_Format
		}
		if !strings.has_suffix(s=line, suffix="\"") {
	        fmt.println("Invalid format: missing closing quote")
	        return s, .Wrong_Format
	    }
	    s = line[first_quote_index+1:len(line)-1]
	    return s, .None
	}

	parsing_metadata_tags_line :: proc(line: string) -> (t: []string, err: Parsing_Error) {
		// tag line example: tags: ["next.js", "tailwind", "sme"]
		without_quotes := strings.split(line, sep="\"")
		if len(without_quotes) < 3 {
	        fmt.println("Invalid format: missing at least one tag or quotes")
			return t, .Wrong_Format
		}
		// number of tags is following an arithmetic progression => un = u0 + 2n with u0=1
		number_of_tags := (len(without_quotes) - 1) / 2
		t = make([]string, number_of_tags)
		for i in 0..<number_of_tags {
			t[i] = without_quotes[1+2*i]
		}
		return t, .None
	}

	if lines[5] == "draft: true" || lines[5] == "draft:true" {
		return .Is_Draft
	}

	p.title   = parsing_metadata_string_line(line=lines[1]) or_return
	p.date    = parsing_metadata_string_line(line=lines[2]) or_return
	p.lastmod = parsing_metadata_string_line(line=lines[3]) or_return
	p.summary = parsing_metadata_string_line(line=lines[6]) or_return

	p.tags    = parsing_metadata_tags_line(line=lines[4]) or_return

	return .None
}

// Content in a .md file is everything after the last "---" of the metadata part.
// :param lines: Everything after the "---" of the metadata part.
parse_post_content :: proc(lines: []string, p: ^Post) -> Parsing_Error {
	content : [dynamic]string
	in_paragraph_bloc: bool
	in_code_bloc: bool
	in_enumeration_bloc: i64 = -1 // represent the enumeration number we are / -1 if not in an enumeration bloc
	in_list_bloc: bool
	in_unescaped_html_bloc: bool
	in_blockquote_bloc: bool
	paragraph: string

	for value, index in lines {
		// Blank line
		if len(value) == 0 {
			continue
		}

		// Titles: only to h5
		if strings.has_prefix(s=value, prefix="#") {
			html_title: string
			title: string
			href: string
			a_tag: string
			title_id: string
			if strings.has_prefix(s=value, prefix="#####") {
				title = strings.trim_prefix(s=value, prefix="#####")
				href, title_id, a_tag = parse_blog_title_to_create_href_id_and_tag(title=title, post_name=p.file_name)
				html_title = fmt.tprint("<h5 class=\"content-header\" id=\"", title_id, "\">", a_tag, title,"</h5>", sep="")
				append(&p.toc.titles, H_Title{level=5, value=title, href=href})
			} else if strings.has_prefix(s=value, prefix="####") {				
				title = strings.trim_prefix(s=value, prefix="####")				
				href, title_id, a_tag = parse_blog_title_to_create_href_id_and_tag(title=title, post_name=p.file_name)
				html_title = fmt.tprint("<h4 class=\"content-header\" id=\"", title_id, "\">", a_tag, title,"</h4>", sep="")
				append(&p.toc.titles, H_Title{level=4, value=title, href=href})
			} else if strings.has_prefix(s=value, prefix="###") {
				title = strings.trim_prefix(s=value, prefix="###")
				href, title_id, a_tag = parse_blog_title_to_create_href_id_and_tag(title=title, post_name=p.file_name)
				html_title = fmt.tprint("<h3 class=\"content-header\" id=\"", title_id, "\">", a_tag, title,"</h3>", sep="")
				append(&p.toc.titles, H_Title{level=3, value=title, href=href})
			} else if strings.has_prefix(s=value, prefix="##") {
				title = strings.trim_prefix(s=value, prefix="##")
				href, title_id, a_tag = parse_blog_title_to_create_href_id_and_tag(title=title, post_name=p.file_name)
				html_title = fmt.tprint("<h2 class=\"content-header\" id=\"", title_id, "\">", a_tag, title,"</h2>", sep="")
				append(&p.toc.titles, H_Title{level=2, value=title, href=href})
			} else if strings.has_prefix(s=value, prefix="#") {
				title = strings.trim_prefix(s=value, prefix="#")
				href, title_id, a_tag = parse_blog_title_to_create_href_id_and_tag(title=title, post_name=p.file_name)
				html_title = fmt.tprint("<h1 class=\"content-header\" id=\"", title_id, "\">", a_tag, title,"</h1>", sep="")
				append(&p.toc.titles, H_Title{level=1, value=title, href=href})
			} else {
				html_title = value
			}
			append(&content, html_title)
			continue
		}
		
		// Big code ```
		if strings.has_prefix(s=value, prefix="```") && !in_code_bloc {
			start_file_name_index := strings.index(s=value, substr=":") + 1
			file_name: string
			if start_file_name_index!=0 {
				file_name = value[start_file_name_index:]
			}
			paragraph = fmt.tprint("<h5 class=\"font-medium\">", file_name, "</h5><div class=\"code-bloc-content\"><pre><code class=\"language-javascript language-html\">", sep="")
			in_code_bloc = true
			continue
		}
		if in_code_bloc {
			if strings.has_prefix(s=value, prefix="```")  {
				paragraph = fmt.tprint(paragraph, "</code></pre></div>", sep="")
				in_code_bloc = false
				append(&content, paragraph)
				continue
			}
			if index+1 < len(lines) {
				paragraph = fmt.tprint(paragraph, value, sep="\n")
				continue
			} 
			return .Code_Bloc_Unfinished
		}

		// Enumeration
		if strings.has_prefix(s=value, prefix="1.") && in_enumeration_bloc == -1 {
			in_enumeration_bloc = 1
			paragraph = fmt.tprint("<ol><li>", value[3:], sep="")
			if index+1 < len(lines) && len(lines[index+1]) != 0 {
				// Is the <li> spreading on several lines? Or should we close the </li>
				if strings.has_prefix(s=lines[index+1], prefix="2.") {
					// This one is over.
					paragraph = fmt.tprint(paragraph, "</li>", sep="")
					in_enumeration_bloc += 1
				}
			} else {
				// This one is over.
				paragraph = fmt.tprint(paragraph, "</li>", sep="")
				in_enumeration_bloc += 1
			}
			continue
		}
		if in_enumeration_bloc > 0 {
			// The first space is before the value we want
			enum_index := strings.index(s=value, substr=" ") + 1
			buf: [4]byte

			enum_prefix := fmt.tprint(strconv.write_int(buf=buf[:], i=in_enumeration_bloc, base=10), ".", sep="")
			if index+1 < len(lines) && len(lines[index+1]) != 0 {
				if strings.has_prefix(s=value, prefix=enum_prefix) {
					paragraph = fmt.tprint(paragraph, "<li>", value[enum_index:], sep="")
				} else {
					paragraph = fmt.tprint(paragraph, value[enum_index:], sep=" ")
				}

				// Is the <li> spreading on several lines? Or should we close the </li>
				enum_prefix = fmt.tprint(strconv.write_int(buf=buf[:], i=in_enumeration_bloc+1, base=10), ".", sep="")
				if strings.has_prefix(s=lines[index+1], prefix=enum_prefix) {
					// This one is over.
					paragraph = fmt.tprint(paragraph, "</li>", sep="")
					in_enumeration_bloc += 1
				}
				// paragraph = fmt.tprint(paragraph, "<li>", value[enum_index:], "</li>", sep="")
			} else {
				// Last line of the list bloc. Is it from an opened <li> or is it a new one?
				if strings.has_prefix(s=value, prefix=enum_prefix) {
					paragraph = fmt.tprint(paragraph, "<li>", value[enum_index:], "</li></ol>", sep="")
				} else {
					paragraph = fmt.tprint(paragraph, value[enum_index:], "</li></ol>", sep=" ")
				}
				in_enumeration_bloc = -1
				paragraph = parse_paragraph_for_inline_shenanigans(p=paragraph)
				append(&content, paragraph)
			}
			continue
		}

		// List (no enumeration)
		if strings.has_prefix(s=value, prefix="-") && !in_list_bloc {
			paragraph = fmt.tprint("<ul><li>", value[2:], sep="")
			if index+1 < len(lines) && len(lines[index+1]) != 0 {
				// Is the <li> spreading on several lines? Or should we close the </li>
				if strings.has_prefix(s=lines[index+1], prefix="-") {
					// This one is over.
					paragraph = fmt.tprint(paragraph, "</li>", sep="")
				}
			} else {
				// This one is over.
				paragraph = fmt.tprint(paragraph, "</li>", sep="")
			}
			in_list_bloc = true
			continue
		}
		if in_list_bloc {
			// The first space is before the value we want
			enum_index := strings.index(s=value, substr=" ") + 1
			if index+1 < len(lines) && len(lines[index+1]) != 0 {
				if strings.has_prefix(s=value, prefix="-") {
					paragraph = fmt.tprint(paragraph, "<li>", value[enum_index:], sep="")
				} else {
					paragraph = fmt.tprint(paragraph, value[enum_index:], sep=" ")
				}

				// Is the <li> spreading on several lines? Or should we close the </li>
				if strings.has_prefix(s=lines[index+1], prefix="-") {
					// This one is over.
					paragraph = fmt.tprint(paragraph, "</li>", sep="")
				}
			} else {
				// Last line of the list bloc. Is it from an opened <li> or is it a new one?
				if strings.has_suffix(s=paragraph, suffix="</li>") {
					paragraph = fmt.tprint(paragraph, "<li>", value[enum_index:], "</li></ul>", sep="")
				} else {
					paragraph = fmt.tprint(paragraph, value[enum_index:], "</li></ul>", sep=" ")
				}
				in_list_bloc = false
				paragraph = parse_paragraph_for_inline_shenanigans(p=paragraph)
				append(&content, paragraph)
			}
			continue
		}

		// TOCLine: Table Of Content
		// Special feature. We skip it know since we have no idea what the titles are yet.
		if strings.has_prefix(s=value, prefix="<TOC") {
			p.toc.exists = true
			p.toc.line_start = len(content)
			if strings.contains(s=value, substr="heading=") {
				max_level := strings.split(s=value, sep="{")
				if len(max_level) != 2 {
					fmt.println("Problem parsing Table of Content. No \"{\" found. The max heading must be written has \"heading={X}\".")
					return .Wrong_Format
				}
				max_level = strings.split(s=max_level[1], sep="}")
				if len(max_level) != 2 {
					fmt.println("Problem parsing Table of Content. No \"}\" found. The max heading must be written has \"heading={X}\".")
					return .Wrong_Format
				}
				p.toc.max_level, _ = strconv.parse_uint(s=max_level[0])
			}
			continue
		}

		// Html bloc
		// They should start with a <html>
		// End with a <html/>
		if strings.has_prefix(s=value, prefix="<html>") && !in_unescaped_html_bloc {
			paragraph = strings.trim(s=value, cutset="<html>")
			if index+1 < len(lines) {
				is_end_html_bloc: bool = strings.has_suffix(s=value, suffix="</html>")
				if is_end_html_bloc {
					// We already leave the html bloc
					paragraph = strings.trim(s=paragraph, cutset="</html>")
					append(&content, paragraph)
					continue
				} else if len(lines[index+1]) == 0 && !is_end_html_bloc {
					return .Html_Bloc_Unfinished
				}
			}
			in_unescaped_html_bloc = true
			continue
		}
		if in_unescaped_html_bloc {
			is_end_html_bloc: bool = strings.has_suffix(s=value, suffix="</html>")
			if is_end_html_bloc {
				paragraph = fmt.tprint(paragraph, strings.trim(s=value, cutset="</html>"), sep="")
				in_unescaped_html_bloc = false
				append(&content, paragraph)
				continue
			}
			paragraph = fmt.tprint(paragraph, value, sep="")
			continue
		}

		// Opening Blockquote bloc
		// Should start with a >
		// Can contains <p></p> inside
		if strings.has_prefix(s=value, prefix="> ") && !in_blockquote_bloc {
			in_blockquote_bloc = true
			paragraph = parse_paragraph_for_inline_shenanigans(p=value[2:])
			paragraph = fmt.tprint("<blockquote><p>", paragraph, sep="")
			in_paragraph_bloc = true
			// single line paragraph check
			if index+1 < len(lines) {
				if len(lines[index+1]) == 0 {
					paragraph = fmt.tprint(paragraph, "</p></blockquote>", sep="")
					in_blockquote_bloc = false
					in_paragraph_bloc = false
					append(&content, paragraph)
					paragraph = ""
				} else if len(strings.trim_space(s=lines[index+1])) == 1 {
					// There is only a >, so we close the </p> for a new paragraph bloc latter
					paragraph = fmt.tprint(paragraph, "</p>", sep="")
					in_paragraph_bloc = false
					append(&content, paragraph)
					paragraph = ""
				} 
			} else {
				paragraph = fmt.tprint(paragraph, "</p></blockquote>", sep="")
				in_blockquote_bloc = false
				in_paragraph_bloc = false
				append(&content, paragraph)
				paragraph = ""
			}
			continue
		} else if in_blockquote_bloc {
			if index+1 < len(lines) {
				if len(lines[index+1]) == 0 {
					paragraph = fmt.tprint(paragraph, value[2:], sep=" ")
					paragraph = parse_paragraph_for_inline_shenanigans(p=paragraph)
					paragraph = fmt.tprint(paragraph, "</p></blockquote>", sep="")
					in_blockquote_bloc = false
					in_paragraph_bloc = false
					append(&content, paragraph)
					paragraph = ""
				} else if len(strings.trim_space(s=lines[index+1])) == 1 {
					// There is only a >, so we close the </p> for a new paragraph bloc latter
					paragraph = fmt.tprint(paragraph, value[2:], sep=" ")
					paragraph = parse_paragraph_for_inline_shenanigans(p=paragraph)
					paragraph = fmt.tprint(paragraph, "</p>", sep="")
					in_paragraph_bloc = false
					append(&content, paragraph)					
					paragraph = ""
				} else {
					paragraph = fmt.tprint(paragraph, value[2:], sep=" ")
				}
			} else {
				paragraph = fmt.tprint(paragraph, value[2:], sep=" ")
				paragraph = parse_paragraph_for_inline_shenanigans(p=paragraph)
				paragraph = fmt.tprint(paragraph, "</p></blockquote>", sep="")
				in_blockquote_bloc = false
				in_paragraph_bloc = false
				append(&content, paragraph)
				paragraph = ""
			}
			continue
		}

		// Paragraph
		// Tricky part: if someone just \n after two empty spaces: needs to be a <br/>
		// If someone just \n for clarity in the file => same paragraph
		if !in_paragraph_bloc {
			paragraph = fmt.tprint("<p>", value, sep="")
			in_paragraph_bloc = true
			// single line paragraph check
			if index+1 < len(lines) {
				if len(lines[index+1]) == 0 {
					paragraph = fmt.tprint(paragraph, "</p>", sep="")
					in_paragraph_bloc = false
				} else {
					continue
				}
			} else {
				paragraph = fmt.tprint(paragraph, "</p>", sep="")
				in_paragraph_bloc = false
			}
		} else {
			paragraph = fmt.tprint(paragraph, value, sep=" ")
			if index+1 < len(lines) {
				if len(lines[index+1]) == 0 {
					paragraph = fmt.tprint(paragraph, "</p>", sep="")
					in_paragraph_bloc = false
				} else if strings.has_suffix(s=value, suffix="  ") {
					paragraph = fmt.tprint(paragraph, "<br/>", sep="")
					continue
				} else {
					continue
				}
			} else {
				// End of the file. Closing the paragraph.
				paragraph = fmt.tprint(paragraph, "</p>", sep="")
				in_paragraph_bloc = false
			}
		}
		
		// Find images in paragraph and make them <img />
		paragraph = parse_paragraph_for_inline_shenanigans(p=paragraph)
		append(&content, paragraph)

		// Closing Blockquote bloc
		// Should start with a >
		// Can contains <p></p> inside
		if strings.has_prefix(s=value, prefix=">") && in_blockquote_bloc {
			if index+1 < len(lines) {
				if len(lines[index+1]) == 0 {
					append(&content, "</blockquote>")
					in_blockquote_bloc = false
				}
			} else {
				append(&content, "</blockquote>")
				in_blockquote_bloc = false
			}
		}
	}
	p.content = content
	return .None
}

parse_paragraph_for_inline_shenanigans :: proc(p: string) -> string {
	// Find specific html characters
	paragraph : string = parse_html_char_in_paragraph(p=p)
	// Find images in paragraph and make them <img />
	paragraph = parse_img_in_paragraph(p=paragraph)
	// Find links in paragraph and make them <a></a>
	paragraph = parse_links_in_paragraph(p=paragraph)
	// Find inline code
	paragraph = parse_code_in_paragraph(p=paragraph)
	// Find bold and italic
	paragraph = parse_italic_and_bold_in_paragraph(p=paragraph)
	return paragraph
}

// Find ![xxx](http://xxx) patterns and change them into <img /> html
// Must be done before finding links!
// ![ is the distinctive case of images in markdown.
parse_img_in_paragraph :: proc(p: string) -> string {
	cut := strings.split(p, sep="![")
	// Example of image on a single line:
	// ["<p>", "Building warnings](/static/images/an-approach-to-pdf-generation-with-directus/BuildingError.webp)</p>"]
	if len(cut) < 2 {
		return p
	}
	parsed_p: string
	// number of images is following an arithmetic progression => un = u0 + n with u0=1
	number_of_imgs := len(cut) - 1
	for i in 0..=number_of_imgs {
		if i == 0 {
			parsed_p = cut[i]
			continue
		}
		// We are working on "Alt](http://xxx) blabla " if we are here
		// We need to skip what is before the first parenthesis.
		start_link := strings.index(s=cut[i], substr="(")
		end_link := strings.index(s=cut[i], substr=")")
		end_alt := strings.index(s=cut[i], substr="]")
		parsed_p = fmt.tprint(parsed_p, "<img src=\"", cut[i][start_link+1:end_link],"\", alt=\"", cut[i][:end_alt], "\" />", sep="")
	}
	parsed_p = fmt.tprint(parsed_p, "</p>", sep="")
	return parsed_p
}

// Find [xxx](http://xxx) patterns and change them into <a></a> html
// Must be done after finding Images !
// ]( is the distinctive case of links in markdown.
parse_links_in_paragraph :: proc(p: string) -> string {
	cut := strings.split(p, sep="](")
	if len(cut) < 2 {
		return p
	}
	parsed_p: string
	// number of links is following an arithmetic progression => un = u0 + n with u0=1
	number_of_links := len(cut) - 1

	for i in 0..=number_of_links {
		if i == 0 {
			// If we have something like cut[i] = "xxx [xxx] xxx [things of interest"
			// we want to forget about the first "[" to get to the last one.
			reversed := strings.reverse(cut[i])
			start_name := len(cut[i]) - 1 - strings.index(s=reversed, substr="[")
			// start_name := strings.index(s=cut[i], substr="[")
			end_link := strings.index(s=cut[i+1], substr=")")
			parsed_p = fmt.tprint(cut[i][0:start_name], "<a class=\"text-teal-400 hover:text-teal-300 dark:hover:text-teal-300\" href=\"", cut[i+1][0:end_link],"\">", cut[i][start_name+1:], "</a>", sep="")
			continue
		} else if i == number_of_links {
			end_parenthesis := strings.index(s=cut[i], substr=")")
			parsed_p = fmt.tprint(parsed_p, cut[i][end_parenthesis+1:], sep="")
			continue
		}
		// We are working on "http://xxx) blabla [name" if we are here
		// We need to skip what is before the first parenthesis.
		reversed := strings.reverse(cut[i])
		start_name := len(cut[i]) - 1 - strings.index(s=reversed, substr="[")
		// start_name := strings.index(s=cut[i], substr="[")
		end_parenthesis := strings.index(s=cut[i], substr=")")
		end_link := strings.index(s=cut[i+1], substr=")")
		parsed_p = fmt.tprint(parsed_p, cut[i][end_parenthesis+1:start_name], "<a class=\"text-teal-400 hover:text-teal-300 dark:hover:text-teal-300\" href=\"", cut[i+1][0:end_link], "\">", cut[i][start_name+1:], "</a>", sep="")
	}
	return parsed_p
}

// Find the `code` part in a paragraph.
// Must be done after parsing big code paragraphs starting with ```
parse_code_in_paragraph :: proc(p: string) -> string {
	cut := strings.split(p, sep="`")
	if len(cut) < 3 {
		return p
	}
	parsed_p: string
	// number of code is following an arithmetic progression => un = u0 + 2n with u0=1
	number_of_codes := (len(cut) - 1) / 2
	for i in 0..=len(cut) - 1 {
		if i%2 != 0 {
			parsed_p = fmt.tprint(parsed_p, "<code>", cut[i], "</code>", sep="")			
		} else {
			parsed_p = fmt.tprint(parsed_p, cut[i], sep="")
		}
	}
	return parsed_p
}

parse_italic_and_bold_in_paragraph :: proc(p: string) -> string {
	bold_parsed_p: string
	bold_cut := strings.split(p, sep="**")
	if len(bold_cut) >= 3 {
		// number of bold is following an arithmetic progression => un = u0 + 2n with u0=1
		number_of_bolds := (len(bold_cut) - 1) / 2
		for i in 0..=len(bold_cut) - 1 {
			if i%2 != 0 {
				bold_parsed_p = fmt.tprint(bold_parsed_p, "<b>", bold_cut[i], "</b>", sep="")			
			} else {
				bold_parsed_p = fmt.tprint(bold_parsed_p, bold_cut[i], sep="")
			}
		}
	} else {
		bold_parsed_p = p
	}
	italic_cut := strings.split(bold_parsed_p, sep="*")
	if len(italic_cut) >= 3 {
		parsed_p: string
		// number of bold is following an arithmetic progression => un = u0 + 2n with u0=1
		number_of_italics := (len(italic_cut) - 1) / 2
		for i in 0..=len(italic_cut) - 1 {
			if i%2 != 0 {
				parsed_p = fmt.tprint(parsed_p, "<i>", italic_cut[i], "</i>", sep="")			
			} else {
				parsed_p = fmt.tprint(parsed_p, italic_cut[i], sep="")
			}
		}
		return parsed_p
	} 
	return bold_parsed_p
}

// Parse a date like "YYYY-MM-DD" into something like Thursday, October 12, 2025
parse_complete_date_from_string :: proc(s: string) -> (beautiful_date: string, err: datetime.Error) {
	year, _ := strconv.parse_int(s[:4])
	month, _ := strconv.parse_int(s[5:7])
	day, _ := strconv.parse_int(s[8:])
	d := datetime.components_to_date(year=year, month=month, day=day) or_return
	ordinal := datetime.date_to_ordinal(date=d) or_return
	day_of_week := datetime.day_of_week(ordinal=ordinal)
	m := time.Month(month)
	beautiful_date = fmt.tprint(day_of_week, ", ", m, " ", day, ", ", s[:4], sep="")
	return beautiful_date, .None
}

// Parse a date like "YYYY-MM-DD" into something like October 12, 2025
parse_half_date_from_string :: proc(s: string) -> (beautiful_date: string, err: datetime.Error) {
	year, _ := strconv.parse_int(s[:4])
	month, _ := strconv.parse_int(s[5:7])
	day, _ := strconv.parse_int(s[8:])
	d := datetime.components_to_date(year=year, month=month, day=day) or_return
	m := time.Month(month)
	beautiful_date = fmt.tprint(m, " ", day, ", ", s[:4], sep="")
	return beautiful_date, .None
}

// Create the code required for html file.
// The characters "&" and "<" and ">" are forbiden and stricly reserved for html.
// Use directly the proper translation in the markdown file.
parse_html_char_in_paragraph :: proc(p: string) -> string {
	// Default parameters start and end are for removing the <p> and </p>
	start: int = 0
	end  : int = 0
	// if strings.has_prefix(s=p, prefix="<blockquote><p>") {
	// 	start=15
	// 	end=17
	// } else if strings.has_prefix(s=p, prefix="<ol><li>") {
	// 	start=8
	// 	end=10
	// } else if strings.has_prefix(s=p, prefix="<ul><li>") {
	// 	start=8
	// 	end=10
	// } else if strings.has_prefix(s=p, prefix="<li>") {
	// 	start=4
	// 	end=5
	// }  else if strings.has_prefix(s=p, prefix="<p>") {
	// 	start=3
	// 	end=4
	// }

	parsed_p: string = p[start:len(p)-end]
	parsed_p, _ = strings.replace(s=parsed_p, old="\"", new="&quot;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="'", new="&apos;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¡", new="&iexcl;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¢", new="&cent;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="£", new="&pound;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¤", new="&curren;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¥", new="&yen;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¦", new="&brvbar;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="§", new="&sect;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¨", new="&uml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="©", new="&copy;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ª", new="&ordf;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="«", new="&laquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¬", new="&not;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="®", new="&reg;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¯", new="&macr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="°", new="&deg;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="±", new="&plusmn;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="²", new="&sup2;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="³", new="&sup3;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="´", new="&acute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="µ", new="&micro;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¶", new="&para;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="·", new="&middot;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¸", new="&cedil;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¹", new="&sup1;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="º", new="&ordm;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="»", new="&raquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¼", new="&frac14;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="½", new="&frac12;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¾", new="&frac34;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="¿", new="&iquest;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="À", new="&Agrave;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Á", new="&Aacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Â", new="&Acirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ã", new="&Atilde;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ä", new="&Auml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Å", new="&Aring;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Æ", new="&AElig;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ç", new="&Ccedil;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="È", new="&Egrave;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="É", new="&Eacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ê", new="&Ecirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ë", new="&Euml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ì", new="&Igrave;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Í", new="&Iacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Î", new="&Icirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ï", new="&Iuml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ð", new="&ETH;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ñ", new="&Ntilde;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ò", new="&Ograve;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ó", new="&Oacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ô", new="&Ocirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Õ", new="&Otilde;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ö", new="&Ouml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="×", new="&times;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ø", new="&Oslash;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ù", new="&Ugrave;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ú", new="&Uacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Û", new="&Ucirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ü", new="&Uuml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ý", new="&Yacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Þ", new="&THORN;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ß", new="&szlig;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="à", new="&agrave;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="á", new="&aacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="â", new="&acirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ã", new="&atilde;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ä", new="&auml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="å", new="&aring;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="æ", new="&aelig;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ç", new="&ccedil;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="è", new="&egrave;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="é", new="&eacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ê", new="&ecirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ë", new="&euml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ì", new="&igrave;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="í", new="&iacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="î", new="&icirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ï", new="&iuml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ð", new="&eth;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ñ", new="&ntilde;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ò", new="&ograve;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ó", new="&oacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ô", new="&ocirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="õ", new="&otilde;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ö", new="&ouml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="÷", new="&divide;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ø", new="&oslash;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ù", new="&ugrave;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ú", new="&uacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="û", new="&ucirc;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ü", new="&uuml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ý", new="&yacute;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="þ", new="&thorn;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ÿ", new="&yuml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Œ", new="&OElig;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="œ", new="&oelig;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Š", new="&Scaron;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="š", new="&scaron;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ÿ", new="&Yuml;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ƒ", new="&fnof;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ˆ", new="&circ;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="˜", new="&tilde;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Α", new="&Alpha;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Β", new="&Beta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Γ", new="&Gamma;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Δ", new="&Delta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ε", new="&Epsilon;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ζ", new="&Zeta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Η", new="&Eta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Θ", new="&Theta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ι", new="&Iota;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Κ", new="&Kappa;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Λ", new="&Lambda;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Μ", new="&Mu;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ν", new="&Nu;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ξ", new="&Xi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ο", new="&Omicron;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Π", new="&Pi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ρ", new="&Rho;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Σ", new="&Sigma;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Τ", new="&Tau;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Υ", new="&Upsilon;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Φ", new="&Phi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Χ", new="&Chi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ψ", new="&Psi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="Ω", new="&Omega;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="α", new="&alpha;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="β", new="&beta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="γ", new="&gamma;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="δ", new="&delta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ε", new="&epsilon;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ζ", new="&zeta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="η", new="&eta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="θ", new="&theta;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ι", new="&iota;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="κ", new="&kappa;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="λ", new="&lambda;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="μ", new="&mu;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ν", new="&nu;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ξ", new="&xi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ο", new="&omicron;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="π", new="&pi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ρ", new="&rho;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ς", new="&sigmaf;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="σ", new="&sigma;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="τ", new="&tau;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="υ", new="&upsilon;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="φ", new="&phi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="χ", new="&chi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ψ", new="&psi;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ω", new="&omega;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ϑ", new="&thetasym;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ϒ", new="&upsih;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ϖ", new="&piv;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="–", new="&ndash;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="—", new="&mdash;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="‘", new="&lsquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="’", new="&rsquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="‚", new="&sbquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="“", new="&ldquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="”", new="&rdquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="„", new="&bdquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="†", new="&dagger;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="‡", new="&Dagger;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="•", new="&bull;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="…", new="&hellip;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="‰", new="&permil;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="′", new="&prime;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="″", new="&Prime;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="‹", new="&lsaquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="›", new="&rsaquo;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="‾", new="&oline;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⁄", new="&frasl;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="€", new="&euro;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ℑ", new="&image;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="℘", new="&weierp;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ℜ", new="&real;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="™", new="&trade;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="ℵ", new="&alefsym;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="←", new="&larr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="↑", new="&uarr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="→", new="&rarr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="↓", new="&darr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="↔", new="&harr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="↵", new="&crarr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⇐", new="&lArr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⇑", new="&uArr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⇒", new="&rArr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⇓", new="&dArr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⇔", new="&hArr;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∀", new="&forall;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∂", new="&part;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∃", new="&exist;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∅", new="&empty;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∇", new="&nabla;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∈", new="&isin;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∉", new="&notin;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∋", new="&ni;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∏", new="&prod;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∑", new="&sum;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="−", new="&minus;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∗", new="&lowast;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="√", new="&radic;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∝", new="&prop;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∞", new="&infin;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∠", new="&ang;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∧", new="&and;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∨", new="&or;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∩", new="&cap;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∪", new="&cup;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∫", new="&int;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∴", new="&there4;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="∼", new="&sim;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="≅", new="&cong;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="≈", new="&asymp;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="≠", new="&ne;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="≡", new="&equiv;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="≤", new="&le;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="≥", new="&ge;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⊂", new="&sub;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⊃", new="&sup;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⊄", new="&nsub;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⊆", new="&sube;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⊇", new="&supe;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⊕", new="&oplus;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⊗", new="&otimes;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⊥", new="&perp;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⋅", new="&sdot;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⌈", new="&lceil;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⌉", new="&rceil;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⌊", new="&lfloor;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⌋", new="&rfloor;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⟨", new="&lang;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="⟩", new="&rang;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="◊", new="&loz;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="♠", new="&spades;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="♣", new="&clubs;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="♥", new="&hearts;", n=-1)
	parsed_p, _ = strings.replace(s=parsed_p, old="♦", new="&diams;", n=-1)

	// parsed_p = fmt.tprint(p[:start], parsed_p, p[len(p)-end:], sep="")
	return parsed_p
}

// Add the beautiful ToC
// Heuristic: if the first level in the post is h2, it is considered the highest level
// in the rest of the post.
// Hence, if a h1 is after, it is treated as a h2.
// Heuristic 2: Level titles follow each other. h1, then h2, etc. not h1 then h3.
parse_toc :: proc(p: ^Post) {
	if len(p.toc.titles) == 0 {
		fmt.println("No titles in the article for the table of content.")
		return
	}
	toc: [dynamic]string
	append(&toc, "<details open>")
	append(&toc, "<summary class=\"ml-6 pb-2 pt-2 text-xl font-bold\">Table of Contents</summary>")
	append(&toc, "<div class=\"ml-6\">")
	append(&toc, "<ul>")

	highest_level     : uint = p.toc.titles[0].level
	next_level        : uint = p.toc.titles[0].level
	for t, ind in p.toc.titles {
		value: string

		if ind == len(p.toc.titles) - 1 {
			// Is last title found at an authorized level?
			if t.level <= p.toc.max_level {
				value = fmt.tprint("<li><a href=\"", t.href,"\">", t.value, "</a></li>")
			}
			level_to_close: uint
			if t.level > p.toc.max_level {
				// Caveats: if the number of level is not following each other <h2> then <h4>
				// for example, it will be problematic.
				level_to_close = highest_level
			} else {
				level_to_close = t.level - highest_level + 1
			}
			// closing time for the </ul>
			if level_to_close > 1 {
				for j in 0..=level_to_close-1 {
					value = fmt.tprint(value, "</ul></li>", sep="")
				}
			}			
			value = fmt.tprint(value, "</ul></div></details>", sep="")
			append(&toc, value)
			continue
		}
		if t.level > p.toc.max_level {
			continue
		}

		// next valid level
		next_level = p.toc.titles[ind+1].level
		if next_level > p.toc.max_level {
			for j in ind+1..<len(p.toc.titles) {
				next_level = p.toc.titles[j].level
				if next_level > p.toc.max_level {
					continue
				}
				break
			}
			
			if ind+1 == len(p.toc.titles)-1 {
				next_level = t.level
			}
		}
		
		// Heuristic verification
		if next_level < highest_level {
			next_level = highest_level
		}

		if next_level == t.level {
			value = fmt.tprint("<li><a href=\"", t.href,"\">", t.value, "</a></li>", sep="")
		} else if next_level > t.level {
			value = fmt.tprint("<li><a href=\"", t.href,"\">", t.value, "</a><ul>", sep="")
		} else {
			value = fmt.tprint("<li><a href=\"", t.href,"\">", t.value, "</a></li>", sep="")
			for j in 0..<t.level - next_level {
				value = fmt.tprint(value, "</ul></li>", sep="")
			}
		}
		append(&toc, value)
	}
	// Add toc at the proper place
	inject_at(&p.content, p.toc.line_start, ..toc[:])
}

// Create a proper href and a tag for referencing titles inside a blog post.
parse_blog_title_to_create_href_id_and_tag :: proc(title: string, post_name: string) -> (string, string, string) {
	sane_title := html_sanitize_link(s=title)
	id := strings.to_snake_case(sane_title)
	href := fmt.tprint(post_name, "#", id, sep="")
	href = fmt.tprint(MAIN_URL, "blog", href, sep="/")
	return href, id, fmt.tprint(
		"<a class=\"break-words\" href=\"",
		href, 
		"\" aria-hidden=\"true\" tabindex=\"-1\"><span class=\"content-header-link\"><svg class=\"h-5 linkicon w-5\" fill=\"currentColor\" viewBox=\"0 0 20 20\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M12.232 4.232a2.5 2.5 0 0 1 3.536 3.536l-1.225 1.224a.75.75 0 0 0 1.061 1.06l1.224-1.224a4 4 0 0 0-5.656-5.656l-3 3a4 4 0 0 0 .225 5.865.75.75 0 0 0 .977-1.138 2.5 2.5 0 0 1-.142-3.667l3-3Z\"></path><path d=\"M11.603 7.963a.75.75 0 0 0-.977 1.138 2.5 2.5 0 0 1 .142 3.667l-3 3a2.5 2.5 0 0 1-3.536-3.536l1.225-1.224a.75.75 0 0 0-1.061-1.06l-1.224 1.224a4 4 0 1 0 5.656 5.656l3-3a4 4 0 0 0-.225-5.865Z\"></path></svg></span></a>", 
		sep=""
	)
}