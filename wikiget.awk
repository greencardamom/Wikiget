#!/usr/bin/awk -bE

#
# Wikiget - command-line access to Wikimedia API read/write functions
#           https://github.com/greencardamom/Wikiget
#

# The MIT License (MIT)
#
# Copyright (c) 2016-2026 by User:GreenC (at en.wikipedia.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy      
# of this software and associated documentation files (the "Software"), to deal   
# in the Software without restriction, including without limitation the rights                
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell    
# copies of the Software, and to permit persons to whom the Software is              
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#                              Code Table of Contents
#
#  [[ _______ Global system vars ____________________________________________ ]]
#  [[ _______ Command line parsing and argument processing __________________ ]]
#  [[ _______ Setup _________________________________________________________ ]]
#  [[ _______ Core read-only functions ______________________________________ ]]
#          ___ Categories (-c)         
#          ___ External links list (-x) 
#          ___ Recent changes (-r)     
#          ___ User Contributions (-u) 
#          ___ Forward links (-F) 
#          ___ Backlinks (-b)
#          ___ Print wiki text (-w)
#          ___ Search list (-a) 
#  [[ _______ Utilities ______________________________________________________ ]]
#  [[ _______ Library ________________________________________________________ ]]
#  [[ _______ JSON ___________________________________________________________ ]]
#  [[ _______ Edit ___________________________________________________________ ]]


# [[ ________ Global system vars _____________________________________________ ]]

BEGIN { # Program cfg

    _defaults = "contact   = User:MY_NAME \
                 emailfp   = /path/to/secrets/myname.email \
                 program   = Wikiget \
                 version   = 1.51 \
                 copyright = 2016-2026 \
                 maxlag    = 10 \
                 lang      = en \
                 project   = wikipedia"

    asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")

    # Create a file containing your email address (a single line) and link that file in 'emailfp' above
    if(!exists2(G["emailfp"])) {
      stdErr("Unable to find email file (" G["emailfp"] "). Create a file anywhere on your system containing your email address (a single line). Link that /path/to/filename into 'emailfp' at the top of wikiget.awk - required for WMF API authentication.")
      exit
    }

    # Agent string format non-compliance could result in 429 (too many requests) rejections by WMF API
    G["agent"] = G["program"] "-" G["version"] "-" G["copyright"] " (" G["contact"] "; mailto:" strip(readfile(G["emailfp"])) ")"

    # wget options (GET)
    G["wget_opts"]=" --user-agent=\"" G["agent"] "\" --referer=\"https://en.wikipedia.org/wiki/Main_Page\" --no-cookies --ignore-length --no-check-certificate --timeout=120 --tries=1 --content-on-error"
                                 
    setup("wget curl lynx")                                     # Use one of wget, curl or lynx - searches PATH in this order
                                                                #  They do the same, need at least one available in PATH
                                                                #  For edit (-E) wget is required.
    Optind = Opterr = 1                                         

    # randomnumber() seed
    srand(systime() + PROCINFO["pid"])    
    _cliff_seed = rand()
    if (_cliff_seed == 0) _cliff_seed = 0.1 # Safety catch so log() doesn't fail

    # Optional OAuth consumer keys. See EDITSETUP for more info. 
    # Create the files below with secure permissions to store your secrets:

    #   mkdir /home/user/.config/wikiget
    #   mkdir /home/user/.config/wikiget/secrets
    #   chmod 700 /home/user/.config/wikiget/secrets
    #   chmod 600 mybot.consumerkey
    #   chmod 600 mybot.consumersecret
    #   chmod 600 mybot.accesskey
    #   chmod 600 mybot.accesssecret

    G["oauth_read"] = 0 # OAuth for read requests (1 = enabled, 0 = disabled)
    G["consumerKey"]    = strip(readfile("/home/user/.config/wikiget/secrets/mybot.consumerkey"))
    G["consumerSecret"] = strip(readfile("/home/user/.config/wikiget/secrets/mybot.consumersecret"))
    G["accessKey"]      = strip(readfile("/home/user/.config/wikiget/secrets/mybot.accesskey"))
    G["accessSecret"]   = strip(readfile("/home/user/.config/wikiget/secrets/mybot.accesssecret"))

    # Toolforge API Private Proxy 
    G["tfproxy"] = 0    # Route API requests through a private proxy at Toolforge (1 = enabled, 0 = disabled)
    G["tfproxy_url"]      = strip(readfile("/home/user/.config/wikiget/secrets/tfproxy.url"))
    G["tfproxy_pass"]     = strip(readfile("/home/user/.config/wikiget/secrets/tfproxy.password"))
    G["tfproxy_header"]   = strip(readfile("/home/user/.config/wikiget/secrets/tfproxy.header"))

}

BEGIN { # Program run

    parsecommandline()

}

# [[ ________ Command line parsing and argument processing ___________________ ]]

#
# parsecommandline() - parse command-line
#
function parsecommandline(c,opts,Arguments) {

    while ((c = getopt(ARGC, ARGV, "XOIyrhVfjpdo:k:a:g:i:s:e:u:m:b:l:n:w:c:t:q:x:z:F:E:S:P:R:T:AB:G:N:U:Y:")) != -1) {
        opts++
        if (c == "h") {
            usage()
            usage_extended()
            exit
        }

        if (c == "b") {                               #  -b <entity>     Backlinks for entity ( -b "Template:Project Gutenberg" )
            Arguments["main"] = verifyval(Optarg)
            Arguments["main_c"] = "b"
        }
        if (c == "t")                                 #  -t <types>      Types of backlinks ( -t "ntf" )
            Arguments["bltypes"] = verifyval(Optarg)

        if (c == "F") {                               #  -F <entity>     Forward-links for entity ( -F "Example" )
            Arguments["main"] = verifyval(Optarg)
            Arguments["main_c"] = "F"
        }

        if (c == "B") {                               #  -B <entity>     Redirects for entity ( -B "Example" )
            Arguments["main"] = verifyval(Optarg)
            Arguments["main_c"] = "B"
        }

        if (c == "c") {                               #  -b <entity>     List articles in a category ( -c "Category:1900 births" )
            Arguments["main"] = verifyval(Optarg)
            Arguments["main_c"] = "c"
        }
        if (c == "q")                                 #  -q <types>      Types of links in a category ( -t "psf" )
            Arguments["cattypes"] = verifyval(Optarg)

        if (c == "a") {                               #  -a <search>     List articles in search results ( -a "John Smith" )
            Arguments["main"] = verifyval(Optarg)
            Arguments["main_c"] = "a"
        }
        if (c == "d")                                 #  -d              Include search snippet in results (optional with -a )
            Arguments["snippet"] = "true"
        if (c == "j")                                 #  -j              Show number of search results (optional with -a)
            Arguments["numsearch"] = "true"
        if (c == "i")                                 #  -i <max>        Max number of search results (optional with -a)
            Arguments["maxsearch"] = verifyval(Optarg)
        if (c == "g")                                 #  -g <type>       Target search (optional with -a)
            Arguments["searchtarget"] = verifyval(Optarg)

        if (c == "u") {                               #  -u <username>   User contributions ( -u "User:Green Cardamom")
            Arguments["main"] = verifyval(Optarg)
            Arguments["main_c"] = "u"
        }
        if (c == "s")                                 #  -s <time>       Start time for -u (required w/ -u)
            Arguments["starttime"] = verifyval(Optarg)
        if (c == "e")                                 #  -e <time>       End time for -u (required w/ -u)
            Arguments["endtime"] = verifyval(Optarg)
        if (c == "i")                                 #  -i <regex>      Edit comment must include this regex match
            Arguments["inccomments"] = verifyval(Optarg)
        if (c == "j")                                 #  -j <regex>      Edit comment must exclude this regex match
            Arguments["exccomments"] = verifyval(Optarg)
        
        if (c == "n")                                 #  -n <namespace>  Namespace for -u, -a and -x (option)
            Arguments["namespace"] = verifyval(Optarg)
   
        if (c == "r")                                 #  -r              Recent changes
            Arguments["main_c"] = "r"
        if (c == "o")                                 #  -o <username>   Username for recent changes
            Arguments["username"] = verifyval(Optarg)
        if (c == "k")                                 #  -k <tag>        Tag for recent changes
            Arguments["tags"] = verifyval(Optarg)
        

        if (c == "A") {                               #  -A              Dump a list of all article titles on Wikipedia (no redirects)
            Arguments["main_c"] = "A"
        }
        if (c == "t")                                 #  -t <type>       Filter redirects
            Arguments["redirtype"] = verifyval(Optarg)
        if (c == "k")                                 #  -k <#>          Number of pages to return
            Arguments["maxpages"] = verifyval(Optarg)
   
        if (c == "w") {                               #  -w <article>    Print wiki text 
            Arguments["main"] = verifyval(Optarg)
            Arguments["main_c"] = "w"
        }
        if (c == "f")                                 #  -f              Don't follow redirect (return source of redirect page)
            Arguments["followredirect"] = "false"
        if (c == "p")                                 #  -p              Plain text (strip wiki markup)
            Arguments["plaintext"] = "true"

        if (c == "x") {                               #  -x <URL>        List articles containing an external link 
            Arguments["main"] = verifyval(Optarg)
            Arguments["main_c"] = "x"
        }


        if (c == "E") {                               #  -E <title>      Edit a page with this title. Requires -S and -P
            Arguments["main_c"] = "E"
            Arguments["title"] = verifyval(Optarg)
        }
        if (c == "S")                                 #  -S <summary>    Edit summary
            Arguments["summary"] = verifyval(Optarg)
        if (c == "P")                                 #  -P <filename>   Page content filename
            Arguments["page"] = verifyval(Optarg)               
        
        if (c == "R") {                               #  -R <page>       Move from page name
            Arguments["main_c"] = "R"
            Arguments["movefrom"] = verifyval(Optarg)
        }
        if (c == "T")                                 #  -T <page>       Move to page name
            Arguments["moveto"] = verifyval(Optarg)

        if (c == "G") {                               #  -G <page>       Purge page
            Arguments["main_c"] = "G"
            Arguments["title"] = verifyval(Optarg)
        }
        if (c == "N") {                               #  -N <page>       Null edit page
            Arguments["main_c"] = "N"
            Arguments["title"] = verifyval(Optarg)
        }
        if (c == "I")                                 #  -I              User info
            Arguments["main_c"] = "I"
        if (c == "m")                                 #  -m <maxlag>     Maxlag setting when using API, default set in BEGIN{} section
            Arguments["maxlag"] = verifyval(Optarg)
        if (c == "l")                                 #  -l <lang>       Language code, default set in BEGIN{} section
            Arguments["lang"] = verifyval(Optarg)
        if (c == "z")                                 #  -z <project>    Project name, default set in BEGIN{} section
            Arguments["project"] = verifyval(Optarg)
        if (c == "U") {                               #  -U <url>        Raw API request
            Arguments["api_url"] = verifyval(Optarg)
            Arguments["main_c"] = "U"
        }
        if (c == "O")                                 #  -O              Toggle OAuth for read requests
            Arguments["toggle_oauth"] = 1
        if (c == "X")                                 #  -X              Toggle Toolforge proxy
            Arguments["toggle_tfproxy"] = 1
        if (c == "y")                                 #  -y              Show debugging info to stderr
            Arguments["debug"] = 1
        if (c == "Y") {                               #  -Y <target>     Show debugging info and route to target "stdout" or <filename>
            Arguments["debug"] = 1
            Arguments["debug_dest"] = verifyval(Optarg)
        }
        if (c == "V") {                               #  -V              Version and copyright info.
            version()
            exit
        }  
    }
    if (opts < 1) 
        usage(1)

    processarguments(Arguments)
}

