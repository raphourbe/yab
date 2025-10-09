---
title: "Designing a no dependency blog generator with Odin"
date: "2025-10-06"
lastmod: "2025-10-06"
tags: ["tailwind", "odin", "blog"]
draft: false
summary: "Rebuilding the Tailwind Nextjs Starter Blog in Odin, to have something faster and lighter."
---
## Context
I have been using the [Tailwind Nextjs Starter Blog](https://github.com/timlrx/tailwind-nextjs-starter-blog) as my blog generator for the past few years. However, when I tried to update it at some point to the new version of next.js (from v12 to v13), it failed miserably thanks to some new library the creator decided to use and that was not working on Windows.

Since, I decided to toy with new programing languages and ended up focusing my attention on [Odin](https://odin-lang.org/). I decided it could be a good toy project to build my own blog generator, with no dependencies except what the language offers. It would allow me to discover the language and get rid of the 350mo *node_modules* folder totally unescessary for a simple blog starter (and maybe with some npm worms in it).

As a result, I have rebuilt a good part of the Tailwind Nextjs Starter Blog, excluding some not really useful features for me, like the newsletter subscription, etc.

The blog you are reading now is entirely built with my blog generator. The full source code of the blog is available on my github [here](https://github.com/raphourbe/blog), and the source code for the blog generator writen in Odin is also on my github under the [yab](https://github.com/raphourbe/yab) nickname for: Yet, Another Blogger.

<TOC heading={3} />

## How it works
### The main ideas
My main ideas for this blog generator were: 

- To keep the idea of an easy tailwind blog
- To have a super fast building time
- Parse .md files where I could include some html into
- To be super small with no dependencies
- Can be deployed instantly
- Good ol' html

### The application
My code is quite small (around 2000 loc). The whole project is less than 3mo and it does not requires you to have anything else than Odin installed. The code compiles and executes in less than 2sec for me and I did not even add some multi-threading (this is something I want to implement in the future).

The mechanism is as simple as it can be: the app parses .md files and then copies them into html templates (where I created some special tags inspired from Jinja2). In the end, it generates a folder with the website, no backend, no SPA, only html files (no javascript).

As mentioned, the application can directly integrate some html code from your .md files, as long as you put the html code inside two `&lt;html&gt;&lt;/html&gt;` tags.

### Blog generation
The app will read and will use files inside the `blog_source_files` folder, where are gathered:

- all the static files that will be needed for the blog (images, css) in the `static` folder.
- all the written posts in the .md format inside the `posts` folder.
- all the html templates at the root of the folder.

It then deletes and generates completely a folder (if it exists) named `blog_generated_files` with a copy and paste of the `static` folder, and the newly created .html files. For each post, a folder with the name of the post is created and an index.html file is created inside so the url are beautiful, with no *.html* at the end, like the url of this post. 

After generating it with `odin run .` you should have something like that:

```
.
└── src/
    ├── blog_source_files/
    │   ├── static/
    │   │   ├── your images.jpg etc
    │   │   └── ...
    │   ├── posts/
    │   │   ├── your-post-1.md
    │   │   ├── your-post-2.md
    │   │   └── ...
    │   ├── template1.html
    │   ├── template2.html
    │   ├── ...
    │   └── out.css (the only css file)
    ├── blog_generated_files/
    │   ├── blog/
    │   │   ├── your-post-1/
    │   │   │   └── index.html
    │   │   ├── your-post-2/
    │   │   │   └── index.html
    │   │   ├── ...
    │   │   └── index.html
    │   ├── static/
    │   │   ├── your images.jpg etc
    │   │   └── ...
    │   ├── tags/
    │   │   ├── tag1.html
    │   │   └── ...
    │   ├── about
    │   │   └── index.html	
    │   └── index.html
    ├── main.odin
    ├── html.odin
    ├── parser.odin
	├── utils.odin
    └── file_management.odin
```

The content of `blog_generated_files` can be uploaded on any webserver and it should works properly.

### No dependencies you said?...
There is, I must admit, one true dependency and a fake one. The true dependency is [highlightjs](https://highlightjs.org/) for creating better code blocks. It is used with a cdn directly inside the template page for blog post.

The fake dependency is [Tailwind css](https://tailwindcss.com/). I used it to generate the css file, but now that it is done, I don't need it anymore. So it won't affect the app (unless I tweak the css, see the css part below for more details).

I also on this blog added (giscus)[https://giscus.app/], although it is not inserted in the templates in the (YAB repo)[https://github.com/raphourbe/yab]. This is a decision than someone can make on its own.

## The things you should know if you use this blog generator
### The three forbidden characters
While writing my minimalist markdown parser, I had to take into account that it would end up on a web page. Some characters have to be encoded in a specific way to be read by the browser. Here is the list of [HTML Special Characters](https://www.html.am/reference/html-special-characters.cfm).

This was not a big problem except for some characters which are: &lt; and &gt;. These are read by your browser and interpreted as html tags... So inside your markdown you should write them as if you were writing them inside an html file. So `& lt;` and `& gt;` without the spaces. There is also the ampersand &amp; that needs to be written `& amp;`. It is due to the way I wrote my parser.

### The css
The css of my template is based on tailwind. To create the css file, I have used the [tailwind standalone executable file](https://github.com/tailwindlabs/tailwindcss/releases/latest). So if you tweak the html template that I have used with some css classes I did not use, it will not render for you. You would have to adjust the css file in the source.

To do so, you can either add directly tailwind from a cdn, or you can build your own css file like me. If you want to build it, please note that you should put all the html template files that you are using to generate the blog inside the same folder as the tailwind standalone and execute it with `.\tailwind.exe -i .\src\input.css -o .\src\out.css --watch` (if you are on windows for example).

### The footer and the logo
#### Footer
I did not bother to create a template for the footer of my blog. Since I just have 5 main template pages, I just copy-pasted it in the required pages instead of bothering writing the code. So if you want to change the footer, you will have to tweak it in:

- template_about.html
- template_blog_index.html
- template_index.html
- template_post.html
- template_tags_index.html

#### Logo
The logo (here RPHL /dev) on the top left is directly added into the five templates listed above in the &lt;svg&gt; tag, and not in a separated file and using an &lt;img /&gt;. The reason is that you cannot use `class` inside of it otherwise. Hence, no logo that changes color if you use a dark ui or a light ui.

### The blog posts
The blog posts should be placed inside the `/blog_source_files/posts` folder. It should be `.md` files only in this folder and they should follow this template: the first 9 lines are property lines inside "---". The number is fixed and they are hard coded in my source code. You should always use them as such otherwise you need to change the source code yourself.

For the moment, your .md file should always start as in this example:

```
---
title: "An approach to pdf generation with directus."
date: "2023-10-12"
lastmod: "2023-10-12"
tags: ["directus", "pdf", "puppeteer"]
draft: false
summary: "Let's create a pdf generator using an endpoint extension."
---
Your blog content
```

Also, please be aware that it is markdown parsed into html. If you don't write proper markdown, like not jumping a line between a paragraph and a #title it might end up rendering poorly...

#### Adding more metadata properties
If you want to add some properties, you need to:

- modify the `parse_post_metadata` function in the `parser.odin` file;
- modify the `Post` struct in the `main.odin` file so it gets the new property you added.
- modify accordingly the html template with tags like `{%my_new_property%}`.
- modify the functions in `html.odin`: look for the `parse_and_replace_inline` functions. They are used to update the tags `{%my_new_property%}` as such: `modified_line, _ = parse_and_replace_inline(l=modified_line, old="{%title%}", new=p.title)`

#### No nested blog posts (yet?)
At this time there is no nested blog posts. Meaning that you cannot create let's say a series of blog posts and gather them under a subfolder that would in your browser looks something like: https://something.com/blog/series-of-blog/part1

#### No slug
As explained earlier, the file name is used to create the URL. There is no real parser to create a proper slug. So be aware that how you name your .md file will affect the url.

### Table of content
You can add a table of content anywhere in your post, like the one in this very post. To do so you just need to add: `&lt;TOC heading={3} /&gt;`. The number for the heading corresponds to the level of title H tags you want to be included in the table. In the example, the `h3` tags will be registered.

### Static files
There is a `static` folder to add all your static files. Please note that you can either reference them from your .md with full url, since you can know it. Or you can use relative path. Be aware that if you do so you should use `../../static/file.jpg`. Indeed, since `/blog_source_files/posts/my-post.md` will be transformed into `blog_generated_files/blog/my-post/index.html` the static folder will be two slashes away `../../static` and not just one. `../static/`.

### The global variables
At the very beginning of the `main.odin` file, I have created global variables like `MAIN_URL` or `YOUR_NAME` that are used for configuration purpose. You have to adapt them to your situation of course.

### Adding html directly
You can add html directly in your markdown and it will be rendered as html. This code writen directly in the .md file:

```
&lt;html&gt;
&lt;div class="mb-4 rounded-lg bg-orange-100 px-4 pt-4 pb-2 text-orange-700 dark:bg-orange-200 dark:text-orange-800"&gt;
  &lt;p class="m-0 pb-0 text-lg font-medium"&gt;Information&lt;/p&gt;
  &lt;p class="m-0 pt-0 text-lg"&gt;
    This tutorial will not get you a perfect blog generator.
  &lt;/p&gt;
&lt;/div&gt;
&lt;/html&gt;
```

Gives you:

<html>
<div class="mb-4 rounded-lg bg-orange-100 px-4 pt-4 pb-2 text-orange-700 dark:bg-orange-200 dark:text-orange-800">
  <p class="m-0 pb-0 text-lg font-medium">Information</p>
  <p class="m-0 pt-0 text-lg">
    This tutorial will not get you a perfect blog generator.
  </p>
</div>
</html>

So you can embedded YouTube video easily :)

<html>
<iframe width="560" height="315" src="https://www.youtube.com/embed/nVa9mgRcVPs?si=eKibEibdseaRNAqT" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
</html>

## What's next?
I have two things I want to do next with this project.

1. Adding a way to instantly upload the `blog_generated_files` folder on a webserver with almost no configuration.
2. Multi-threading for the file generation, just for learning how to do it. It is not really useful since it's already super fast... but why not being even faster? 
3. Maybe add some javascript to make a switch for the light/dark theme that is already implemented in the css part of the blog.

For the 1, I would like to find a way to use an sftp connection to just recrete the blog folder on the web server at each update. Like the good old feeling of drag and dropping your html file with FileZilla in an unsecured FTP connection. However, I have not find a way yet. Please contact me if you know how to do it directly in Odin.