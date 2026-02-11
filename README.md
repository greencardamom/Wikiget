Wikiget
===================
Wikiget is a Unix command-line tool to retrieve lists of article titles from Wikipedia, search Wikipedia, edit Wikipedia and more.

Features:

* A list of target article titles is often needed for bot makers. For example all articles in a category, articles that use a 
template (backlinks), or articles edited by a username (user contributions). Wget provides a simple front-end to common API requests.

* Search Wikipedia from the command-line with the option for regex and snippits output.

* Editing Wikipedia couldn't be easier with the -E option. See EDITSETUP for authentication.

Wikiget options and examples:

	Wikiget - command-line access to some Wikimedia API functions
	
	Usage:
	
	 Backlinks:
	       -b <name>        Backlinks for article, template, userpage, etc..
	         -t <types>     (option) 1-3 letter string of types of backlinks:
	                         n(ormal)t(ranscluded)f(ile). Default: "ntf".
	                         See -h for more info 
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace(s)
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 Forward-links:
	       -F <name>        Forward-links for article, template, userpage, etc..
	
	 Redirects:
	       -B <name>        Redirects for article, template, userpage, etc..
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace(s)
	                         Only list redirects in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 User contributions:
	       -u <username>    Username without User: prefix
	         -s <starttime> Start time in YMD format (-s 20150101). Required with -u
	         -e <endtime>   End time in YMD format (-e 20151231). If same as -s,
	                         does 24hr range. Required with -u
	         -i <regex>     (option) Edit comment must include regex match
	         -j <regex>     (option) Edit comment must exclude regex match
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 Recent changes:
	       -r               Recent changes (past 30 days) aka Special:RecentChanges
	                         Either -o or -t required
	         -o <username>  Only list changes made by this user
	         -k <tag>       Only list changes tagged with this tag
	         -i <regex>     (option) Edit comment must include regex match
	         -j <regex>     (option) Edit comment must exclude regex match
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
	       -x <domain name> List articles containing domain name (Special:Linksearch)
	                        Works with domain-name only. To search for a full URI use
	                          regex. eg. -a "insource:/http:\/\/gq.com\/home.htm/"
	                        To include subdomains use wildcards: "-x *.domain.com"
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 Print wiki text:
	       -w <article>     Print wiki text of article
	         -p             (option) Plain-text version (strip wiki markup)
	         -f             (option) Don't follow redirects (print redirect page)
	
	 All pages:
	       -A               Print a list of page titles on the wiki (possibly very large)
	         -t <# type>    1=All, 2=Skip redirects, 3=Only redirects. Default: 2
	         -k <#>         Number of pages to return. 0 is all. Default: 10
	         -n <namespace> (option) Pipe-separated numeric value(s) of namespace
	                         Only list pages in this namespace. Default: 0
	                         See -h for NS codes and examples
	
	 Edit page:
	       -E <title>       Edit a page with this title. Requires -S and -P
	         -S <summary>   Edit summary
	         -P <filename>  Page content filename. If "STDIN" read from stdin
	                         See EDITSETUP for authentication configuration
	
	       -R <page>        Move from page name. Requires -T
	         -T <page>      Move to page name
	
	       -G <page>        Purge page
	       -I               Show OAuth userinfo
	
	 Global options:
	       -l <language>    Wiki language code (default: en)
	                         See https://en.wikipedia.org/wiki/List_of_Wikipedias
	       -z <project>     Wiki project (default: wikipedia)
	                         https://en.wikipedia.org/wiki/Wikipedia:Wikimedia_sister_projects
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
	     wikiget -u "Jimbo Wales" -s 20010910 -e 20010912
	   show all edits during the 24hrs of 9/11
	     wikiget -u "Jimbo Wales" -s 20010911 -e 20010911
	   show all edits when the edit-comment starts with 'A' 
	     wikiget -u "Jimbo Wales" -s 20010911 -e 20010911 -i "^A"
	   articles only
	     wikiget -u "Jimbo Wales" -s 20010911 -e 20010930 -n 0
	   talk pages only
	     wikiget -u "Jimbo Wales" -s 20010911 -e 20010930 -n 1
	   talk and articles only
	     wikiget -u "Jimbo Wales" -s 20010911 -e 20010930 -n "0|1"
	
	   -n codes: https://www.mediawiki.org/wiki/Extension_default_namespaces
	
	 Recent changes:
	   show edits for prior 30 days by IABot made under someone else's name
	   (ie. OAuth) with an edit summary including this target word
	     wikiget -k "OAuth CID: 1804" -r -i "Bluelinking"
	
	   CID list: https://en.wikipedia.org/wiki/Special:Tags
	
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
	   list articles in NS 1 containing a URL with this domain
	     wikiget -x "*.yahoo.com" -n 1
	
	 All pages:
	   all page titles excluding redirects w/debug tracking progress
	     wikiget -A -t 2 -y > list.txt
	   first 50 page titles including redirects
	     wikiget -A -t 1 -k 50 > list.txt
	
	 Print wiki text:
	   wiki text of article "Paris" on the English Wiki
	     wikiget -w "Paris"
	   plain text of article "China" on the French Wiki
	     wikiget -w "China" -p -l fr
	   wiki text of article on Wikinews
	     wikiget -w "Healthy cloned monkeys born in Shanghai" -z wikinews
	
	 Edit page:
	   Edit "Paris" by uploading new content from the local file paris.ws
	     wikiget -E "Paris" -S "Fix spelling" -P "/home/paris.ws"
	   Input via stdin
	     cat /home/paris.ws | wikiget -E "Paris" -S "Fix spelling" -P STDIN
	

Installation
=============
Download wikiget.awk

Set executable: chmod 750 wikiget.awk

Optionally create a symlink: ln -s wikiget.awk wikiget

Change hashbang (first line) to location of GNU Awk 4+  - use 'which gawk' to see where it is on your system.

Change the agent "contact" line to your Wikipedia Username (near the top of the program). 

Create a text file anywhere containing a single line with your email address; to be used by the agent string. 

Add the text file path location to the "emailfp" configuration option.

It's vital to have correct contact information per WMF bot policy. WMF API calls may fail with User Agent information that is non-compliant.

Requires one of the following to be in the path: wget, curl or lynx (use 'which wget' to see where it is on your system)

Usage
==========
The advantage of working in Unix is access to other tools. Some examples follow.

A search-replace bot:

	wikiget -w "Wikipedia" | sed 's/Wikipedia/Wikipodium/g' | wikiget -E "Wikipedia" -S "Change to Wikipodium" -P STDIN

Expand: download the wikisource (-w) for article "Wikipedia". Search/replace (sed) all occurances of 'Wikipedia' with 'Wikipodium'. Upload result (-E) with (-S) edit summary taking input from STDIN. This can be added to a for-loop that operates on a list of articles. 

This unix pipe method is for light and quick work, for a production bot a script would invoke wikiget with -P <filename> and check its output for an error ie. a result other than "Success" or "No change" then make a retry. In about 5% of uploads the WMF servers fail and a retry is needed, up to 3 are usually enough. Retries are not built-in to Wikiget as it depends on the calling application how to handle error results.

To find the intersection of two categories (articles that exist in both), download the category lists using the -c option, then use grep to find the intersection:

	grep -xF -f list1 list2

Or to find the names unique to list2

	grep -vxF -f list1 list2

Credits
==================
by User:GreenC (en.wikipedia.org)

MIT License

Wikiget is part of the BotWikiAwk framework of tools and libraries for building and running bots on Wikipedia

https://github.com/greencardamom/BotWikiAwk