#
# processarguments() - process arguments
#
function processarguments(Arguments,   c,a,i) {

    if (Arguments["toggle_oauth"]) {
        if (G["oauth_read"] == 1) G["oauth_read"] = 0
        else G["oauth_read"] = 1
    }

    if (Arguments["toggle_tfproxy"]) {
        if (G["tfproxy"] == 1) G["tfproxy"] = 0
        else G["tfproxy"] = 1
    }

    if (length(Arguments["lang"]) > 0)                                # Check options, set defaults
        G["lang"] = Arguments["lang"]
        # default set in BEGIN{}

    if (length(Arguments["project"]) > 0)
        G["project"] = Arguments["project"]
        # default set in BEGIN{}

    if (isanumber(Arguments["maxlag"])) 
        G["maxlag"] = Arguments["maxlag"]
        # default set in BEGIN{}

    if (isanumber(Arguments["maxpages"])) 
        G["maxpages"] = Arguments["maxpages"]
    else
        G["maxpages"] = 10

    if (isanumber(Arguments["maxsearch"])) 
        G["maxsearch"] = Arguments["maxsearch"]
    else
        G["maxsearch"] = 10000

    if (isanumber(Arguments["namespace"]) || Arguments["namespace"] ~ "[|]") 
        G["namespace"] = Arguments["namespace"]
    else
        G["namespace"] = "0"

    if (Arguments["followredirect"] == "false")
        G["followredirect"] = "false"
    else
        G["followredirect"] = "true"

    if (Arguments["plaintext"] == "true")
        G["plaintext"] = "true"
    else
        G["plaintext"] = "false"

    if (Arguments["snippet"] == "true")
        G["snippet"] = "true"
    else
        G["snippet"] = "false"

    if (Arguments["redirtype"] !~ /1|2|3/)
        G["redirtype"] = "2"
    else
        G["redirtype"] = Arguments["redirtype"]

    if (Arguments["numsearch"] == "true")
        G["numsearch"] = "true"
    else
        G["numsearch"] = "false"

    if (Arguments["searchtarget"] !~ /^text$|^title$/)
        G["searchtarget"] = "text"
    else
        G["searchtarget"] = Arguments["searchtarget"]

    if (length(Arguments["bltypes"]) > 0 && Arguments["main_c"] == "b") {
        if (Arguments["bltypes"] !~ /[^ntf]/) {    # ie. contains only those letters
            c = split(Arguments["bltypes"], a, "")
            while (i++ < c) 
                G["bltypes"] = G["bltypes"] a[i]
        }
        else {
            stdErr("Invalid \"-t\" value(s)")
            exit
        }
    }
    else
        G["bltypes"] = "ntf"

    if (length(Arguments["cattypes"]) > 0) {
        if (Arguments["cattypes"] !~ /[^psf]/) {    
            c = split(Arguments["cattypes"], a, "")
            while (i++ < c) 
                G["cattypes"] = G["cattypes"] a[i]
        }
        else {
            stdErr("Invalid \"-q\" value(s)")
            exit
        }
    }
    else
        G["cattypes"] = "p"

    if(! empty(Arguments["inccomments"]))
      G["inccomments"] = Arguments["inccomments"]
    if(! empty(Arguments["exccomments"]))
      G["exccomments"] = Arguments["exccomments"]

    if (Arguments["debug"]) {                                  # Enable debugging
        G["debug"] = 1
        if (!empty(Arguments["debug_dest"]))
            G["debug_dest"] = Arguments["debug_dest"]
        else
            G["debug_dest"] = "stderr"
    }

    G["apiURL"] = "https://" G["lang"] "." G["project"] ".org/w/api.php?"

  # ________________ program entry points _______________________ #

    if (Arguments["main_c"] == "E") {                          # edit page
        if (empty(Arguments["summary"]) || empty(Arguments["page"])) {
            stdErr("Missing -S and/or -P") 
            usage(1)
        }
        editPage(Arguments["title"], Arguments["summary"], Arguments["page"])
    }
    else if (Arguments["main_c"] == "I") {                     # OAuth userinfo
        userInfo()
    }
    else if (Arguments["main_c"] == "G") {                     # purge page
        if (empty(Arguments["title"])) {
            stdErr("Missing page title")
            usage(1)
        }
        purgePage(Arguments["title"])
    }
    else if (Arguments["main_c"] == "N") {                     # nulledit page
        if (empty(Arguments["title"])) {
            stdErr("Missing page title")
            usage(1)
        }
        nulleditPage(Arguments["title"])
    }
    else if (Arguments["main_c"] == "R") {                     # move page

        if (empty(Arguments["summary"])) {
          stdErr("Missing -S (reason for move)")
          usage(1)
        }
        if (empty(Arguments["moveto"]))
            usage(1)
        movePage(Arguments["movefrom"], Arguments["moveto"], Arguments["summary"])
    }
    else if (Arguments["main_c"] == "A") {
        allPages(G["redirtype"])
    }
    else if (Arguments["main_c"] == "b") {                     # backlinks
        if ( entity_exists(Arguments["main"]) ) {
            if ( ! backlinks(Arguments["main"]) )
                stdErr("No backlinks for " Arguments["main"]) 
        }
    }
    else if (Arguments["main_c"] == "F") {                     # forward-links
        forlinks(Arguments["main"])
    }
    else if (Arguments["main_c"] == "B") {                     # redirects
        redirects(Arguments["main"])
    }
    else if (Arguments["main_c"] == "c") {                     # categories
        category(Arguments["main"])
    }
    else if (Arguments["main_c"] == "x") {                     # external links
        xlinks(Arguments["main"])
    }
    else if (Arguments["main_c"] == "a") {                     # search results
        search(Arguments["main"])
    }

    else if (Arguments["main_c"] == "u") {                     # user contributions
        if (! isanumber(Arguments["starttime"]) || ! isanumber(Arguments["endtime"])) {
            stdErr("Invalid start time (-s) or end time (-e)\n")
            usage(1)
        }
        Arguments["starttime"] = Arguments["starttime"] "000000"
        Arguments["endtime"] = Arguments["endtime"] "235959"
        if (! ucontribs(Arguments["main"],Arguments["starttime"],Arguments["endtime"]) )
            stdErr("No user and/or edits found.")
    }

    else if (Arguments["main_c"] == "r") {                     # recent changes
        if ((length(Arguments["username"]) == 0 && length(Arguments["tags"]) == 0) || (length(Arguments["username"]) > 0 && length(Arguments["tags"]) > 0)) {
            stdErr("Recent changes requires either -f or -k\n")
            usage(1)
        }
        if (! rechanges(Arguments["username"],Arguments["tags"]) )
            stdErr("No recent changes found.")
    }
    
    else if (Arguments["main_c"] == "w") {                     # wiki text
        if (entity_exists(Arguments["main"]) ) {
            if (G["plaintext"] == "true")
                print wikitextplain(Arguments["main"])
            else
                print wikitext(Arguments["main"])
        }
        else {
            stdErr("Unable to find " Arguments["main"])
            exit
        }
    }
    else if (Arguments["main_c"] == "U") {                     # Raw API URL
        rawAPI(Arguments["api_url"])
    }
    else 
        usage(1)

}

#
# usage()
#
function usage(die) {
    print ""              
    print G["program"] " - command-line access to some Wikimedia API functions"
    print ""
    print "Usage:"         
    print ""
    print " Backlinks:"
    print "       -b <name>        Backlinks for article, template, userpage, etc.."
    print "         -t <types>     (option) 1-3 letter string of types of backlinks:" 
    print "                         n(ormal)t(ranscluded)f(ile). Default: \"ntf\"."
    print "                         See -h for more info "
    print "         -n <namespace> (option) Pipe-separated numeric value(s) of namespace(s)" 
    print "                         Only list pages in this namespace. Default: 0"
    print "                         See -h for NS codes and examples"
    print ""
    print " Forward-links:"
    print "       -F <name>        Forward-links for article, template, userpage, etc.."
    print ""
    print " Redirects:"
    print "       -B <name>        Redirects for article, template, userpage, etc.."
    print "         -n <namespace> (option) Pipe-separated numeric value(s) of namespace(s)" 
    print "                         Only list redirects in this namespace. Default: 0"
    print "                         See -h for NS codes and examples"
    print ""
    print " User contributions:"
    print "       -u <username>    Username without User: prefix"
    print "         -s <starttime> Start time in YMD format (-s 20150101). Required with -u"
    print "         -e <endtime>   End time in YMD format (-e 20151231). If same as -s," 
    print "                         does 24hr range. Required with -u"
    print "         -i <regex>     (option) Edit comment must include regex match"
    print "         -j <regex>     (option) Edit comment must exclude regex match"
    print "         -n <namespace> (option) Pipe-separated numeric value(s) of namespace"
    print "                         Only list pages in this namespace. Default: 0"
    print "                         See -h for NS codes and examples"
    print ""
    print " Recent changes:"
    print "       -r               Recent changes (past 30 days) aka Special:RecentChanges" 
    print "                         Either -o or -k required"
    print "         -o <username>  Only list changes made by this user"
    print "         -k <tag>       Only list changes tagged with this tag"
    print "         -i <regex>     (option) Edit comment must include regex match"
    print "         -j <regex>     (option) Edit comment must exclude regex match"
    print "         -n <namespace> (option) Pipe-separated numeric value(s) of namespace"
    print "                         Only list pages in this namespace. Default: 0"
    print "                         See -h for NS codes and examples"
    print ""
    print " Category list:"
    print "       -c <category>    List articles in a category"
    print "         -q <types>     (option) 1-3 letter string of types of links: "
    print "                         p(age)s(ubcat)f(ile). Default: \"p\""
    print ""
    print " Search-result list:"
    print "       -a <search>      List of articles containing a search string"
    print "                         See docs https://www.mediawiki.org/wiki/Help:CirrusSearch"
    print "         -d             (option) Include search-result snippet in output (def: title)"
    print "         -g <target>    (option) Search in \"title\" or \"text\" (def: \"text\")"
    print "         -n <namespace> (option) Pipe-separated numeric value(s) of namespace"
    print "                         Only list pages in this namespace. Default: 0"
    print "                         See -h for NS codes and examples"
    print "         -i <maxsize>   (option) Max number of results to return. Default: 10000"
    print "                         10k max limit imposed by search engine"
    print "         -j             (option) Show number of search results"
    print ""
    print " External links list:"
    print "       -x <domain name> List articles containing domain name (Special:Linksearch)"
    print "                        Works with domain-name only. To search for a full URI use" 
    print "                          regex. eg. -a \"insource:/http:\\/\\/gq.com\\/home.htm/\""  
    print "                        To include subdomains use wildcards: \"-x *.domain.com\""
    print "         -n <namespace> (option) Pipe-separated numeric value(s) of namespace"
    print "                         Only list pages in this namespace. Default: 0"
    print "                         See -h for NS codes and examples"
    print ""
    print " Print wiki text:"
    print "       -w <article>     Print wiki text of article"
    print "         -p             (option) Plain-text version (strip wiki markup)"
    print "         -f             (option) Don't follow redirects (print redirect page)"
    print ""
    print " All pages:"
    print "       -A               Print a list of page titles on the wiki (possibly very large)" 
    print "         -t <# type>    1=All, 2=Skip redirects, 3=Only redirects. Default: 2"
    print "         -k <#>         Number of pages to return. 0 is all. Default: 10"
    print "         -n <namespace> (option) Pipe-separated numeric value(s) of namespace"
    print "                         Only list pages in this namespace. Default: 0"
    print "                         See -h for NS codes and examples"
    print ""
    print " API request:"
    print "        -U <url>         Send a custom API query. Uses OAuth authentication, if enabled."
    print "                         Will deftly handle maxlag, retry and pause loops."
    print "                         Can be the full URL, or just the query string."
    print "                         Example: wikiget -U \"action=query&meta=siteinfo&format=json\""
    print "                         Note: URL values must be percent-encoded (e.g., %20 for spaces)."
    print ""
    print " Edit page:"
    print "       -E <title>       Edit a page with this title. Requires -S and -P"
    print "         -S <summary>   Edit summary"
    print "         -P <filename>  Page content filename. If \"STDIN\" read from stdin"
    print "                         See EDITSETUP for authentication configuration"
    print ""
    print "       -R <page>        Move from page name. Requires -T"
    print "         -T <page>      Move to page name"
    print ""
    print "       -G <page>        Purge page"
    print "       -N <page>        Null edit page (forces category/template refresh)"
    print "       -I               Show OAuth userinfo"
    print ""
    print " Global options:"
    print "       -l <language>    Wiki language code (default: " G["lang"] ")" 
    print "                         See https://en.wikipedia.org/wiki/List_of_Wikipedias"
    print "       -z <project>     Wiki project (default: " G["project"] ")"
    print "                         https://en.wikipedia.org/wiki/Wikipedia:Wikimedia_sister_projects"
    print "       -m <#>           API maxlag value (default: " G["maxlag"] ")"
    print "                         See https://www.mediawiki.org/wiki/API:Etiquette#Use_maxlag_parameter"
    print "       -O               Toggle OAuth for read requests (default: " (G["oauth_read"] == 1 ? "ON" : "OFF") ")"
    print "       -X               Toggle Toolforge Private Proxy (default: " (G["tfproxy"] == 1 ? "ON" : "OFF") ")"
    print "       -y               Print debugging to stderr (show URLs sent to API)"
    print "       -Y <target>      Print debugging to target: stderr, stdout, or a /file/path (appends)"
    print "       -V               Version and copyright"
    print "       -h               Help with examples"
    print ""
    if(die) exit
}
function usage_extended() {
    print "Examples:"
    print ""
    print " Backlinks:"
    print "   for a User: showing all link types (\"ntf\")"
    print "     wikiget -b \"User:Jimbo Wales\""
    print "   for a User: showing normal and transcluded links"
    print "     wikiget -b \"User:Jimbo Wales\" -t nt"                               
    print "   for a Template: showing transcluded links"  
    print "     wikiget -b \"Template:Gutenberg author\" -t t"
    print "   for a File: showing file links"
    print "     wikiget -b \"File:Justforyoucritter.jpg\" -t f"
    print "   for article \"Paris (Idaho)\" on the French Wiki"
    print "     wikiget -b \"Paris (Idaho)\" -l fr"
    print ""
    print " User contributions:"
    print "   show all edits from 9/10-9/12 on 2001"
    print "     wikiget -u \"Jimbo Wales\" -s 20010910 -e 20010912" 
    print "   show all edits during the 24hrs of 9/11" 
    print "     wikiget -u \"Jimbo Wales\" -s 20010911 -e 20010911"  
    print "   show all edits when the edit-comment starts with 'A' " 
    print "     wikiget -u \"Jimbo Wales\" -s 20010911 -e 20010911 -i \"^A\""  
    print "   articles only"
    print "     wikiget -u \"Jimbo Wales\" -s 20010911 -e 20010930 -n 0"
    print "   talk pages only"
    print "     wikiget -u \"Jimbo Wales\" -s 20010911 -e 20010930 -n 1"
    print "   talk and articles only"
    print "     wikiget -u \"Jimbo Wales\" -s 20010911 -e 20010930 -n \"0|1\""
    print ""
    print "   -n codes: https://www.mediawiki.org/wiki/Extension_default_namespaces"
    print ""
    print " Recent changes:"
    print "   show edits for prior 30 days by IABot made under someone else's name"
    print "   (ie. OAuth) with an edit summary including this target word"
    print "     wikiget -k \"OAuth CID: 1804\" -r -i \"Bluelinking\""
    print ""
    print "   CID list: https://en.wikipedia.org/wiki/Special:Tags"
    print ""
    print " Category list:"
    print "   pages in a category"
    print "     wikiget -c \"Category:1900 births\""
    print "   subcats in a category"
    print "     wikiget -c \"Category:Dead people\" -q s"
    print "   subcats and pages in a category"
    print "     wikiget -c \"Category:Dead people\" -q sp"
    print ""
    print " Search-result list:"
    print "   article titles containing a search"
    print "     wikiget -a \"Jethro Tull\" -g title"
    print "   first 50 articles containing a search"
    print "     wikiget -a John -i 50"
    print "   include snippet of text containing the search string"
    print "     wikiget -a John -i 50 -d"
    print "   search talk and articles only"
    print "     wikiget -a \"Barleycorn\" -n \"0|1\""
    print "   regex search, include debug output"
    print "     wikiget -a \"insource:/ia[^.]*[.]us[.]/\" -y"
    print "   subpages of User:GreenC"
    print "     wikiget -a \"user: subpageof:GreenC\""
    print ""
    print "   search docs: https://www.mediawiki.org/wiki/Help:CirrusSearch"
    print "   -n codes: https://www.mediawiki.org/wiki/Extension_default_namespaces"
    print ""
    print " External link list:"
    print "   list articles containing a URL with this domain"
    print "     wikiget -x \"news.yahoo.com\""
    print "   list articles in NS 1 containing a URL with this domain"
    print "     wikiget -x \"*.yahoo.com\" -n 1"
    print ""
    print " All pages:"
    print "   all page titles excluding redirects w/debug tracking progress"
    print "     wikiget -A -t 2 -y > list.txt"
    print "   first 50 page titles including redirects"
    print "     wikiget -A -t 1 -k 50 > list.txt"
    print ""
    print " Print wiki text:"
    print "   wiki text of article \"Paris\" on the English Wiki"
    print "     wikiget -w \"Paris\""
    print "   plain text of article \"China\" on the French Wiki"
    print "     wikiget -w \"China\" -p -l fr"
    print "   wiki text of article on Wikinews"
    print "     wikiget -w \"Healthy cloned monkeys born in Shanghai\" -z wikinews"
    print ""  
    print " Edit page:"
    print "   Edit \"Paris\" by uploading new content from the local file paris.ws"
    print "     wikiget -E \"Paris\" -S \"Fix spelling\" -P \"/home/paris.ws\""
    print "   Input via stdin"
    print "     cat /home/paris.ws | wikiget -E \"Paris\" -S \"Fix spelling\" -P STDIN"
    print "   Purge page"
    print "     wikiget -G \"Paris\""
    print ""
 
}
function version() {
    print G["program"] " " G["version"]
    print "Copyright (C) " G["copyright"] " User:GreenC (en.wikipedia.org)"
    print
    print "The MIT License (MIT)"
    print
    print "Permission is hereby granted, free of charge, to any person obtaining a copy"      
    print "of this software and associated documentation files (the "Software"), to deal"   
    print "in the Software without restriction, including without limitation the rights"                
    print "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell"    
    print "copies of the Software, and to permit persons to whom the Software is"              
    print "furnished to do so, subject to the following conditions:"
    print
    print "The above copyright notice and this permission notice shall be included in"
    print "all copies or substantial portions of the Software."
    print
    print "THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR"
    print "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,"
    print "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE"
    print "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER"
    print "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,"
    print "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN"
    print "THE SOFTWARE."
    print 
}

