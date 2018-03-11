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
	       -l <language>    Wiki language code (default: en)
	                         See https://en.wikipedia.org/wiki/List_of_Wikipedias
	       -z <project>     Wiki project (default: wikipedia)
	                         See https://en.wikipedia.org/wiki/Wikipedia:Wikimedia_sister_projects
	       -m <#>           API maxlag value (default: 5)
	                         See https://www.mediawiki.org/wiki/API:Etiquette#Use_maxlag_parameter
	       -y               Print debugging to stderr (show URLs sent to API)
	       -V               Version and copyright
	       -h               Help with examples
		
	
	Examples:

	 Backlinks:
	   for a User: showing all link types ("ntf")
	     wikiget -b "User:Jimbo Wales"
	   for a User: showing normal and transcluded links
	     wikiget -b "User:Jimbo Wales" -t nt
	   for a Template: showing transcluded links
	     wikiget -b "Template:Gutenberg author" -t t
	   for a File: showing file links
	     wikiget -b "File:Justforyoucritter.jpg" -t f
	   for article "Paris (Idaho)" on the French Wiki
	     wikiget -b "Paris (Idaho)" -l fr
	
	 User contributions:
	   show all edits from 9/10-9/12 on 2001
	     wikiget -u "User:Jimbo Wales" -s 20010910 -e 20010912
	   show all edits during the 24hrs of 9/11
	     wikiget -u "User:Jimbo Wales" -s 20010911 -e 20010911
	   articles only
	     wikiget -u "User:Jimbo Wales" -s 20010911 -e 20010930 -n 0
	   talk pages only
	     wikiget -u "User:Jimbo Wales" -s 20010911 -e 20010930 -n 1
	   talk and articles only
	     wikiget -u "User:Jimbo Wales" -s 20010911 -e 20010930 -n "0|1"
	
	   -n codes: https://www.mediawiki.org/wiki/Extension_default_namespaces
	
	 Category list:
	   pages in a category
	     wikiget -c "Category:1900 births"
	   subcats in a category
	     wikiget -c "Category:Dead people" -q s
	   subcats and pages in a category
	     wikiget -c "Category:Dead people" -q sp
	
	 Search-result list:
	   article titles containing a search
	     wikiget -a "Jethro Tull" -g title
	   first 50 articles containing a search
	     wikiget -a John -i 50
	   include snippet of text containing the search string
	     wikiget -a John -i 50 -d
	   search talk and articles only
	     wikiget -a "Barleycorn" -n "0|1"
	   regex search, include debug output
	     wikiget -a "insource:/ia[^.]*[.]us[.]/" -y
	   subpages of User:GreenC
	     wikiget -a "user: subpageof:GreenC"
	
	   search docs: https://www.mediawiki.org/wiki/Help:CirrusSearch
	   -n codes: https://www.mediawiki.org/wiki/Extension_default_namespaces
	
	 External link list:
	   list articles containing a URL with this domain
	     wikiget -x "news.yahoo.com"
	
	 Recent changes:
	   recent changes in last 30 days tagged with this ID
	     wikiget -r -k "OAuth CID: 678"
	
	 Print wiki text:
	   wiki text of article "Paris" on the English Wiki
	     wikiget -w "Paris"
	   plain text of article "China" on the French Wiki
	     wikiget -w "China" -p -l fr
	   wiki text of article on Wikinews
	     wikiget -w "Healthy cloned monkeys born in Shanghai" -z wikinews
	
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

