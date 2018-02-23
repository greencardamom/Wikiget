Wikiget
===================
Wikiget is a Unix command-line tool to retrieve lists of article titles from Wikipedia.

When working with AWB or bots on Wikipedia, a list of target article titles is often needed. For example all articles in a category, articles that use a 
template (backlinks), or articles edited by a username (user contributions). Wget provides a simple front-end to common API requests.


	Wikiget - command-line access to Wikimedia API functions

	Usage:

	 Backlinks:
	       -b <name>        Backlinks for article, template, userpage, etc..
	         -t <types>     (option) 1-3 letter string of types of backlinks:
	                         n(ormal)t(ranscluded)f(ile). Default: "ntf".
	                         See -h for more info 
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace(s)
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 User contributions:
	       -u <username>    User contributions
	         -s <starttime> Start time in YMD format (-s 20150101). Required with -u
	         -e <endtime>   End time in YMD format (-e 20151231). If same as -s,
	                         does 24hr range. Required with -u
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 Category list:
	       -c <category>    List articles in a category
	         -q <types>     (option) 1-3 letter string of types of links: 
	                         p(age)s(ubcat)f(ile). Default: "p"
	
	 Search-result list:
	       -a <search>      List of articles containing a search string
	                         See docs https://www.mediawiki.org/wiki/Help:CirrusSearch
	         -d             (option) Include search-result snippet in output (def: title)
	         -g <target>    (option) Search in "title" or "text" (def: "text")
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	         -i <maxsize>   (option) Max number of results to return. Default: 10000
	                         10k max limit imposed by search engine
	         -j             (option) Show number of search results
	
	 External links list:
	       -x <URL>         List articles containing external link (Special:Linksearch)
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 Recent changes:
	       -r               Recent changes (past 30 days) aka Special:RecentChanges
	                         Either -o or -t required
	         -o <username>  Only list changes made by this user
	         -k <tag>       Only list changes tagged with this tag
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 Print wiki text:
	       -w <article>     Print wiki text of article
	         -p             (option) Plain-text version (strip wiki markup)
	         -f             (option) Don't follow redirects (print redirect page)
	
	 Global options:
	       -l <language>    Wikipedia language code (default: en)
	                         See https://en.wikipedia.org/wiki/List_of_Wikipedias
	       -m <#>           API maxlag value (default: 5)
	                         See https://www.mediawiki.org/wiki/API:Etiquette#Use_maxlag_parameter
	       -y               Print debugging to stderr (show URLs sent to API)
	       -V               Version and copyright
	       -h               Help with examples
	

Installation
=============
Download wikiget.awk

Set executable: chmod 750 wikiget.awk

Optionally create a symlink: ln -s wikiget.awk wikiget

Change the first line (default: /usr/bin/awk) to location of GNU Awk 4+ (use 'which gawk' to see where it is on your system)

Change the "Contact" line to your Wikipedia Username (optionally or leave blank)

Requires one of the following to be in the path: wget, curl or lynx (use 'which wget' to see where it is on your system)

Usage
==========
The advantage of working in Unix is access to other tools. For example to find the intersection of two categories (the articles that exist in both), download the two category lists using the -c option, then use grep to find the intersection:

	grep -xF -f list1 list2

Or to find the names unique to list2

	grep -vxF -f list1 list2

For other methods see [this page](http://mywiki.wooledge.org/BashFAQ/036)

Credits
==================
by User:GreenC (en.wikipedia.org)

First version: November 2016

MIT License

Want to use MediaWiki API with Awk? Check out 'MediaWiki Awk API Library'

https://github.com/greencardamom/MediaWikiAwkAPI