# 
# Verify an argument has a valid value                
#
function verifyval(val) {

    if (val == "" || substr(val,1,1) ~ /^[-]/) {
        stdErr("\nCommand line argument has an empty value when it should have something.\n")
        usage(1)
    }
    return val
}              

#
# getopt()
#   Credit: GNU awk (/usr/local/share/awk/getopt.awk)
#   Pre-define these globaly: Optind = Opterr = 1 
#
function getopt(argc, argv, options,    thisopt, i) {

    if (length(options) == 0)    # no options given
        return -1

    if (argv[Optind] == "--") {  # all done
        Optind++
        _opti = 0
        return -1
    } else if (argv[Optind] !~ /^-[^:[:space:]]/) {
        _opti = 0
        return -1
    }
    if (_opti == 0)
        _opti = 2
    thisopt = substr(argv[Optind], _opti, 1)
    Optopt = thisopt
    i = index(options, thisopt)
    if (i == 0) {
        if (Opterr)
            printf("%c -- invalid option\n", thisopt) > "/dev/stderr"
        if (_opti >= length(argv[Optind])) {
            Optind++
            _opti = 0
        } else
            _opti++
        return "?"
    }
    if (substr(options, i + 1, 1) == ":") {
        # get option argument
        if (length(substr(argv[Optind], _opti + 1)) > 0) {
            Optarg = substr(argv[Optind], _opti + 1)
        }
        else {
            Optarg = argv[++Optind]
        }
        _opti = 0
    } else { 
        Optarg = ""
    }
    if (_opti == 0 || _opti >= length(argv[Optind])) {
        Optind++
        _opti = 0
    } else
        _opti++
    return thisopt
}

# [[ ________ Setup __________________________________________________________ ]]

#
# Check for existence of needed programs and files.
#
function setup(files_system) {

    if (! files_verify("ls") ) {
        stdErr("Unable to find 'ls' and/or 'command'. PATH problem?\n")
        exit
    }
    if (! files_verify(files_system) ) 
        exit
}

#
# Verify existence of programs in path
# Return 0 if fail.
#
function files_verify(files_system,    a, i, missing, to_path) {

    missing = 0

    # --- Hardcoded timeout check ---
    to_path = strip(sys2var("command -v timeout"))
    if (!empty(to_path)) {
        # wget max time: 3 tries * 120s timeout + 2 * 60s waitretry = 480s.
        G["timeout"] = to_path " 500s "
    } else {
        G["timeout"] = ""
    }
    
    split(files_system, a, " ")
    for ( i in a ) {
        if (! sys2var(sprintf("command -v %s",a[i])) ) {
            if (a[i] == "wget") G["wget"] = "false"
                else if (a[i] == "curl") G["curl"] = "false"
                else if (a[i] == "lynx") G["lynx"] = "false"
                else {
                    stdErr("Abort: command not found in PATH: " a[i])
                    missing++
                }
            }
            else if (a[i] == "wget") G["wget"] = "true"
            else if (a[i] == "curl") G["curl"] = "true"
            else if (a[i] == "lynx") G["lynx"] = "true"
        }

        if (G["wget"] == "false" && G["curl"] == "false" && G["lynx"] == "false") {
            stdErr("Abort: unable to find wget, curl or lynx in PATH.")
            return 0
        }
        else if (G["wget"] == "true")
            G["wta"] = "wget"
        else if (G["curl"] == "true")
            G["wta"] = "curl"
        else if (G["lynx"] == "true")
            G["wta"] = "lynx"

        if ( missing ) 
          return 0
        return 1
}

# [[ ________ Core read-only functions _______________________________________ ]]


# ___ Categories (-c)

#
# MediaWiki API:Categorymembers
#  https://www.mediawiki.org/wiki/API:Categorymembers
#
function category(entity,   ct, url, results) {

        if (entity !~ /^[Cc]ategory[:]/)
            entity = "Category:" entity

        if (G["cattypes"] ~ /p/)
            ct = ct " page"
        if (G["cattypes"] ~ /s/)
            ct = ct " subcat"
        if (G["cattypes"] ~ /f/)
            ct = ct " file"
        ct = strip(ct)
        gsub(/[ ]/,"|",ct)
 
        url = G["apiURL"] "action=query&list=categorymembers&cmtitle=" urlencodeawk(entity) "&cmtype=" urlencodeawk(ct) "&cmprop=title&cmlimit=max&format=json&formatversion=2&maxlag=" G["maxlag"]

        # Pass 'ct' to getcategory to preserve types during pagination
        results = uniq(getcategory(url, entity, ct) )

        if ( length(results) > 0)
            print results
        return length(results)
}
function getcategory(url, entity, ct,    jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin, "cmcontinue")
        
        while ( continuecode != "-1-1!!-1-1" ) {
            url = G["apiURL"] "action=query&list=categorymembers&cmtitle=" urlencodeawk(entity) "&cmtype=" urlencodeawk(ct) "&cmprop=title&cmlimit=max&format=json&formatversion=2&maxlag=" G["maxlag"] "&continue=" urlencodeawk("-||") "&cmcontinue=" urlencodeawk(continuecode, "rawphp")
            
            jsonin = http2var(url)
            
            if (apierror(jsonin, "json") > 0)
                return ""
                
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin, "cmcontinue")
        }
        return jsonout
}

# ___ External links list (-x) 

#
# MediaWiki API:Exturlusage
#  https://www.mediawiki.org/wiki/API:Exturlusage
#
function xlinks(entity,   url,results,a,c,i) {

        if (entity ~ /^https?/ )
            gsub(/^https?[:]\/\//,"",entity)
        else if(entity ~ /^\/\// ) 
            gsub(/^\/\//,"",entity)
        
        if (entity ~ /^[*]$/) {
            entity = ""
        }
        
        c = split("http|https|ftp|ftps|sftp", a, /[|]/)
        # iterate for euprotocol=a[i]
        for(i = 1; i <= c; i++) {
          url = G["apiURL"] "action=query&list=exturlusage&euprotocol=" urlencodeawk(a[i]) "&euexpandurl=&euquery=" urlencodeawk(entity) "&euprop=title&eulimit=max&eunamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"]
          
          # Pass a[i] to preserve the correct protocol during pagination
          results = results "\n" getxlinks(url, entity, a[i]) 
        }

        results = uniq( results )

        if ( length(results) > 0)
            print results
        return length(results)

}
function getxlinks(url, entity, euprotocol,     jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin,"eucontinue")

        while ( continuecode != "-1-1!!-1-1" ) {
            url = G["apiURL"] "action=query&list=exturlusage&euprotocol=" urlencodeawk(euprotocol) "&euexpandurl=&euquery=" urlencodeawk(entity) "&euprop=title&eulimit=max&eunamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"] "&continue=" urlencodeawk("-||") "&eucontinue=" urlencodeawk(continuecode, "rawphp")
            
            jsonin = http2var(url)
            
            if (apierror(jsonin, "json") > 0)
                return ""
                
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin,"eucontinue")

        }
        return jsonout
}

# ___ Recent changes (-r) 

#
# MediaWiki API:RecentChanges
#  https://www.mediawiki.org/wiki/API:RecentChanges#cite_note-1
#
function rechanges(username, tag,      url, results, entity) {

        if (length(username) > 0) 
            entity = "&rcuser=" urlencodeawk(username)
        else if (length(tag) > 0)
            entity = "&rctag=" urlencodeawk(tag)
        else 
            return 0

        url = G["apiURL"] "action=query&list=recentchanges&rcprop=" urlencodeawk("title|parsedcomment") entity "&rclimit=max&rcnamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"]

        results = uniq( getrechanges(url, entity) )

        if ( length(results) > 0) 
            print results
        return length(results)
}
function getrechanges(url, entity,         jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2varUcontribs(jsonin)
        continuecode = getcontinue(jsonin,"rccontinue")

        while ( continuecode != "-1-1!!-1-1" ) {
            url = G["apiURL"] "action=query&list=recentchanges&rcprop=" urlencodeawk("title|parsedcomment") entity "&rclimit=max&continue=" urlencodeawk("-||") "&rccontinue=" urlencodeawk(continuecode) "&rcnamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"]
            
            jsonin = http2var(url)
            
            if (apierror(jsonin, "json") > 0)
                return ""
                
            jsonout = jsonout "\n" json2varUcontribs(jsonin)
            continuecode = getcontinue(jsonin,"rccontinue")
        }

        return jsonout
}


# ___ User Contributions (-u) 

#
# MediaWiki API:Usercontribs
#  https://www.mediawiki.org/wiki/API:Usercontribs
#
function ucontribs(entity,sdate,edate,      url, results) {

        # API stopped working with User: prefix sometime in April 2018
        sub(/^[Uu]ser[:]/, "", entity)

        url = G["apiURL"] "action=query&list=usercontribs&ucuser=" urlencodeawk(entity) "&uclimit=max&ucstart=" urlencodeawk(sdate) "&ucend=" urlencodeawk(edate) "&ucdir=newer&ucnamespace=" urlencodeawk(G["namespace"]) "&ucprop=" urlencodeawk("title|parsedcomment") "&format=json&formatversion=2&maxlag=" G["maxlag"]

        results = uniq( getucontribs(url, entity, sdate, edate) )

        if ( length(results) > 0) 
            print results
        return length(results)
}
function getucontribs(url, entity, sdate, edate,         jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2varUcontribs(jsonin)
        continuecode = getcontinue(jsonin,"uccontinue")

        while ( continuecode != "-1-1!!-1-1" ) {
            url = G["apiURL"] "action=query&list=usercontribs&ucuser=" urlencodeawk(entity) "&uclimit=max&continue=" urlencodeawk("-||") "&uccontinue=" urlencodeawk(continuecode) "&ucstart=" urlencodeawk(sdate) "&ucend=" urlencodeawk(edate) "&ucdir=newer&ucnamespace=" urlencodeawk(G["namespace"]) "&ucprop=" urlencodeawk("title|parsedcomment") "&format=json&formatversion=2&maxlag=" G["maxlag"]
            
            jsonin = http2var(url)
            
            if (apierror(jsonin, "json") > 0)
                return ""
                
            jsonout = jsonout "\n" json2varUcontribs(jsonin)
            continuecode = getcontinue(jsonin,"uccontinue")
        }

        return jsonout
}


# ___ Forward links (-F) 

#
# MediaWiki API:Parsing_wikitext
#  https://www.mediawiki.org/wiki/API:Parsing_wikitext
#
# ___ Forward links (-F) 

