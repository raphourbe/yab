# Context
I have been using the [Tailwind Nextjs Starter Blog](https://github.com/timlrx/tailwind-nextjs-starter-blog) as my blog generator for the past few years and I loved it. 
However, when I tried to update it at some point to the new version of next.js (from v12 to v13), it failed miserably thanks to some new library the creator decided to use and that was not working on Windows.

Since, I decided to toy with new programing languages and ended up focusing my attention on [Odin](https://odin-lang.org/).
I decided it could be a good toy project to build my own blog generator, with no dependencies except what the language offers. 
It would allow me to discover the language and get rid of the 350mo *node_modules* folder totally unescessary for a simple blog starter (and maybe with some npm worms in it).

As a result, I have rebuilt a good part of the Tailwind Nextjs Starter Blog, excluding some not really useful features for me, like the newsletter subscription, etc.

The blog you are reading now is entirely built with my blog generator. The full source code of the blog is available on my github [here](https://github.com/raphourbe/blog), and the source code for the blog generator writen in Odin is this repo: Yet, Another Blogger.

# How it works
## The main ideas
My main ideas for this blog generator were: 

- To keep the idea of an easy tailwind blog
- To have a super fast building time
- Parse .md files where I could include some html into
- To be super small with no dependencies
- Can be deployed instantly
- Good ol' html

## The application
My code is quite small (around 2000 loc). The whole project is less than 3mo and it does not requires you to have anything else than Odin installed. 
The code compiles and executes in less than 2sec for me and I did not even add some multi-threading (this is something I want to implement in the future to try).

The mechanism is as simple as it can be: the app parses .md files and then copies them into html templates (where I created some special tags inspired from Jinja2). 
In the end, it generates a folder with the website, no backend, no SPA, only html files (no javascript ~ almost).

As mentioned, the application can directly integrate some html code from your .md files, as long as you put the html code inside two `<html></html>` tags.

## Blog generation
The app will read and will use files inside the `blog_source_files` folder, where are gathered:

- all the static files that will be needed for the blog (images, css) in the `static` folder.
- all the written posts in the .md format inside the `posts` folder.
- all the html templates at the root of the folder.

It then deletes and generates completely a folder (if it exists) named `blog_generated_files` with a copy and paste of the `static` folder, and the newly created .html files.
For each post, a folder with the name of the post is created and an index.html file is created inside so the url are beautiful, with no *.html* at the end, like the url of this post. 

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

## No dependencies you said?...
There is, I must admit, one true dependency and a fake one. The true dependency is [highlightjs](https://highlightjs.org/) for creating better code blocks. It is used with a cdn directly inside the template page for blog post.

The fake dependency is [Tailwind css](https://tailwindcss.com/). I used it to generate the css file, but now that it is done, I don't need it anymore. So it won't affect the app (unless I tweak the css, see the css part below for more details).

# The things you should know if you use this blog generator
Everything is writen on [my blog](https://rphl.dev/blog/designing-a-no-dependency-blog-generator-with-odin).

Although, to launch the generator, you should open the *main.odin* file and modify the global variables to adapt to your situation, then run `odin run .`. If you have never used Odin, you should install it following the [doc](https://odin-lang.org/docs/install).