#
# MediaWiki API:Links
#  https://www.mediawiki.org/wiki/API:Links
#
function forlinks(entity,      url, results) {

        url = G["apiURL"] "action=query&generator=links&titles=" urlencodeawk(entity) "&gpllimit=max&gplnamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"]

        results = uniq( getforlinks(url, entity) )

        if ( length(results) > 0) 
            print results
        return length(results)        
}
function getforlinks(url, entity,      jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin,"gplcontinue")

        while ( continuecode != "-1-1!!-1-1" ) {
        
            # Note: &generator requires "&continue=gplcontinue||" and not "&continue=-||"
            url = G["apiURL"] "action=query&generator=links&titles=" urlencodeawk(entity) "&gpllimit=max&gplnamespace=" urlencodeawk(G["namespace"]) "&continue=" urlencodeawk("gplcontinue||") "&gplcontinue=" urlencodeawk(continuecode, "rawphp") "&format=json&formatversion=2&maxlag=" G["maxlag"]
            
            jsonin = http2var(url)
            
            if (apierror(jsonin, "json") > 0)
                return ""
                
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin,"gplcontinue")
        }

        return jsonout
}


# ___ Redirects (-B) 
# Note: Must set namespace - will only return for the given namespace

#
# MediaWiki API:Redirects
#  https://www.mediawiki.org/wiki/API:Redirects
#
function redirects(entity,      url, results) {

        url = G["apiURL"] "action=query&prop=redirects&titles=" urlencodeawk(entity) "&rdprop=title&rdnamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&rdlimit=max&maxlag=" G["maxlag"]

        results = uniq( getrdchanges(url, entity) )

        if ( length(results) > 0) 
            print results
        return length(results)
}
function getrdchanges(url, entity,         jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2varRd(jsonin)
        continuecode = getcontinue(jsonin,"rdcontinue")

        while ( continuecode != "-1-1!!-1-1" ) {
            url = G["apiURL"] "action=query&prop=redirects&rdprop=title&rdcontinue=" urlencodeawk(continuecode) "&titles=" urlencodeawk(entity) "&rdnamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&rdlimit=max&maxlag=" G["maxlag"]
            jsonin = http2var(url)

            if (apierror(jsonin, "json") > 0)
                return ""
            
            jsonout = jsonout "\n" json2varRd(jsonin)
            continuecode = getcontinue(jsonin,"rdcontinue")
        }
        return jsonout
}


# ___ Backlinks (-b) 

#
# MediaWiki API:Backlinks
#  https://www.mediawiki.org/wiki/API:Backlinks
#
function backlinks(entity,      url, blinks) {

        if (G["bltypes"] ~ /n/) {
            url = G["apiURL"] "action=query&list=backlinks&bltitle=" urlencodeawk(entity) "&blnamespace=" urlencodeawk(G["namespace"]) "&blredirect&bllimit=max&continue=&blfilterredir=nonredirects&format=json&formatversion=2&maxlag=" G["maxlag"]
            blinks = getbacklinks(url, entity, "blcontinue") # normal backlinks
        }

        if ( entity ~ /^[Tt]emplate[:]/ && G["bltypes"] ~ /t/) {    # transclusion backlinks
            url = G["apiURL"] "action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&continue=&eilimit=max&format=json&formatversion=2&maxlag=" G["maxlag"]
            if (length(blinks) > 0)
                blinks = blinks "\n" getbacklinks(url, entity, "eicontinue")
            else
                blinks = getbacklinks(url, entity, "eicontinue")
        } 
        else if ( entity ~ /^[Ff]ile[:]/ && G["bltypes"] ~ /f/) { # file backlinks
            url = G["apiURL"] "action=query&list=imageusage&iutitle=" urlencodeawk(entity) "&iunamespace=" urlencodeawk(G["namespace"]) "&iuredirect&iulimit=max&continue=&iufilterredir=nonredirects&format=json&formatversion=2&maxlag=" G["maxlag"]
            if (length(blinks) > 0)
                blinks = blinks "\n" getbacklinks(url, entity, "iucontinue")
            else
                blinks = getbacklinks(url, entity, "iucontinue")
        }

        blinks = uniq(blinks)
        if (length(blinks) > 0)
            print blinks 

        close(outfile)
        return length(blinks)
}
function getbacklinks(url, entity, method,      jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin, method)

        while ( continuecode != "-1-1!!-1-1" ) {

            if ( method == "eicontinue" )
                url = G["apiURL"] "action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&eilimit=max&continue=" urlencodeawk("-||") "&eicontinue=" urlencodeawk(continuecode) "&format=json&formatversion=2&maxlag=" G["maxlag"]
            if ( method == "iucontinue" )
                url = G["apiURL"] "action=query&list=imageusage&iutitle=" urlencodeawk(entity) "&iunamespace=" urlencodeawk(G["namespace"]) "&iuredirect&iulimit=max&continue=" urlencodeawk("-||") "&iucontinue=" urlencodeawk(continuecode) "&iufilterredir=nonredirects&format=json&formatversion=2&maxlag=" G["maxlag"]
            if ( method == "blcontinue" )
                url = G["apiURL"] "action=query&list=backlinks&bltitle=" urlencodeawk(entity) "&blnamespace=" urlencodeawk(G["namespace"]) "&blredirect&bllimit=max&continue=" urlencodeawk("-||") "&blcontinue=" urlencodeawk(continuecode) "&blfilterredir=nonredirects&format=json&formatversion=2&maxlag=" G["maxlag"]

            jsonin = http2var(url)
            if (apierror(jsonin, "json") > 0)
                return ""
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin, method)
        }

        return jsonout
}

# ___ Print wiki text (-w) 

#
# Print wiki text (-w) with the plain text option (-p)
#  MediaWiki API Extension:TextExtracts
#   https://www.mediawiki.org/wiki/Extension:TextExtracts
#
function wikitextplain(namewiki,    command,f,target_title,xmlin,c,b,k) {

        command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(strip(namewiki), "uri") "&action=raw"
        f = http2var(command)
        if (empty(f)) 
            return ""

        target_title = wikitext_helper(f)
        if (empty(target_title)) 
            target_title = namewiki

        command = G["apiURL"] "format=xml&action=query&prop=extracts&exlimit=1&explaintext&titles=" urlencodeawk(target_title) 
        xmlin = http2var(command)

        if (apierror(xmlin, "xml") > 0) 
            return ""
        
        c = split(convertxml(xmlin), b, "<extract[^>]*>")
        if (c > 1) {
            k = substr(b[2], 1, match(b[2], "</extract>") - 1)
            return strip(k)
        }
        
        return ""
}
function wikitext(namewiki,    command,f,target_title) {

        command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(strip(namewiki)) "&action=raw"
        f = http2var(command)
        if (empty(f)) 
            return ""

        target_title = wikitext_helper(f)
        if (!empty(target_title)) {
            command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(target_title) "&action=raw"
            f = http2var(command)
        }
        
        if (empty(f))
            return ""
        else
            return f
}
function wikitext_helper(text,    r) {
        if (G["followredirect"] == "true" && tolower(text) ~ /#[ ]*redir/) {
            if (match(text, /#[ ]*[Rr][Ee][^]]*[]]/, r) > 0) {
                gsub(/#[ ]*[Rr][Ee][Dd][Ii][^[]*[[]/, "", r[0])
                return strip(substr(r[0], 2, length(r[0]) - 2))
            }
        }
        return ""
}

# ___ All pages (-A)

#
# MediaWiki API: Allpages
#  https://www.mediawiki.org/wiki/API:Allpages
#
function allPages(redirtype,    url,results,apfilterredir,aplimit) {

        if (redirtype == "1")
            apfilterredir = "all"
        else if (redirtype == "2")
            apfilterredir = "nonredirects"
        else if (redirtype == "3")
            apfilterredir = "redirects"
        else
            apfilterredir = "nonredirects"

        if (G["maxpages"] < 500 && G["maxpages"] > 0)
            aplimit = G["maxpages"] + G["maxpages"]  # get extra in case redirs are filtered
        else
            aplimit = "max"

        url = G["apiURL"] "action=query&list=allpages&aplimit=" aplimit "&apfilterredir=" apfilterredir "&apnamespace=" urlencodeawk(G["namespace"], "rawphp") "&format=json&formatversion=2&maxlag=" G["maxlag"]

        getallpages(url, apfilterredir, aplimit)
}
function getallpages(url,apfilterredir,aplimit,         jsonin, jsonout, continuecode, count, pages_printed, pages_in_buffer, a, i) {

        pages_printed = 0

        jsonin = http2var(url)
        if ( apierror(jsonin, "json") > 0)
            return
        continuecode = getcontinue(jsonin,"apcontinue")

        jsonout = json2var(jsonin)
        if ( ! empty(jsonout)) {
            pages_in_buffer = split(jsonout, a, "\n")
            if (G["maxpages"] > 0) {
                if (pages_printed + pages_in_buffer >= G["maxpages"]) {
                    for(i = 1; i <= G["maxpages"] - pages_printed; i++) {
                        if ( ! empty(a[i])) print a[i]
                    }
                    return
                }
            }
            print jsonout
            pages_printed += pages_in_buffer
        }

        while ( continuecode != "-1-1!!-1-1" ) {
            if (G["maxpages"] > 0 && pages_printed >= G["maxpages"]) {
                return
            }

            url = G["apiURL"] "action=query&list=allpages&aplimit=" aplimit "&apfilterredir=" apfilterredir "&apnamespace=" urlencodeawk(G["namespace"], "rawphp") "&apcontinue=" urlencodeawk(continuecode, "rawphp") "&continue=" urlencodeawk("-||") "&format=json&formatversion=2&maxlag=" G["maxlag"]
            jsonin = http2var(url)

            if (apierror(jsonin, "json") > 0)
                return ""
            
            continuecode = getcontinue(jsonin,"apcontinue")
            jsonout = json2var(jsonin)

            if ( ! empty(jsonout)) {
                pages_in_buffer = split(jsonout, a, "\n")
                if (G["maxpages"] > 0) {
                    if (pages_printed + pages_in_buffer >= G["maxpages"]) {
                        for(i = 1; i <= G["maxpages"] - pages_printed; i++) {
                            if ( ! empty(a[i])) print a[i]
                        }
                        return
                    }
                }
                print jsonout
                pages_printed += pages_in_buffer
            }
            jsonin = "" # free memory
        }
}


# ___ Search list (-a) 

#
# MediaWiki API:Search
#  https://www.mediawiki.org/wiki/API:Search
#
function search(srchstr,    url, results, a) {

        if (G["snippet"] == "false")
            G["srprop"] = "timestamp"
        else
            G["srprop"] = "timestamp|snippet"
                                       
        if (G["searchtarget"] ~ /title/)  # Use this instead of &srwhat
            srchstr = "intitle:" srchstr   # See https://www.mediawiki.org/wiki/API_talk:Search#title_search_is_disabled  

        url = G["apiURL"] "action=query&list=search&srsearch=" urlencodeawk(srchstr) "&srprop=" urlencodeawk(G["srprop"]) "&srnamespace=" urlencodeawk(G["namespace"]) "&srlimit=50&continue=" urlencodeawk("-||") "&format=xml&maxlag=" G["maxlag"]

        results = strip(getsearch(url, srchstr))   # Don't uniq, confuses ordering and not needed for search results

        l = length(results)

        if (length(results) > 0)
            print results
        if (split(results,a,"\n") > 9999)
            print "Warning (wikiget): Search results max out at 10000. See https://www.mediawiki.org/wiki/API:Search" > "/dev/stderr"
        return length(results)
}
function getsearch(url, srchstr,   xmlin,xmlout,offset,retrieved) {

        xmlin = http2var(url)
        if (apierror(xmlin, "xml") > 0)
            return ""
        xmlout = parsexmlsearch(xmlin)
        offset = getoffsetxml(xmlin)

        if (G["numsearch"] == "true") 
            return totalhits(xmlin)

        retrieved = 50
        if (retrieved > G["maxsearch"] && G["maxsearch"] != 0) 
            return trimxmlout(xmlout, G["maxsearch"])
   
        while ( offset) {
            url = G["apiURL"] "action=query&list=search&srsearch=" urlencodeawk(srchstr) "&srprop=" urlencodeawk(G["srprop"]) "&srnamespace=" urlencodeawk(G["namespace"]) "&srlimit=50&continue=" urlencodeawk("-||") "&format=xml&maxlag=" G["maxlag"] "&sroffset=" offset
            xmlin = http2var(url)

            if (apierror(xmlin, "xml") > 0)
                break
            
            xmlout = xmlout "\n" parsexmlsearch(xmlin)
            offset = getoffsetxml(xmlin)
            retrieved = retrieved + 50
            if (retrieved > G["maxsearch"] && G["maxsearch"] != 0)
                return trimxmlout(xmlout, G["maxsearch"])
        }

        return xmlout
} 
function parsexmlsearch(xmlin,   f,g,e,c,a,i,out,snippet,title) {

        f = split(xmlin,e,/<search>|<\/search>/)
        c = split(e[2],a,"/>")  

        while (++i < c) {
            if (a[i] ~ /title[=]/) {
                match(a[i], /title="[^"]*"/,k)
                split(gensub("title=","","g",k[0]), g, "\"")
                title = convertxml(g[2])
                match(a[i], /snippet="[^"]*"/,k)
                snippet = gensub("snippet=","","g",k[0])
                snippet = convertxml(snippet)
                gsub(/<span class[=]"searchmatch">|<\/span>/,"",snippet)
                snippet = convertxml(snippet)
                gsub(/^"|"$/,"",snippet)
                if (G["snippet"] != "false") 
                    out = out title " <snippet>" snippet "</snippet>\n"
                else
                    out = out title "\n"
          }
        }
        return strip(out)
}

function getoffsetxml(xmlin,  a, offset) {

        if ( match(xmlin, /<continue sroffset[=]"[0-9]{1,}"/, offset) > 0) {
            split(offset[0],a,/"/)
            return a[2]
        }
        else 
            return ""
}
function trimxmlout(xmlout, max,   c,a,i,out) {

        if ( split(xmlout, a, "\n") > 0) {
            while (i++ < max) 
                out = out a[i] "\n"
            return out
        }
}
function totalhits(xmlin,    a, b) {

        # <searchinfo totalhits="40"/>
        if (match(xmlin, /<searchinfo totalhits[=]"[0-9]{1,}"/, a) > 0) {
            if (split(a[0],b,"\"") > 0)
                return b[2]
            else
                return "error"
        }
        else
            return "error"
}

# [[ ________ Utilities ______________________________________________________ ]]

#
# readfile() - same as @include "readfile"
#
#   . leaves an extra trailing \n just like with the @include readfile
#
#   Credit: https://www.gnu.org/software/gawk/manual/html_node/Readfile-Function.html by Denis Shirokov
#
function readfile(file,     tmp, save_rs) {
    save_rs = RS     
    RS = "^$"
    getline tmp < file
    close(file)
    RS = save_rs
    return tmp
}

#
# json2var - given raw json extract field "title" and convert to \n seperated string
#
function json2var(json,  jsona,arr) {
    if (query_json(json, jsona) >= 0) {
        splitja(jsona, arr, 3, "title")
        return join(arr, 1, length(arr), "\n")
    }
}

#
# Uncontribs version 
#
function json2varUcontribs(json,  jsona, arrTitle, arrComment, arr, i, j) {
    
    delete arr
    if (query_json(json, jsona) >= 0) {
        splitja(jsona, arrTitle, 3, "title")
        splitja(jsona, arrComment, 3, "parsedcomment")
        # awkenough_dump(jsona, "jsona")
        for(i = 1; i <= length(arrComment); i++) {

          if(! empty(G["inccomments"]) && ! empty(G["exccomments"]) ) {
            if(arrComment[i] ~ G["inccomments"] && arrComment[i] !~ G["exccomments"]) {
              j++
              arr[j] = arrTitle[i]
            }
          }
          else if(! empty(G["inccomments"])) {
            if(arrComment[i] ~ G["inccomments"] ) {
              j++
              arr[j] = arrTitle[i]
            }
          }
          else if(! empty(G["exccomments"])) {
            if(arrComment[i] !~ G["exccomments"] ) {
              j++
              arr[j] = arrTitle[i]
            }
          }
          else if( empty(G["exccomments"]) && empty(G["inccomments"])) {
            j++
            arr[j] = arrTitle[i]
          }
        }
        return join(arr, 1, length(arr), "\n")
    }

}

#
# json2varRd - given raw json extract field "title" and convert to \n seperated string - for API:Redirects
#
function json2varRd(json,  jsona,arr) {
    if (query_json(json, jsona) >= 0) {
        # jsona["query","pages","1","redirects","4","title"]=Template:Cite-web
        splitja(jsona, arr, 5, "title")
        return join(arr, 1, length(arr), "\n")
    }
}

#
# Parse continue code from JSON input
#
function getcontinue(jsonin, method,    jsona,id) {

        if( query_json(jsonin, jsona) >= 0) {
          id = jsona["continue", method]
          if(!empty(id))
            return id
        }
        return "-1-1!!-1-1" # Random string unlikely to be the name of a Wiki article
}

#
# entity_exists - see if a page on Wikipedia exists
#   eg. if ( ! entity_exists("Gutenberg author") ) print "Unknown page"
#
function entity_exists(entity   ,url,jsonin) {

        url = G["apiURL"] "action=query&titles=" urlencodeawk(entity) "&format=json"
        jsonin = http2var(url)
        if (jsonin ~ "\"missing\"")
            return 0
        return 1
}

#
# Basic check of API results for error
#
function apierror(input, type,   pre, code) {

        pre = "API error: "

        if (length(input) < 5) {
            stdErr(pre "Received no response.")
            return 1
        }

        if (type == "json") {
            # Catch "error" blocks even if WMF injects spaces or newlines
            if (match(input, /"error"[^}]*"code"[: \t]+"[^"]*"/) > 0) {
                stdErr(pre substr(input, RSTART, RLENGTH))
                return 1
            }
        }

        else if (type == "xml") {
            if (match(input, /error code[=]"[^"]*" info[=]"[^"]*"/, code) > 0) {
                stdErr(pre code[0])
                return 1
            }
        }
        else
            return
}

#
# Uniq a list of \n separated names
#
function uniq(names,    b,c,i,x) {

        c = split(names, b, "\n")
        names = "" # free memory
        
        for (i = 1; i <= c; i++) {
            gsub(/\\"/, "\"", b[i])
            if (b[i] != "") {
                x[b[i]] = "" # The key itself enforces uniqueness
            }
        }
        
        delete b # free memory
        return join2(x, "\n")
}

#
# Webpage to variable. url is assumed to be percent encoded.
#
function http2var(url,  tries, i, op, baseUrl, queryStr, authHeader, headerCmd, local_opts, wait, maxlag_val, current_url, final_url) {

        if (G["debug"])
            print url > "/dev/stderr"                          

        if (url ~ /'/) gsub(/'/, "%27", url)
        if (url ~ /’/) gsub(/’/, "%E2%80%99", url)

        # Clean the URL of any pre-existing maxlag parameters
        gsub(/&maxlag=[0-9]+/, "", url)
        gsub(/\?maxlag=[0-9]+&/, "?", url)
        gsub(/\?maxlag=[0-9]+$/, "", url)

        tries = 3
        if(url ~ "([.]|/)wiki")
            tries = 20

        force_post = 0  # force POST in proxy API if initial GET fails

        for(i = 1; i <= tries; i++) {
            
            # Dynamic maxlag escalation
            maxlag_val = G["maxlag"] + ((i - 1) * 5)
            
            if (url ~ /\?/) current_url = url "&maxlag=" maxlag_val
            else current_url = url "?maxlag=" maxlag_val

            headerCmd = ""
            wait = 0

            # --- PARSE AND AUTO-POST LONG URLS ---
            is_post = 0
            post_data = ""
            method = "GET"

            if (index(current_url, "?") > 0) {
                baseUrl = substr(current_url, 1, index(current_url, "?") - 1)
                queryStr = substr(current_url, index(current_url, "?") + 1)
            } else {
                baseUrl = current_url
                queryStr = ""
            }

            # Convert to POST if the URL is massive OR if a previous GET failed
            if ((force_post == 1 || length(current_url) > 2000) && queryStr != "") {
                is_post = 1
                method = "POST"
                post_data = queryStr
                current_url = baseUrl # Strip query string so it isn't appended to the proxy target
            }

            # --- OAUTH & HEADER BUILDER ---
            if (G["oauth_read"] == 1 && current_url ~ /api\.php/ && !empty(G["consumerKey"]) && !empty(G["accessKey"]) && G["wta"] != "lynx") {
                
                # Pass the correct payload and HTTP method for OAuth signing
                auth_payload = is_post ? post_data : queryStr
                authHeader = MWOAuthGenerateHeader(G["consumerKey"], G["consumerSecret"], G["accessKey"], G["accessSecret"], baseUrl, method, auth_payload)
                
                if (!empty(authHeader)) {
                    # If proxy is active, repackage the OAuth header
                    if (G["tfproxy"] == 1 && G["tfproxy_pass"] != "") {
                        gsub(/^Authorization: /, "X-WMF-OAuth: ", authHeader)
                    }
                    
                    if (G["wta"] == "wget") {
                        headerCmd = " --header=" shquote(strip(authHeader)) " "
                    } else if (G["wta"] == "curl") {
                        headerCmd = " -H " shquote(strip(authHeader)) " "
                    }
                }
            }

            # --- INJECT PROXY AUTH HEADER ---
            # Only inject the password header if the proxy toggle is ON
            if (G["tfproxy"] == 1 && G["tfproxy_pass"] != "") {
                if (G["wta"] == "wget") headerCmd = headerCmd " --header=" shquote(G["tfproxy_header"] ": " G["tfproxy_pass"]) " "
                else if (G["wta"] == "curl") headerCmd = headerCmd " -H " shquote(G["tfproxy_header"] ": " G["tfproxy_pass"]) " "
            }

            local_opts = " --user-agent=" shquote(G["agent"]) " --referer=\"https://en.wikipedia.org/wiki/Main_Page\" --no-cookies "

            # --- ROUTING SWITCH ---
            # Route through proxy ONLY if toggle is ON and password is set
            if (G["tfproxy"] == 1 && G["tfproxy_pass"] != "") {
                final_url = G["tfproxy_url"] urlencodeawk(current_url)
                
                if (G["debug"]) {
                    if (G["oauth_read"] == 1) { 
                        stdErr("http2var: [PROXY ACTIVE] Routing through tfproxy w/ OAuth")
                    } else {
                        stdErr("http2var: [PROXY ACTIVE] Routing through tfproxy w/out OAuth")
                    }
                }
            } else {
                final_url = current_url
                
                # Add a clean debug notification when the bypass is used
                if (G["debug"] && G["tfproxy_pass"] != "" && G["tfproxy"] == 0) {
                    if (G["oauth_read"] == 1) {
                        stdErr("http2var: [PROXY BYPASSED] Direct connection w/ OAuth")
                    } else {
                        stdErr("http2var: [PROXY BYPASSED] Direct connection w/out OAuth")
                    }
                }
            }

            # --- EXECUTION ---
            if (G["wta"] == "wget") {
                post_cmd = is_post ? " --post-data=" shquote(post_data) " " : " "
                op = sys2var(G["timeout"] " wget " local_opts " --content-on-error " headerCmd post_cmd " -q -O- -- " shquote(final_url) )  
            } else if (G["wta"] == "curl") {
                post_cmd = is_post ? " -d " shquote(post_data) " " : " "
                op = sys2var(G["timeout"] " curl --max-time 120 -L -s -k --user-agent " shquote(G["agent"]) " " headerCmd post_cmd "-- " shquote(final_url) )  
            } else if (G["wta"] == "lynx") {
                op = sys2var("lynx -source -- " shquote(final_url) )  
            }
            
            # --- VALIDATION & BACKOFF ---
            if (!empty(op)) {
                if (op ~ /"error"[^}]*"code"[: \t]+"[^"]*"/) {
                    if (op ~ /"maxlag"/ || op ~ /"ratelimited"/) {
                        if(G["debug"])
                          stdErr("http2var: [WARNING] API Overload or Rate Limit (Attempt " i ").")
                        wait = 15 + (i * 10) 
                    } else if (op ~ /"mwoauth-/) {
                        if(G["debug"])
                          stdErr("http2var: [WARNING] Transient OAuth Drop (Attempt " i ")" final_url)
                        wait = 10 + (i * 5) 
                    } else {
                        if(G["debug"])
                          stdErr("http2var: [FATAL API ERROR] " substr(op, 1, 300))
                        return op 
                    }
                }
                else if (tolower(op) ~ /^[ \t\n]*(<!doctype html|<html)/) {
                     if(G["debug"])
                       stdErr("http2var: [WARNING] WMF Varnish HTML Gateway Error (Attempt " i ").")
                     wait = 15 + (i * 5) 
                     force_post = 1
                } 
                else if (url ~ /format=json/ && op !~ /}[ \t\n]*$/) {
                     if(G["debug"])
                       stdErr("http2var: [WARNING] Truncated Payload or Gateway Drop (Attempt " i ").")
                     wait = 15 + (i * 10)
                     force_post = 1
                }
                else {
                    return op 
                }
            } else {
                if(G["debug"])
                  stdErr("http2var: [WARNING] Network Timeout or Empty Response (Attempt " i ").")
                wait = 15 + (i * 10)
                force_post = 1
            }
            
            if (i < tries && wait > 0) {
                if(G["debug"])
                  stdErr("http2var: Retrying in " wait "s... " substr(op, 1, 100))
                system("sleep " wait)
            }
        }

        # --- EXHAUSTION CATCH ---
        if (G["debug"]) {
            stdErr("http2var: [ABORT] Maximum retries (" tries ") exhausted. Giving up on URL.")
        }
        
        return ""
}





# [[ ________ Library ________________________________________________________ ]]

# 
# sys2var() - run a system command and store result in a variable
#  
#  . supports pipes inside command string
#  . stderr is sent to null
#  . if command fails (errno) return null        
#          
#  Example:            
#     googlepage = sys2var("wget -q -O- http://google.com")
#
function sys2var(command        ,fish, scale, ship) {

    # command = command " 2>/dev/null"
    while ( (command | getline fish) > 0 ) {
        if ( ++scale == 1 )
            ship = fish
        else
            ship = ship "\n" fish                
    }
    close(command)
    system("")
    return ship
}

#
# sys2varPipe() - supports piping string data into a program eg. echo <data> | <command>
#
#  . <data> is a string not a command
#
#   Example:
#      replicate 'cat /etc/passwd | wc'
#        print sys2varPipe(readfile("/etc/passwd"), Exe["wc"])
#      send output of one command to another
#        print sys2varPipe(sys2var("date +\"%s\""), Exe["wc"])
#
function sys2varPipe(data, command,   fish, scale, ship) {

    printf("%s",data) |& command
    close(command, "to")

    while ( (command |& getline fish) > 0 ) {
        if ( ++scale == 1 )
            ship = fish
        else
            ship = ship "\n" fish
    }
    close(command)
    return ship
}


#    
# urlElement - given a URL, return a sub-portion (scheme, netloc, path, query, fragment)
#
#  In the URL "https://www.cwi.nl:80/nl?dooda/guido&path.htm#section"
#   scheme = https
#   netloc = www.cwi.nl:80
#   path = /nl                  
#   query = dooda/guido&path.htm
#   fragment = section
#
#  Example:                
#     uriElement("https://www.cwi.nl:80/nl?", "path") returns "/nl"
#           
#   . URLs have many edge cases. This function works for well-formed URLs.
#   . If a robust solution is needed:
#       "python3 -c \"from urllib.parse import urlsplit; import sys; o = urlsplit(sys.argv[1]); print(o." element ")\" " shquote(url)
#   . returns full url on error
#
function urlElement(url, element,    a, scheme, netloc, path, query, fragment) {

    if (url ~ /^\/\//) 
        url = "http:" url

    # 1. Extract Fragment (everything after #)
    if (index(url, "#")) {
        split(url, a, "#")
        fragment = a[2]
        url = a[1]
    }

    # 2. Extract Query (everything after ?)
    if (index(url, "?")) {
        split(url, a, "?")
        query = a[2]
        url = a[1]
    }

    # 3. Extract Scheme (everything before ://)
    if (index(url, "://")) {
        split(url, a, "://")
        scheme = a[1]
        url = a[2]
    }

    # 4. Extract Netloc and Path
    # Now that ? and # are gone, the first / separates the domain from the path
    if (index(url, "/")) {
        netloc = substr(url, 1, index(url, "/") - 1)
        path = substr(url, index(url, "/"))
    } else {
        # If there is no slash left, the whole remaining string is the domain
        netloc = url
        path = ""
    }
    
    if (element == "scheme") return scheme
    else if (element == "netloc") return netloc
    else if (element == "path") return path
    else if (element == "query") return query
    else if (element == "fragment") return fragment

    return ""
}

#
# urldecodeawk - natively decode percent-encoded strings
#
function urldecodeawk(str, class,  c, len, res, i, hex) {
    res = ""
    len = length(str)
    for (i = 1; i <= len; i++) {
        c = substr(str, i, 1)
        if (c == "%" && i + 2 <= len) {
            hex = substr(str, i + 1, 2)
            if (hex ~ /^[0-9a-fA-F]{2}$/) {
                res = res sprintf("%c", strtonum("0x" hex))
                i += 2
                continue
            }
        } else if (c == "+" && class != "uri") {
            res = res " "
            continue
        }
        res = res c
    }
    return res
}

# 
# urlencodeawk - urlencode a string
#
#  . if optional 'class' is "url" treat 'str' with best-practice URL encoding
#     see https://perishablepress.com/stop-using-unsafe-characters-in-urls/
#  . if 'class' is "rawphp" attempt to match behavior of PhP rawurlencode()              
#  . otherwise encode everything except 0-9A-Za-z
#          
#  Requirement: gawk -b
#  Credit: Rosetta Code May 2015
#          GreenC
#
function urlencodeawk(str,class,  c, len, res, i, ord, re) {

    if (class == "url")               
        re = "[$\\-_.+!*'(),,;/?:@=&0-9A-Za-z]"
    else if (class == "rawphp")         
        re = "[\\-_.~0-9A-Za-z]"
    else
        re = "[\\-_.~0-9A-Za-z]"

    for (i = 0; i <= 255; i++)
        ord[sprintf("%c", i)] = i        
    len = length(str)      
    res = ""
    for (i = 1; i <= len; i++) {
        c = substr(str, i, 1)
        if (c ~ re)                # don't encode          
            res = res c
        else
            res = res "%" sprintf("%02X", ord[c])
    }
    return res
}

#
# concatarray() - merge array a & b into c
#
#  . if array a & b have a same key eg. a["1"] = 2 and b["1"] = 3
#      then b takes precedent eg. c["1"] = 3
#
function concatarray(a, b, c,    i) {

    delete c          
    for (i in a)       
        c[i] = a[i]
    for (i in b)    
        c[i] = b[i]        
}

#
# splitx() - split str along re and return num'th element
#
#   Example:
#      print splitx("a:b:c:d", "[:]", 3) ==> "c"
#
function splitx(str, re, num,    a) {
    # split() returns the number of fields created. Ensure num is within bounds.
    if (split(str, a, re) >= num)
        return a[num] 
    
    return ""
}

#               
# removefile2() - delete a file/directory
#
#   . no wildcards 
#   . return 1 success
#
#   Requirement: rm
#   
function removefile2(str) {

    if (str ~ /[*|?]/ || empty(str)) 
        return 0

    if (exists2(str)) {
        system("") # Flush buffer before OS handoff
        system("rm -rf -- " shquote(str) " >/dev/null 2>&1")
        
        if (! exists2(str)) 
            return 1
    }
    
    return 0
}

#
# exists2() - check for file existence                               
#
#   . return 1 if exists, 0 otherwise.
#   . no dependencies version
#
function exists2(file    ,line, msg) {

    # Prevent fatal gawk crash on null string evaluation
    if (file == "") 
        return 0

    if ((getline line < file) == -1 ) {
        msg = (ERRNO ~ /Permission denied/ || ERRNO ~ /a directory/) ? 1 : 0
        close(file)
        return msg
    }
    
    close(file)
    return 1
}

#           
# empty() - return 1 if string is 0-length      
#
function empty(s) {                 
    if (length(s) == 0)  
        return 1      
    return 0           
}                

#
# shquote() - make string safe for shell
#
#  . an alternate is shell_quote.awk in /usr/local/share/awk which uses '"' instead of \'
# 
#  Example:
#     print shquote("Hello' There")    produces 'Hello'\'' There'
#     echo 'Hello'\'' There'           produces Hello' There
#
function shquote(str) {      
    gsub(/'/, "'\\''", str)          
    gsub(/’/, "'\\’'", str)
    return "'" str "'"                  
}

#   
# convertxml() - convert XML to plain
#
function convertxml(str) {  
    gsub(/&lt;/, "<", str)              
    gsub(/&gt;/, ">", str)
    gsub(/&quot;/, "\"", str)            
    gsub(/&#039;/, "'", str)
    gsub(/&#10;/, "\n", str)  
    gsub(/&amp;/, "\\&", str) # Must remain last
    return str
}


# 
# strip() - strip leading/trailing whitespace
#   
function strip(str) {                
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", str)
    return str
}

#   
# join() - merge an array of strings into a single string. Array indice are numbers.
# 
function join(arr, start, end, sep,    result, i) {    
    if (start > end)
        return ""

    result = arr[start]            

    for (i = start + 1; i <= end; i++)
        result = result sep arr[i]

    return result
}

#
# join2() - merge an array of strings into a single string. Array indices are strings.
#
#   . optional third argument 'sortkey' informs how to sort:
#       https://www.gnu.org/software/gawk/manual/html_node/Controlling-Scanning.html
#   . spliti() does reverse 
#
function join2(arr, sep, sortkey,         i, lobster, result, save_sorted, has_saved) {

    # 1. Apply local sort if requested
    if (!empty(sortkey)) {
        if ("sorted_in" in PROCINFO) {
            save_sorted = PROCINFO["sorted_in"]
            has_saved = 1
        }
        PROCINFO["sorted_in"] = sortkey
    }

    # 2. Join the associative array keys
    for (lobster in arr) {
        if (++i == 1) {
            result = lobster
            continue
        }
        result = result sep lobster
    }

    # 3. Safely restore global sort state
    if (!empty(sortkey)) {
        if (has_saved)
            PROCINFO["sorted_in"] = save_sorted
        else
            delete PROCINFO["sorted_in"]
    }

    return result
}

# 
# subs() - like sub() but literal non-regex
# 
#   Example:
#      s = "*field"
#      print subs("*", "-", s)  #=> -field
# 
#   Credit: adapted from lsub() by Daniel Mills https://github.com/e36freak/awk-libs
# 
function subs(pat, rep, str,    len, i) {

    if (!length(str))
        return str

    # get the length of pat, in order to know how much of the string to remove
    if (!(len = length(pat)))
        return str

    # substitute str for rep
    if (i = index(str, pat))
        str = substr(str, 1, i - 1) rep substr(str, i + len)

    return str     
}                  

#
# splits() - literal version of split()
#
#   . the "sep" is a literal string not re
#   . see also subs() and gsubs()
#       
#   Credit: https://github.com/e36freak/awk-libs (Daniel Mills)
#               
function splits(str, arr, sep,    len, slen, i) {

    delete arr
    
    # Fast-fail to mimic native split() behavior
    if (str == "")
        return 0

    # if "sep" is empty, just do a normal split
    if (!(slen = length(sep))) {         
        return split(str, arr, "")
    }

    # loop while "sep" is matched
    while (i = index(str, sep)) {
        # append field to array
        arr[++len] = substr(str, 1, i - 1)
        # remove that portion (with the sep) from the string
        str = substr(str, i + slen)
    }
    
    arr[++len] = str
    return len
}

#
# asplit() - break "key=val SEP key=val" strings into array[key]=value
#
#   . can optionally supply "re" for equals, space; if they're the same or equals is "", array will be setlike
#
#   Example              
#     asplit(arr, "action=query&format=json&meta=tokens", "=", "&")
#       arr["action"] = "query"
#       arr["format"] = "json"
#       arr["meta"]   = "tokens"
# 
# Credit: https://github.com/dubiousjim/awkenough
# 
function asplit(array, str, equals, space,     aux, i, n) {

    n = split(str, aux, (space == "") ? "[ \n]+" : space)
    
    if (space && equals == space)
        equals = ""               
    else if (!length(equals))             
        equals = "="
        
    delete array 
    
    for (i = 1; i <= n; i++) {
        if (equals && match(aux[i], equals))
            array[substr(aux[i], 1, RSTART-1)] = substr(aux[i], RSTART+RLENGTH)
        else
            array[aux[i]] = "" # FIX: Explicitly assign the empty value
    }              
    
    delete aux     
    return n
}

#
# readfile2() - similar to readfile but no trailing \n                
#
#   Credit: https://github.com/dubiousjim/awkenough getfile()
#
function readfile2(path,    v, p, res) {
    
    # Prevent fatal gawk crash
    if (path == "") 
        return ""

    res = p = ""
    while ((getline v < path) > 0) {
        res = res p v
        p = "\n"
    }        
    
    close(path)
    return res
}

#
# mktemp() - make a temporary unique file or directory and/or returns its name         
#
#  . the last six characters of 'template' must be "XXXXXX" which will be replaced by a uniq string
#  . if template is not a pathname, the file will be created in ENVIRON["TMPDIR"] if set otherwise /tmp
#  . if template not provided defaults to "tmp.XXXXXX"                
#  . recommend don't use spaces or " or ' in pathname
#  . if type == f create a file
#  . if type == d create a directory
#  . if type == u return the name but create nothing
#
#  Example:                          
#     outfile = mktemp(meta "index.XXXXXX", "u")
#
#  Credit: https://github.com/e36freak/awk-libs   
#       
function mktemp(template, type,
                c, chars, len, dir, dir_esc, rstring, i, out, out_esc, umask,
                cmd) {

  # portable filename characters (added missing 7)
    c = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    len = split(c, chars, "")

  # make sure template is valid
    if (length(template)) {
        if (template !~ /XXXXXX$/) {
            return -1
        }

  # template was not supplied, use the default
    } else {
        template = "tmp.XXXXXX"
    }
  # make sure type is valid
    if (length(type)) {
        if (type !~ /^[fdu]$/) {
            return -1
        }
  # type was not supplied, use the default
    } else {
        type = "f"
    }
  # if template is a path...
    if (template ~ /\//) {
        dir = template
        sub(/\/[^/]*$/, "", dir)
        sub(/.*\//, "", template)
  # template is not a path, determine base dir
    } else {
        if (length(ENVIRON["TMPDIR"])) {
            dir = ENVIRON["TMPDIR"]
        } else {
            dir = "/tmp"
        }
    }

  # if this is not a dry run, make sure the dir exists
    if (type != "u" && ! exists2(dir)) {
        return -1
    }

  # get the base of the template, sans Xs (1-indexed for strict POSIX compliance)
    template = substr(template, 1, length(template) - 6)

  # generate the filename
    if (!_MKTEMP_SEEDED) {
        srand()
        _MKTEMP_SEEDED = 1
    }
    
    do {
        rstring = ""
        for (i=0; i<6; i++) {
            c = chars[int(rand() * len) + 1]
            rstring = rstring c
        }
        out = dir "/" template rstring
    } while( exists2(out) )

    if (type == "f") {
        printf "" > out
        close(out)
    } 

   # removed for wikiget
    #else if (type == "d") {
    #   mkdir(out)
    #}

    return out
}

# 
# isanumber() - return 1 if str is a positive whole number or 0
# 
#   Example:
#      "1234" == 1 / "0fr123" == 0 / 1.1 == 0 / -1 == 0 / 0 == 1
# 
function isanumber(str) {
    return (str ~ /^[0-9]+$/) ? 1 : 0
}

#  
# randomnumber() - return a random number between 1 to max
#
#  . robust awk random number generator works at nano-second speed and parallel simultaneous invocation
#  . requires global variable _cliff_seed 
#    should be defined one-time only eg. in the BEGIN{} section
#
function randomnumber(max,    i, randomArr) {

  # missing _cliff_seed fallback to less-robust rand() method
    if (empty(_cliff_seed)) 
        return randomnumber1(max)
    
  # create array of 1000 random numbers made by cliff_rand() method
    for (i = 0; i <= 1002; i++) 
        randomArr[i] = randomnumber2(max)
 
  # choose one at random using native rand()
    return randomArr[randomnumber1(1000)] 
 
}
function randomnumber1(max) {
    # Relies on the global srand() set in the BEGIN block
    return int( rand() * max)
}
function randomnumber2(max) {
    int( cliff_rand() * max)  # bypass first call
    return int( cliff_rand() * max)
}
#
#  cliff_rand()
#
#  Credit: https://www.gnu.org/software/gawk/manual/html_node/Cliff-Random-Function.html
#
function cliff_rand() {
    _cliff_seed = (100 * log(_cliff_seed)) % 1
    if (_cliff_seed < 0)
        _cliff_seed = - _cliff_seed
    return _cliff_seed
}

#                 
# stdErr() - print s to target destination
#
#  . if flag = "n" no newline
#  . routes to stderr, stdout, or appends to a file based on G["debug_dest"]
# 
function stdErr(s, flag) {
    if (G["debug_dest"] == "stderr" || empty(G["debug_dest"])) {
        if (flag == "n")
            printf("%s",s) > "/dev/stderr"
        else
            printf("%s\n",s) > "/dev/stderr"
    } 
    else if (G["debug_dest"] == "stdout") {
        if (flag == "n")
            printf("%s",s) > "/dev/stdout"
        else
            printf("%s\n",s) > "/dev/stdout"
    }
    else {
        if (flag == "n")
            printf("%s",s) >> G["debug_dest"]
        else
            printf("%s\n",s) >> G["debug_dest"]
        close(G["debug_dest"])
    }
}

# [[ ________ JSON ___________________________________________________________ ]]

#
#  query_json() and associate routines
#
#   From 'awkenough'
#
#	https://github.com/dubiousjim/awkenough
#
#   Copyright MIT license
#   Copyright (c) 2007-2011 Aleksey Cheusov <vle@gmx.net>
#   Copyright (c) 2012 Jim Pryor <dubiousjim@gmail.com>
#   Copyright (c) 2018 GreenC (User:GreenC at en.wikipedia.org)
#

#
#  Sample usage
#
# 1. Create a JSON file eg. 
#    wget -q -O- "https://en.wikipedia.org/w/api.php?action=query&titles=Public opinion on global warming|Pertussis&prop=info&format=json&utf8=&redirects" > o
# 2. In a test, view what the json-array looks like with dump() eg.
#      query_json(readfile("o"), jsona)
#      awkenough_dump(jsona, "jsona")
# 3. Use the created json-array (jsona) in a program 
#      if( query_json(readfile("o"), jsona) >= 0)
#        id = jsona["query","pages","25428398","pageid"]
#

function awkenough_die(msg) {
    printf("awkenough: %s\n", msg) > "/dev/stderr"
    # exit 1
}

function awkenough_assert(test, msg) {
    if (!test) awenough_die(msg ? msg : "assertion failed")
}

# unitialized scalar
function ismissing(u) {
    return u == 0 && u == ""
}

# explicit ""
function isnull(s, u) {
    if (u) return s == "" # accept missing as well
    return !s && s != 0
}

# populate array from str="key key=value key=value"
# can optionally supply "re" for equals, space; if they're the same or equals is "", array will be setlike
function awkenough_asplit(str, array,  equals, space,   aux, i, n) {
    n = split(str, aux, (space == "") ? "[ \n]+" : space)
    if (space && equals == space)
        equals = ""
    else if (ismissing(equals))
        equals = "="
    split("", array) # delete array
    for (i=1; i<=n; i++) {
        if (equals && match(aux[i], equals))
            array[substr(aux[i], 1, RSTART-1)] = substr(aux[i], RSTART+RLENGTH)
        else
            array[aux[i]]
    }
    split("", aux) # does it help to delete the aux array?
    return n
}

# behaves like gawk's split; special cases re == "" and " "
# unlike split, will honor 0-length matches
function awkenough_gsplit(str, items, re,  seps,   n, i, start, stop, sep1, sep2, sepn) {
    n = 0
    # find separators that don't occur in str
    i = 1
    do
        sep1 = sprintf("%c", i++)
    while (index(str, sep1))
    do
        sep2 = sprintf("%c", i++)
    while (index(str, sep2))
    sepn = 1
    split("", seps) # delete array
    if (ismissing(re))
        re = FS
    if (re == "") {
        split(str, items, "")
        n = length(str)
        for (i=1; i<n; i++)
            seps[i]
        return n
    }
    split("", items) # delete array
    if (re == " ") {
        re = "[ \t\n]+"
        if (match(str, /^[ \t\n]+/)) {
            seps[0] = substr(str, 1, RLENGTH)
            str = substr(str, RLENGTH+1)
        }
        if (match(str, /[ \t\n]+$/)) {
            sepn = substr(str, RSTART, RLENGTH)
            str = substr(str, 1, RSTART-1)
        }
    }
    i = gsub(re, sep1 "&" sep2, str)
    while (i--) {
        start = index(str, sep1)
        stop = index(str, sep2) - 1
        seps[++n] = substr(str, start + 1, stop - start)
        items[n] = substr(str, 1, start - 1)
        str = substr(str, stop + 2)
    }
    items[++n] = str
    if (sepn != 1) seps[n] = sepn
    return n
}


function parse_json(str, T, V,  slack,    c,s,n,a,A,b,B,C,U,W,i,j,k,u,v,w,root) {
    # use strings, numbers, booleans as separators
    # c = "[^\"\\\\[:cntrl:]]|\\\\[\"\\\\/bfnrt]|\\u[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]"
    c = "[^\"\\\\\001-\037]|\\\\[\"\\\\/bfnrt]|\\\\u[[:xdigit:]A-F][[:xdigit:]A-F][[:xdigit:]A-F][[:xdigit:]A-F]"
    s ="\"(" c ")*\""
    n = "-?(0|[1-9][[:digit:]]*)([.][[:digit:]]+)?([eE][+-]?[[:digit:]]+)?"

    root = awkenough_gsplit(str, A, s "|" n "|true|false|null", T)
    awkenough_assert(root > 0, "unexpected")

    # rejoin string using value indices
    str = ""
    for (i=1; i<root; i++)
        str = str A[i] i
    str = str A[root]

    # cleanup types and values
    for (i=1; i<root; i++) {
        if (T[i] ~ /^"/) {
            b = split(substr(T[i], 2, length(T[i])-2), B, /\\/)
            if (b == 0) v = ""
            else {
                v = B[1]
                k = 0
                for (j=2; j <= b; j++) {
                    u = B[j]
                    if (u == "") {
                       if (++k % 2 == 1) v = v "\\"
                    } else {
                        if (k % 2 == 1) {
                            v = v u
                        } else {
                            w = substr(u, 1, 1)  
                            if (w == "b") v = v "\b" substr(u, 2)
                            else if (w == "f") v = v "\f" substr(u, 2)
                            else if (w == "n") v = v "\n" substr(u, 2)
                            else if (w == "r") v = v "\r" substr(u, 2)
                            else if (w == "t") v = v "\t" substr(u, 2)
                            else v = v u
                        }
                        k = 0
                    }
                }
            }
            V[i] = v
            T[i] = "string"
        } else if (T[i] !~ /true|false|null/) {
            V[i] = T[i] + 0
            T[i] = "number"
        } else {
            V[i] = T[i]
        }
    }

    # sanitize string
    gsub(/[[:space:]]+/, "", str)
    if (str !~ /^[][{}[:digit:],:]+$/) {
        if (slack !~ /:/) return -1
        # handle ...unquoted:...
        a = awkenough_gsplit(str, A, "[[:alpha:]_][[:alnum:]_]*:", B)
        str = ""
        for (i=1; i < a; i++) {
            T[root] = "string"
            V[root] = substr(B[i], 1, length(B[i])-1)
            str = str A[i] root ":"
            root++
        }
        str = str A[a]
        if (str !~ /^[][{}[:digit:],:]+$/) return -10
    }

    # atomic value?
    a = awkenough_gsplit(str, A, "[[{]", B)
    if (A[1] != "") {
        if (a > 1) return -2
        else if (A[1] !~ /^[[:digit:]]+$/) return -3
        else return A[1]+0
    }

    # parse objects and arrays
    k = root
    C[0] = 0
    for (i=2; i<=a; i++) {
        T[k] = (B[i-1] ~ /\{/) ? "object" : "array"
        C[k] = C[0]
        C[0] = k
        u = awkenough_gsplit(A[i], U, "[]}]", W)
        awkenough_assert(u > 0, "unexpected")
        V[k++] = U[1]
        if (i < a && A[i] != "" && U[u] !~ /[,:]$/)
            return -4
        for (j=1; j<u; j++) {
            if (C[0] == 0 || T[C[0]] != ((W[j] == "}") ? "object" : "array")) return -5
            v = C[0]
            w = C[v]
            C[0] = w
            delete C[v]
            if (w) V[w] = V[w] v U[j+1]
        }
    }
    if (C[0] != 0) return -6

    # check contents
    for (i=root; i<k; i++) {
        if (T[i] == "object") {
            # check object contents
            b = split(V[i], B, /,/) 
            for (j=1; j <= b; j++) {
                if (B[j] !~ /^[[:digit:]]+:[[:digit:]]+$/)
                    return -7
                if (T[substr(B[j], 1, index(B[j],":")-1)] != "string")
                    return -8
            }
        } else if (V[i] != "") {
            # check array contents
            if (slack ~ /,/ && V[i] ~ /,$/)
                V[i] = substr(V[i], 1, length(V[i] -1))
            if (V[i] !~ /^[[:digit:]]+(,[[:digit:]]+)*$/)
                return -9
        }
    }
    return root
}

#
# Return a number < 0 on failure. Zero on success
#
function query_json(str, X,  root, slack,   T, V, A, B, C, i, j, k) {

    delete X
    k = parse_json(str, T, V, slack)
    if (k < 1) return k
    split(root, C, ".")
    j = 1
    while (j in C) {
        if (T[k] == "array")
            split(V[k], A, ",")
        else {
            split("", A)
            awkenough_asplit(V[k], B, ":", ",")
            for (i in B)
                A[V[i]] = B[i]
        }
        if (C[j] in A) {
            k = A[C[j]]
            j++
        } else return -11 # can't find requested root
    }
    # split("", B)
    # split("", C)
    split("", X)
    B[k] = ""
    C[k] = 0
    C[0] = k
    do {
        C[0] = C[k]
        delete C[k]
        j = T[k]
        if (j == "array") {
            j = split(V[k], A, ",")
            k = B[k] ? B[k] SUBSEP : ""
            X[k 0] = j
            for (i=1; i<=j; i++) {
               # push A[i] to C, (B[k],i) to B 
                C[A[i]] = C[0]
                B[A[i]] = k i
                C[0] = A[i]
            }
        } else if (j == "object") {
            awkenough_asplit(V[k], A, ":", ",")
            k = B[k] ? B[k] SUBSEP : ""
            for (i in A) {
                # push A[i] to C, (B[k],V[i]) to B 
                C[A[i]] = C[0]
                B[A[i]] = k V[i]
                C[0] = A[i]
            }
        } else if (j == "number") {
            X[B[k]] = V[k]
        } else if (j == "true") {
            X[B[k]] = 1
        } else if (j == "false") {
            X[B[k]] = 0
        } else if (j == "string") {
            X[B[k]] = V[k]
        } else {
            # null will satisfy ismissing()
            X[B[k]] 
        }
        k = C[0]
    } while (k)
    return 0
}

#
# Visually inspect array created by query_json()
#
function awkenough_dump(array, prefix, i,j,c,a,k,s,sep) {

    for (i in array) {
        j = i
        c = split(i, a, SUBSEP, sep)
        for (k = 1; k <= length(sep); k++) {
            gsub(/\\/, "\\", sep[k])
            gsub(/\//, "\\/", sep[k])
            gsub(/\t/, "\\t", sep[k])
            gsub(/\n/, "\\n", sep[k])
            gsub(/\r/, "\\r", sep[k])
            gsub(/\b/, "\\b", sep[k])
            gsub(/\f/, "\\f", sep[k])
            gsub(SUBSEP, ",", sep[k])          
            gsub(/[\001-\037]/, "¿", sep[k])   # TODO: convert to octal?
        }

        s = ""
        for (k = 1; k <= c; k++) 
            s = s "\"" a[k] "\"" sep[k]
        printf "%s[%s]=%s\n", prefix, s, array[i]
    }
}

#
# Given a JSON-array (jsonarr) created by query_json() producing:
#
#    jsona["query","pages","4035","pageid"]=8978 
# 
# Populate arr[] such that:
#
#    splitja(jsonarr, arr, 3, "pageid") ==>  arr["4035"]=8978
#
# indexn is the field # counting from left=>right - this becomes the index of arr
# value is the far-right (last) field name of the record for which the 8978 is assigned to arr[]
#
function splitja(jsonarr, arr, indexn, value) {

    delete arr                 
    for (ja in jsonarr) {
        c = split(ja, a, SUBSEP)
        if (a[c] == value) {
            arr[a[indexn]] = jsonarr[ja]
        }
    }
    return length(arr)
}

# [[ ________ Edit ___________________________________________________________ ]]


function setupEdit(   cookiejar) {

 # OAuth credentials

    if (empty(G["consumerKey"])) {
        stdErr("No account. See EDITSETUP for login/authentication info.")
        exit
    }

  # Where to store cookies

    cookiejar = "/tmp/cookiejar_" PROCINFO["pid"]
    cookieopt = " --save-cookies=\"" cookiejar "\" --load-cookies=\"" cookiejar "\""

  # Initialize random number generator

    if (empty(_cliff_seed))  # randomnumber() seed - initialize once
        _cliff_seed = "0.00" splitx(sprintf("%f", systime() * 0.000001), ".", 2)

  # Initialize external program dependencies

    setup("openssl")

  # Web agent support for Edit requests

    if (G["wta"] != "wget") {
        stdErr("Edit requires wget. Curl may be supported in a future version.")
        exit
    }

  # Adjust API URL for Oauth

    sub(/[?]$/, "", G["apiURL"])

}

function editPage(title,summary,page,    sp,jsona,data,command,postfile,errfile,fp,line,outfile,text) {

    if (page == "STDIN") {
        while ( (getline line < "/dev/stdin") > 0) 
            fp = fp line "\n"
        outfile = mktemp("wikigetstdinfile.XXXXXX", "f")
        print fp > outfile
        close(outfile)
        page = outfile
    }

    # Don't blank page
    text = urlencodeawk(readfile2(page), "rawphp")
    if (empty(text)) {
      print "No change (empty text)"
      if (outfile) removefile2(outfile)
      exit
    }

    data = strip("action=edit&bot=&format=json&text=" text "&title=" urlencodeawk(title, "rawphp") "&summary=" urlencodeawk(summary, "rawphp") "&token=" urlencodeawk(getEditToken()) )
    postfile = genPostfile(data)
    errfile = mktemp("wgeterr.XXXXXX", "f")
    command = apiurlPost(data, postfile, errfile)
    sp = sys2var(command)
    if (length(sp) == 0) {
        sp = readfile2(errfile)
    }
    removefile2(errfile)
    removefile2(cookiejar)

    # Sometimes when sending large files or when the Wikimedia servers are very busy, sp will come back blank even though the edit went through. 
    #  Your calling application should be prepared for getting a blank result string and try again. 
    #  It may fail on the second try due to "nochange" since it worked on the first round (but returned a blank result string)

    if (G["debug"]) {
        print "\nEDITARTICLE\n------"
        print command
        print "   ---JSON---"
        query_json(sp, jsona)
        awkenough_dump(jsona, "jsona")
        print "   ---RAW---"
        print sp 
    }
    if (! G["debug"]) {
        removefile2(postfile)
        removefile2(outfile)
    }

    printResult(sp)

}

function getEditToken(  sp,jsona,command,data,i) {

    setupEdit()
    data = "action=query&format=json&meta=tokens"
    command = apiurl(data)

    for (i = 1; i <= 3; i++) {
        sp = sys2var(command)
        query_json(sp, jsona)
        
        if (!empty(jsona["query","tokens","csrftoken"])) {
            return jsona["query","tokens","csrftoken"]
        }
        
        if (G["debug"]) {
            stdErr("getEditToken: Failed to fetch token. Retrying... (" i "/3)")
        }
        system("sleep 5")
    }

    stdErr("Fatal: Unable to retrieve edit token from API. Response: " substr(sp, 1, 100))
    exit 1
}

function movePage(from,to,reason,    sp,jsona,data,command) {

    setupEdit()
    data = strip("action=move&format=json&from=" urlencodeawk(from, "rawphp") "&to=" urlencodeawk(to, "rawphp") "&reason=" urlencodeawk(reason, "rawphp") "&movetalk=&token=" urlencodeawk(getEditToken()) )
    command = apiurl(data)
    sp = sys2var(command)
    removefile2(cookiejar)

    if (G["debug"]) {
        print "\nMOVEARTICLE\n------"
        print command
        print "   ---JSON---"
        query_json(sp, jsona)
        awkenough_dump(jsona, "jsona")
        print "   ---RAW---"
        print sp 
    }

    printResult(sp)

}

#
# purgePage() - issue a purge on a page title
#  https://www.mediawiki.org/wiki/API:Purge
#
function purgePage(title,    sp,jsona,data,command,errfile,postfile) {

    setupEdit()
    data = strip("action=purge&titles=" urlencodeawk(title, "rawphp") "&format=json")
    postfile = genPostfile(data)
    errfile = mktemp("wgeterr.XXXXXX", "f")
    command = apiurlPost(data, postfile, errfile)
    sp = sys2var(command)
    if (length(sp) == 0) {
        sp = readfile2(errfile)
    }
    removefile2(errfile)
    removefile2(cookiejar)

    if (G["debug"]) {
        print "\nPURGEARTICLE\n------"
        print command
        print "   ---JSON---"
        query_json(sp, jsona)
        awkenough_dump(jsona, "jsona")
        print "   ---RAW---"
        print sp 
    }
    if (! G["debug"]) {
        removefile2(postfile)
        removefile2(outfile)
    }

    printResult(sp)

}

#
# nulleditPage() - issue a null edit on a page title to update category links
#  https://www.mediawiki.org/wiki/API:Edit
#
function nulleditPage(title,    sp,jsona,data,command,postfile,errfile) {

    # prependtext= with no value forces a null edit without needing to fetch the page content
    data = strip("action=edit&title=" urlencodeawk(title, "rawphp") "&prependtext=&nocreate=1&format=json&token=" urlencodeawk(getEditToken()) )
    postfile = genPostfile(data)
    errfile = mktemp("wgeterr.XXXXXX", "f")
    command = apiurlPost(data, postfile, errfile)
    sp = sys2var(command)
    if (length(sp) == 0) {
        sp = readfile2(errfile)
    }
    removefile2(errfile)
    removefile2(cookiejar)

    if (G["debug"]) {
        print "\nNULLEDITARTICLE\n------"
        print command
        print "   ---JSON---"
        query_json(sp, jsona)
        awkenough_dump(jsona, "jsona")
        print "   ---RAW---"
        print sp 
    }
    if (! G["debug"]) {
        removefile2(postfile)
    }

    # Intercept the generic "nochange" JSON payload for better UX
    query_json(sp, jsona)
    if (jsona["edit","result"] ~ /[Ss]uccess/) {
        print "Null edit success: " title
    } else {
        printResult(sp) # Fallback to standard error printing
    }

}

# ___ Raw API URL (-U) 

#
# Send a raw, custom request directly to the authenticated fetcher
#
function rawAPI(url,   results) {

        # If it's not a full HTTP link, assume it's a query string and prepend the base API URL
        if (url !~ /^https?:\/\//) {
            # Strip leading ? or & just in case the user typed it
            sub(/^[?&]/, "", url)
            url = G["apiURL"] url
        }

        # Fetch using the hardened, OAuth-aware engine
        results = http2var(url)

        if (!empty(results))
            print results
        else
            stdErr("No response or fatal HTTP error.")
}

#
# userInfo() - user info via API
#  https://www.mediawiki.org/wiki/API:userinfo
#
function userInfo(  sp,jsona,command,data) {

    setupEdit()
    data = "action=query&meta=userinfo&uiprop=" urlencodeawk("rights|groups|blockinfo") "&format=json"
    command = apiurl(data)
    sp = sys2var(command)
    removefile2(cookiejar)
    
    if (G["debug"]) {
        print "\nUSERINFO\n------"
        print command
        print "   ---JSON---"
        query_json(sp, jsona)
        awkenough_dump(jsona, "jsona")
        print "   ---RAW---"
        print sp 
    } else {
        # Print the raw JSON payload to stdout for normal CLI usage
        if (!empty(sp))
            print sp
        else
            stdErr("No response or HTTP error.")
    }
}

#
# printResult() - print result of action
#
function printResult(json,  jsona,nc,sc,arr) {

    query_json(json, jsona)

    for (k in jsona) {
         if(k ~ "nochange")
         nc++                        
    }
    if (jsona["edit","result"] ~ /[Ss]uccess/)
        sc++

    if (sc && nc)                      
        print "No change"     
    else if(sc)
        print jsona["edit","result"]
    else {
      if(! empty(jsona["error","info"])) 
        print jsona["error","info"]
      else if(! empty(jsona["edit","spamblacklist"]))
        print jsona["edit","spamblacklist"]
      else if( !empty(jsona["move","from"]) && !empty(jsona["move","to"]) )
        print "Page moved from " shquote(jsona["move","from"]) " -> " shquote(jsona["move","to"])
      else if( match(json, /"purged"/) && match(json, /"title":"([^"]+)"/, arr) )
        print "Page purged: " arr[1]
      else {
        # --- Raw Payload & HTTP Status Inspection ---
        if (length(json) == 0) {
            print "Empty response from Wikipedia (Possible dropped connection)"
        } else if (match(json, /ERROR ([0-9]{3}):? ([^\n]*)/, arr)) {
            print "HTTP Error: " arr[1] " - " arr[2]
        } else if (json ~ /<html/ || json ~ /<!DOCTYPE/ || json ~ /<title>/) {
            if (match(json, /<title>([^<]*)<\/title>/, arr)) {
                print "HTTP Error: " arr[1]
            } else {
                print "HTTP Error: Received HTML instead of JSON. Server likely overloaded."
            }
        } else {
            print "Unknown error. Raw response snippet: " substr(json, 1, 100)
        }
      }
    }
}
        

#
# genPostfile() - generate postfile wget
#
function genPostfile(data,  outfile) {

    outfile = mktemp("wikigetpostfile.XXXXXX", "f")
    printf("%s", data) > outfile
    close(outfile)
    return outfile
}

#
# apiurl() - build a URL to the API using given post data 
#
function apiurl(data,  command, auth_header, header_cmd, final_url) {

    auth_header = strip(oauthHeader(data))
    header_cmd = " --header=" shquote("Content-Type: application/x-www-form-urlencoded")

    # Route through custom tfproxy proxy if enabled
    if (G["tfproxy"] == 1 && G["tfproxy_pass"] != "") {
        final_url = G["tfproxy_url"] urlencodeawk(G["apiURL"])
        gsub(/^Authorization: /, "X-WMF-OAuth: ", auth_header)
        header_cmd = header_cmd " --header=" shquote(G["tfproxy_header"] ": " G["tfproxy_pass"])
    } else {
        final_url = G["apiURL"]
    }

    header_cmd = header_cmd " --header=" shquote(auth_header)

    command = G["timeout"] " wget --tries=3 --timeout=120 --waitretry=60 --retry-connrefused --retry-on-http-error=429,502,503,504 --user-agent=" shquote(G["agent"]) " " cookieopt header_cmd " --post-data=" shquote(data) " -q -O- " shquote(final_url)
    
    if (G["debug"])
        stdErr(command)
    return command
}

#
# apiurlPost() - build a URL to the API using a file for post data 
#
function apiurlPost(data, postfile, errfile,  command, auth_header, header_cmd, final_url) {

    auth_header = strip(oauthHeader(data))
    header_cmd = " --header=" shquote("Content-Type: application/x-www-form-urlencoded")

    # Route through custom tfproxy proxy if enabled
    if (G["tfproxy"] == 1 && G["tfproxy_pass"] != "") {
        final_url = G["tfproxy_url"] urlencodeawk(G["apiURL"])
        gsub(/^Authorization: /, "X-WMF-OAuth: ", auth_header)
        header_cmd = header_cmd " --header=" shquote(G["tfproxy_header"] ": " G["tfproxy_pass"])
    } else {
        final_url = G["apiURL"]
    }

    header_cmd = header_cmd " --header=" shquote(auth_header)

    command = G["timeout"] " wget --tries=3 --timeout=120 --waitretry=60 --retry-connrefused --retry-on-http-error=429,502,503,504 --user-agent=" shquote(G["agent"]) " " cookieopt header_cmd " --post-file=" shquote(postfile) " -q -O- " shquote(final_url) " 2> " shquote(errfile)
    
    if (G["debug"])
        stdErr(command)
    return command
}

#
# oauthHeader() - retrieve OAuth header
#
function oauthHeader(data,   sp) {

    sp = MWOAuthGenerateHeader(G["consumerKey"], G["consumerSecret"], G["accessKey"], G["accessSecret"], G["apiURL"], "POST", data)
    if (empty(sp))
        stdErr("oauthHeader(): unable to determine header")
    return sp
}

# MWOAuthGenerateHeader() - MediaWiki Generate OAuth Header
#
#   . requires openssl
#
function MWOAuthGenerateHeader(consumerKey, consumerSecret, accessKey, accessSecret, url, method, data,

                               nonce,headerParams,dataArr,allParamsJoined,k,i,j,url2,
                               signatureBaseParts,signatureBaseString,cmd,header,save_sorted,
                               decodedDataArr) {

  # sort associative arrays by index string ascending
    if ("sorted_in" in PROCINFO)               
        save_sorted = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = "@ind_str_asc"

  # Generate 32 characters of pure cryptographic randomness - guaranteed never to collide
    nonce = strip(sys2var("openssl rand -hex 16"))

    asplit(headerParams, "oauth_consumer_key=" consumerKey " oauth_token=" accessKey " oauth_signature_method=HMAC-SHA1 oauth_timestamp=" systime() " oauth_nonce=" nonce " oauth_version=1.0") 

  # 1. Parse the incoming query parameters
    asplit(dataArr, data, "=", "&")

  # 2. Decode then strictly re-encode the query params (normalizes %2D to -, %20 to %20, etc.)
    for (k in dataArr) {
        decodedDataArr[urlencodeawk(urldecodeawk(k), "rawphp")] = urlencodeawk(urldecodeawk(dataArr[k]), "rawphp")
    }

  # 3. Strictly encode the OAuth header params and add them to the signature pool
    for (k in headerParams) {
        decodedDataArr[urlencodeawk(k, "rawphp")] = urlencodeawk(headerParams[k], "rawphp")
    }

  # 4. Build the sorted parameter string
    for (k in decodedDataArr) 
        allParamsJoined[i++] = k "=" decodedDataArr[k]

    url2 = urlElement(url, "scheme") "://" tolower(urlElement(url, "netloc")) urlElement(url, "path")

  # 5. Build Signature Base String
    signatureBaseParts[0] = toupper(method)
    signatureBaseParts[1] = url2
    signatureBaseParts[2] = join(allParamsJoined, 0, length(allParamsJoined) - 1, "&")

    signatureBaseString = urlencodeawk(signatureBaseParts[0], "rawphp") "&" urlencodeawk(signatureBaseParts[1], "rawphp") "&" urlencodeawk(signatureBaseParts[2], "rawphp")

  # Generate HMAC binary and pipe directly to base64 in the shell
    cmd = "openssl sha1 -hmac " shquote(urlencodeawk(consumerSecret, "rawphp") "&" urlencodeawk(accessSecret, "rawphp")) " -binary | openssl base64"
    headerParams["oauth_signature"] = strip(sys2varPipe(signatureBaseString, cmd))

  # Build final Authorization header
    for (k in headerParams) 
        header[j++] = urlencodeawk(k, "rawphp") "=\"" urlencodeawk(headerParams[k], "rawphp") "\""

    if (save_sorted)
        PROCINFO["sorted_in"] = save_sorted
    else
        PROCINFO["sorted_in"] = ""

    return sprintf("%s", "Authorization: OAuth " join(header, 0, length(header) - 1, ", "))
}
