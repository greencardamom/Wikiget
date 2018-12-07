#!/usr/local/bin/awk -bE

#
# Wikiget - command-line access to Wikimedia API read/write functions
#           https://github.com/greencardamom/Wikiget
#

# The MIT License (MIT)
#
# Copyright (c) 2016-2018 by User:GreenC (at en.wikipedia.org)
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

BEGIN {

    _defaults = "contact   = User:GreenC -> en.wikipedia.org \
                 program   = Wikiget \
                 version   = 1.10 \
                 copyright = 2016-2018 \
                 agent     = " G["program"] " " G["version"] " " G["contact"] "\
                 maxlag    = 5 \
                 lang      = en \
                 project   = wikipedia"

    asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
                                 
    setup("wget curl lynx")                                     # Use one of wget, curl or lynx - searches PATH in this order
                                                                #  They do the same, need at least one available in PATH
                                                                #  For edit (-E) wget is required
    Optind = Opterr = 1                                         
    parsecommandline()

}

# [[ ________ Command line parsing and argument processing ___________________ ]]

#
# parsecommandline() - parse command-line
#
function parsecommandline(c,opts,Arguments) {

    while ((c = getopt(ARGC, ARGV, "yrhVfjpdo:k:a:g:i:s:e:u:m:b:l:n:w:c:t:q:x:z:F:E:S:P:I:R:T:A")) != -1) {
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

        if (c == "I")                                 #  -I              User info
            Arguments["main_c"] = "I"

        if (c == "m")                                 #  -m <maxlag>     Maxlag setting when using API, default set in BEGIN{} section
            Arguments["maxlag"] = verifyval(Optarg)
        if (c == "l")                                 #  -l <lang>       Language code, default set in BEGIN{} section
            Arguments["lang"] = verifyval(Optarg)
        if (c == "z")                                 #  -z <project>    Project name, default set in BEGIN{} section
            Arguments["project"] = verifyval(Optarg)
        if (c == "y")                                 #  -y              Show debugging info to stderr
            Arguments["debug"] = 1
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

    if (length(Arguments["lang"]) > 0)                                # Check options, set defaults
        G["lang"] = Arguments["lang"]
        # default set in BEGIN{}

    if (length(Arguments["project"]) > 0)                             # Check options, set defaults
        G["project"] = Arguments["project"]
        # default set in BEGIN{}

    if (isanumber(Arguments["maxlag"])) 
        G["maxlag"] = Arguments["maxlag"]
        # default set in BEGIN{}

    if (isanumber(Arguments["maxsearch"])) 
        G["maxsearch"] = Arguments["maxsearch"]
    else
        G["maxsearch"] = 10000

    if (isanumber(Arguments["namespace"])) 
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

    if (Arguments["debug"])                                    # Enable debugging
        G["debug"] = 1

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
    else if (Arguments["main_c"] == "R") {                     # move page
        if (empty(Arguments["moveto"]))
            usage(1)
        movePage(Arguments["movefrom"], Arguments["moveto"])
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
    print " User contributions:"
    print "       -u <username>    Username without User: prefix"
    print "         -s <starttime> Start time in YMD format (-s 20150101). Required with -u"
    print "         -e <endtime>   End time in YMD format (-e 20151231). If same as -s," 
    print "                         does 24hr range. Required with -u"
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
    print " Recent changes:"
    print "       -r               Recent changes (past 30 days) aka Special:RecentChanges" 
    print "                         Either -o or -t required"
    print "         -o <username>  Only list changes made by this user"
    print "         -k <tag>       Only list changes tagged with this tag"
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
    print "       -A               Print list of all page titles (possibly very large list)" 
    print "         -t <# type>    1=All, 2=Skip redirects, 3=Only redirects. Default: 2"
    print "         -n <namespace> (option) Pipe-separated numeric value(s) of namespace"
    print "                         Only list pages in this namespace. Default: 0"
    print "                         See -h for NS codes and examples"
    print ""
    print " Edit page (experimental):"
    print "       -E <title>       Edit a page with this title. Requires -S and -P"
    print "         -S <summary>   Edit summary"
    print "         -P <filename>  Page content filename. If \"STDIN\" read from stdin"
    print "                         See EDITSETUP for authentication configuration"
    print ""
    print "       -R <page>        Move from page name. Requires -T"
    print "         -T <page>      Move to page name"
    print ""
    print "       -I               Show OAuth userinfo"
    print ""
    print " Global options:"
    print "       -l <language>    Wiki language code (default: " G["lang"] ")" 
    print "                         See https://en.wikipedia.org/wiki/List_of_Wikipedias"
    print "       -z <project>     Wiki project (default: " G["project"] ")"
    print "                         https://en.wikipedia.org/wiki/Wikipedia:Wikimedia_sister_projects"
    print "       -m <#>           API maxlag value (default: " G["maxlag"] ")"
    print "                         See https://www.mediawiki.org/wiki/API:Etiquette#Use_maxlag_parameter"
    print "       -y               Print debugging to stderr (show URLs sent to API)"
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
    print "   articles only"
    print "     wikiget -u \"Jimbo Wales\" -s 20010911 -e 20010930 -n 0"
    print "   talk pages only"
    print "     wikiget -u \"Jimbo Wales\" -s 20010911 -e 20010930 -n 1"
    print "   talk and articles only"
    print "     wikiget -u \"Jimbo Wales\" -s 20010911 -e 20010930 -n \"0|1\""
    print ""
    print "   -n codes: https://www.mediawiki.org/wiki/Extension_default_namespaces"
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
    print " Recent changes:"
    print "   recent changes in last 30 days tagged with this ID"
    print "     wikiget -r -k \"OAuth CID: 678\""
    print ""
    print " All pages:"
    print "   all page titles excluding redirects w/debug tracking progress"
    print "     wikiget -A -t 2 -y > list.txt"
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
    print ""
 
}
function version() {
    print G["program"] " " G["version"]
    print "Copyright (C) 2016-2018 User:GreenC (en.wikipedia.org)"
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
function files_verify(files_system,    a, i, missing) {

    missing = 0
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
 
        url = G["apiURL"] "action=query&list=categorymembers&cmtitle=" urlencodeawk(entity) "&cmtype=" urlencodeawk(ct) "&cmprop=title&cmlimit=500&format=json&formatversion=2&maxlag=" G["maxlag"]

        results = uniq(getcategory(url, entity) )

        if ( length(results) > 0)
            print results
        return length(results)
}
function getcategory(url, entity,   jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin, "cmcontinue")
        while ( continuecode ) {
            url = G["apiURL"] "action=query&list=categorymembers&cmtitle=" urlencodeawk(entity) "&cmtype=page&cmprop=title&cmlimit=500&format=json&formatversion=2&maxlag=" G["maxlag"] "&continue=-||&cmcontinue=" continuecode 
            jsonin = http2var(url)
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
          url = G["apiURL"] "action=query&list=exturlusage&euprotocol=" urlencodeawk(a[i]) "&euexpandurl=&euquery=" urlencodeawk(entity) "&euprop=title&eulimit=500&eunamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"]
          results = results "\n" getxlinks(url, entity, "http") 
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

        while ( continuecode ) {
            url = G["apiURL"] "action=query&list=exturlusage&euprotocol=" urlencodeawk(euprotocol) "&euexpandurl=&euquery=" urlencodeawk(entity) "&euprop=title&eulimit=500&eunamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"] "&continue=" urlencodeawk("-||") "&eucontinue=" urlencodeawk(continuecode, "rawphp")
            jsonin = http2var(url)
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

        url = G["apiURL"] "action=query&list=recentchanges&rcprop=title" entity "&rclimit=500&rcnamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"]

        results = uniq( getrechanges(url, entity) )

        if ( length(results) > 0) 
            print results
        return length(results)
}
function getrechanges(url, entity,         jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin,"rccontinue")

        while ( continuecode ) {
            url = G["apiURL"] "action=query&list=recentchanges&rcprop=title" entity "&rclimit=500&continue=" urlencodeawk("-||") "&rccontinue=" urlencodeawk(continuecode) "&rcnamespace=" urlencodeawk(G["namespace"]) "&format=json&formatversion=2&maxlag=" G["maxlag"]
            jsonin = http2var(url)
            jsonout = jsonout "\n" json2var(jsonin)
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

        url = G["apiURL"] "action=query&list=usercontribs&ucuser=" urlencodeawk(entity) "&uclimit=500&ucstart=" urlencodeawk(sdate) "&ucend=" urlencodeawk(edate) "&ucdir=newer&ucnamespace=" urlencodeawk(G["namespace"]) "&ucprop=" urlencodeawk("title|parsedcomment") "&format=json&formatversion=2&maxlag=" G["maxlag"]

        results = uniq( getucontribs(url, entity, sdate, edate) )

        if ( length(results) > 0) 
            print results
        return length(results)
}
function getucontribs(url, entity, sdate, edate,         jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin,"uccontinue")

        while ( continuecode ) {
            url = G["apiURL"] "action=query&list=usercontribs&ucuser=" urlencodeawk(entity) "&uclimit=500&continue=" urlencodeawk("-||") "&uccontinue=" urlencodeawk(continuecode) "&ucstart=" urlencodeawk(sdate) "&ucend=" urlencodeawk(edate) "&ucdir=newer&ucnamespace=" urlencodeawk(G["namespace"]) "&ucprop=" urlencodeawk("title|parsedcomment") "&format=json&formatversion=2&maxlag=" G["maxlag"]
            jsonin = http2var(url)
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin,"uccontinue")
        }

        return jsonout
}

# ___ Forward links (-F) 

#
# MediaWiki API:Parsing_wikitext
#  https://www.mediawiki.org/wiki/API:Parsing_wikitext
#
function forlinks(entity,sdate,edate,      url,jsonin,jsonout) {

        url = G["apiURL"] "action=parse&prop=" urlencodeawk("links") "&page=" urlencodeawk(entity) "&format=json&formatversion=2&maxlag=" G["maxlag"]
        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        if ( length(jsonout) > 0) 
            print jsonout
        return length(jsonout)       
}

# ___ Backlinks (-b) 

#
# MediaWiki API:Backlinks
#  https://www.mediawiki.org/wiki/API:Backlinks
#
function backlinks(entity,      url, blinks) {

        if (G["bltypes"] ~ /n/) {
            url = G["apiURL"] "action=query&list=backlinks&bltitle=" urlencodeawk(entity) "&blnamespace=" urlencodeawk(G["namespace"]) "&blredirect&bllimit=250&continue=&blfilterredir=nonredirects&format=json&formatversion=2&maxlag=" G["maxlag"]
            blinks = getbacklinks(url, entity, "blcontinue") # normal backlinks
        }

        if ( entity ~ /^[Tt]emplate[:]/ && G["bltypes"] ~ /t/) {    # transclusion backlinks
            url = G["apiURL"] "action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&continue=&eilimit=500&format=json&formatversion=2&maxlag=" G["maxlag"]
            if (length(blinks) > 0)
                blinks = blinks "\n" getbacklinks(url, entity, "eicontinue")
            else
                blinks = getbacklinks(url, entity, "eicontinue")
        } 
        else if ( entity ~ /^[Ff]ile[:]/ && G["bltypes"] ~ /f/) { # file backlinks
            url = G["apiURL"] "action=query&list=imageusage&iutitle=" urlencodeawk(entity) "&iunamespace=" urlencodeawk(G["namespace"]) "&iuredirect&iulimit=250&continue=&iufilterredir=nonredirects&format=json&formatversion=2&maxlag=" G["maxlag"]
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

        while ( continuecode ) {

            if ( method == "eicontinue" )
                url = G["apiURL"] "action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&eilimit=500&continue=" urlencodeawk("-||") "&eicontinue=" urlencodeawk(continuecode) "&format=json&formatversion=2&maxlag=" G["maxlag"]
            if ( method == "iucontinue" )
                url = G["apiURL"] "action=query&list=imageusage&iutitle=" urlencodeawk(entity) "&iunamespace=" urlencodeawk(G["namespace"]) "&iuredirect&iulimit=250&continue=" urlencodeawk("-||") "&iucontinue=" urlencodeawk(continuecode) "&iufilterredir=nonredirects&format=json&formatversion=2&maxlag=" G["maxlag"]
            if ( method == "blcontinue" )
                url = G["apiURL"] "action=query&list=backlinks&bltitle=" urlencodeawk(entity) "&blnamespace=" urlencodeawk(G["namespace"]) "&blredirect&bllimit=250&continue=" urlencodeawk("-||") "&blcontinue=" urlencodeawk(continuecode) "&blfilterredir=nonredirects&format=json&formatversion=2&maxlag=" G["maxlag"]

            jsonin = http2var(url)
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
function wikitextplain(namewiki,   command,f,r,redirurl,xmlin,i,c,b,k) {

        command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(strip(namewiki)) "&action=raw"
        f = http2var(command)
        if (length(f) < 5) 
            return ""
        if (tolower(f) ~ /[#][ ]{0,}redirect[ ]{0,}[[]/ && G["followredirect"] == "true") {
            match(f, /[#][ ]{0,}[Rr][Ee][^]]*[]]/, r)
            gsub(/[#][ ]{0,}[Rr][Ee][Dd][Ii][^[]*[[]/,"",r[0])
            redirurl = strip(substr(r[0], 2, length(r[0]) - 2))
            command = G["apiURL"] "format=xml&action=query&prop=extracts&exlimit=1&explaintext&titles=" urlencodeawk(redirurl) 
            xmlin = http2var(command)
        }
        else {
            command = G["apiURL"] "format=xml&action=query&prop=extracts&exlimit=1&explaintext&titles=" urlencodeawk(namewiki)
            xmlin = http2var(command)
        }

        if (apierror(xmlin, "xml") > 0) {
            return ""
        }
        else {
            c = split(convertxml(xmlin), b, "<extract[^>]*>")
            i = 1
            while (i++ < c) {
                k = substr(b[i], 1, match(b[i], "</extract>") - 1)
                return strip(k)
            }
        }
}

function wikitext(namewiki,   command,f,r,redirurl) {

        command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(strip(namewiki)) "&action=raw"
        f = http2var(command)
        if (length(f) < 5) 
            return ""

        if (tolower(f) ~ /[#][ ]{0,}redirect[ ]{0,}[[]/ && G["followredirect"] == "true") {
            match(f, /[#][ ]{0,}[Rr][Ee][^]]*[]]/, r)
            gsub(/[#][ ]{0,}[Rr][Ee][Dd][Ii][^[]*[[]/,"",r[0])
            redirurl = strip(substr(r[0], 2, length(r[0]) - 2))
            command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(redirurl) "&action=raw"
            f = http2var(command)
        }
        if (length(f) < 5)
            return ""
        else
            return f
}

# ___ All pages (-A)

#
# MediaWiki API: Allpages
#  https://www.mediawiki.org/wiki/API:Allpages
#
function allPages(redirtype,    url,results,apfilterredir) {

        if(redirtype == "1")
          apfilterredir = "&apfilterredir=all"
        else if(redirtype == "2")
          apfilterredir = "&apfilterredir=nonredirects"
        else if(redirtype == "3")
          apfilterredir = "&apfilterredir=redirects"
        else
          apfilterredir = "&apfilterredir=nonredirects"

        url = G["apiURL"] "action=query&list=allpages&aplimit=500" apfilterredir "&apnamespace=" urlencodeawk(G["namespace"], "rawphp") "&format=json&formatversion=2&maxlag=" G["maxlag"]

        results = uniq( getallpages(url, apfilterredir) )

        if ( length(results) > 0) 
            print results
        return length(results)
}
function getallpages(url,apfilterredir,         jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin,"apcontinue")

        while ( continuecode ) {
            url = G["apiURL"] "action=query&list=allpages&aplimit=500" apfilterredir "&apnamespace=" urlencodeawk(G["namespace"], "rawphp") "&apcontinue=" urlencodeawk(continuecode, "rawphp") "&continue=" urlencodeawk("-||") "&format=json&formatversion=2&maxlag=" G["maxlag"]
            jsonin = http2var(url)
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin,"apcontinue")
        }
        return jsonout
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
            xmlout = xmlout "\n" parsexmlsearch(xmlin)
            offset = getoffsetxml(xmlin)
            retrieved = retrieved + 50
            if (retrieved > G["maxsearch"] && G["maxsearch"] != 0)
                return trimxmlout(xmlout, G["maxsearch"])
        }

        return xmlout
} 
function parsexmlsearch(xmlin,   f,g,e,c,a,i,out,snippet,title) {

        if (xmlin ~ /error code="maxlag"/) {
            stdErr("Max lag (" G["maxlag"] ") exceeded - aborting. Try again when API servers are less busy, or increase Maxlag (-m)")
            exit
        }

        f = split(xmlin,e,/<search>|<\/search>/)
        c = split(e[2],a,"/>")  

        while (++i < c) {
            if (a[i] ~ /title[=]/) {
                match(a[i], /title="[^\"]*"/,k)
                split(gensub("title=","","g",k[0]), g, "\"")
                title = convertxml(g[2])
                match(a[i], /snippet="[^\"]*"/,k)
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
function getoffsetxml(xmlin,  a) {

        if ( match(xmlin, /<continue sroffset[=]"[0-9]{1,}"/, offset) > 0) {     
            split(offset[0],a,/"/)
            return a[2]
        }
        else 
            return ""
}
function trimxmlout(xmlout, max,   c,a,i) {

        if ( split(xmlout, a, "\n") > 0) {
            while (i++ < max) 
                out = out a[i] "\n"
            return out
        }
}
function totalhits(xmlin) {

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
# json2var - given raw json extract field "title" and convert to \n seperated string
#
function json2var(json,  jsona,arr) {
    if (query_json(json, jsona) >= 0) {
        splitja(jsona, arr, 3, "title")
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
        return 0
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
            if (match(input, /"error"[:]{"code"[:]"[^\"]*","info"[:]"[^\"]*"/, code) > 0) {
                stdErr(pre code[0])
                return 1
            }
        }
        else if (type == "xml") {
            if (match(input, /error code[=]"[^\"]*" info[=]"[^\"]*"/, code) > 0) {
                stdErr(re code[0])
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
        while (i++ < c) {
            gsub(/\\["]/,"\"",b[i])
            if (b[i] ~ "for API usage") { # Max lag exceeded.
                stdErr("\nMax lag (" G["maxlag"] ") exceeded - aborting. Try again when API servers are less busy, or increase Maxlag (-m)")
                exit
            }
            if (b[i] == "")
                continue
            if (x[b[i]] == "")
                x[b[i]] = b[i]
        }
        delete b # free memory
        return join2(x,"\n")
}


#
# Webpage to variable. url is assumed to be percent encoded.
#
function http2var(url) {

        if (G["debug"])
            print url > "/dev/stderr"

        if (G["wta"] == "wget") 
            return sys2var("wget --no-check-certificate --user-agent=\"" G["agent"] "\" -q -O- -- " shquote(url) )
        else if (G["wta"] == "curl")
            return sys2var("curl -L -s -k --user-agent \"" G["agent"] "\" -- " shquote(url) )
        else if (G["wta"] == "lynx")
            return sys2var("lynx -source -- " shquote(url) )
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
function urlElement(url,element,   a,scheme,netloc,tail,b,fragment,query,path) {

  if(url ~ /^\/\//)        # Protocol-relative - assume http
    url = "http:" url

  split(url, a, /\//)

  scheme = substr(a[1], 0, index(a[1], ":") -1)
  netloc = a[3]

  tail = subs(scheme "://" netloc, "", url)

  splits(tail, b, "#")
  if(!empty(b[2]))
    fragment = b[2]

  splits(tail, b, "?")
  if(!empty(b[2])) {
    query = b[2]
    if(!empty(fragment))
      query = subs("#" fragment, "", query)
  }

  path = tail
  if(!empty(fragment))
    path = subs("#" fragment, "", path)
  if(!empty(query))
    path = subs("?" query, "", path)
    
  if(element == "scheme")
    return scheme
  else if(element == "netloc")
    return netloc
  else if(element == "path")
    return path
  else if(element == "query")
    return query
  else if(element == "fragment")
    return fragment

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
        re = "[0-9A-Za-z]"

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
#      then b takes precendent eg. c["1"] = 3
#
function concatarray(a,b,c) {

    delete c          
    for (i in a)       
        c[i]=a[i]
    for (i in b)    
       c[i]=b[i]       
}                

#
# splitx() - split str along re and return num'th element
#
#   Example:
#      print splitx("a:b:c:d", "[:]", 3) ==> "c"
#
function splitx(str, re, num,    a){
    if(split(str, a, re))
        return a[num] 
    else               
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
    system("") # Flush buffer
    if (exists2(str)) {
      sys2var("rm -r -- " shquote(str) )
      system("")
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

    if ((getline line < file) == -1 ) {
        msg = (ERRNO ~ /Permission denied/ || ERRNO ~ /a directory/) ? 1 : 0
        close(file)
        return msg
    }
    else {
        close(file)
        return 1
    }
}

#           
# empty() - return 0 if string is 0-length      
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
function shquote(str,  safe) {      
    safe = str                      
    gsub(/'/, "'\\''", safe)          
    gsub(/’/, "'\\’'", safe)
    return "'" safe "'"                 
}

#   
# convertxml() - convert XML to plain
#
function convertxml(str,   safe) {  
    safe = str                      
    gsub(/&lt;/,"<",safe)             
    gsub(/&gt;/,">",safe)
    gsub(/&quot;/,"\"",safe)            
    gsub(/&amp;/,"\\&",safe)
    gsub(/&#039;/,"'",safe)
    gsub(/&#10;/,"'",safe)
    return safe
}

# 
# strip() - strip leading/trailing whitespace
#   
#   . faster than the gsub() or gensub() methods eg.
#        gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
#        gensub(/^[[:space:]]+|[[:space:]]+$/,"","g",s)
#
#   Credit: https://github.com/dubiousjim/awkenough by Jim Pryor 2012
#
function strip(str) {               
    if (match(str, /[^ \t\n].*[^ \t\n]/))      
        return substr(str, RSTART, RLENGTH)
    else if (match(str, /[^ \t\n]/))
        return substr(str, RSTART, 1)
    else
        return ""      
}

#   
# join() - merge an array of strings into a single string. Array indice are numbers.
# 
#   Credit: /usr/local/share/awk/join.awk by Arnold Robbins 1999
# 
function join(arr, start, end, sep,    result, i) {    
    if (length(arr) == 0)
        return ""

    result = arr[start]           

    for (i = start + 1; i <= end; i++)
        result = result sep arr[i]

    return result
}

#
# join2() - merge an array of strings into a single string. Array indice are strings.
#                  
#   . optional third argument 'sortkey' informs how to sort:
#       https://www.gnu.org/software/gawk/manual/html_node/Controlling-Scanning.html
#   . spliti() does reverse
#
function join2(arr, sep, sortkey,         i,lobster) {

    if (!empty(sortkey)) {
        if ("sorted_in" in PROCINFO)
            save_sorted = PROCINFO["sorted_in"]
        PROCINFO["sorted_in"] = sortkey
    }

    for ( lobster in arr ) {
        if (++i == 1) {
            result = lobster
            continue
         }
         result = result sep lobster
    }

    if (save_sorted)
        PROCINFO["sorted_in"] = save_sorted
    else
        PROCINFO["sorted_in"] = ""

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
        return

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
# asplit() - given a string of "key=value SEP key=value" pairs, break it into array[key]=value
#
#   . can optionally supply "re" for equals, space; if they're the same or equals is "", array will be setlike
#
#   Example             
#     asplit(arr, "action=query&format=json&meta=tokens", "=", "&")
#       arr["action"] = "query"
#       arr["format"] = "json"
#       arr["meta"]   = "tokens"
# 
#   . join() does the inverse eg. join(arr, 0, length(arr) - 1, "&") == "action=query&format=json&meta=tokens"
# 
# Credit: https://github.com/dubiousjim/awkenough
# 
function asplit(array, str, equals, space, aux, i, n) {

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
            array[aux[i]]
    }              
    delete aux     
    return n
}                    

#
# readfile2() - similar to readfile but no trailing \n               
#
#   Credit: https://github.com/dubiousjim/awkenough getfile()
#
function readfile2(path,   v, p, res) {
    res = p = ""
    while (0 < (getline v < path)) {
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

  # portable filename characters
    c = "012345689ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
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

  # get the base of the template, sans Xs
    template = substr(template, 0, length(template) - 6)

  # generate the filename
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
function isanumber(str,    safe,i) {

    if (length(str) == 0) return 0
    safe = str
    while ( i++ < length(safe) ) {
        if ( substr(safe,i,1) !~ /[0-9]/ )
            return 0
    }            
    return 1
}

#  
# randomnumber() - return a random number between 1 to max
#
#  . robust awk random number generator works at nano-second speed and parallel simultaneous invocation
#  . requires global variable _cliff_seed ie:
#        _cliff_seed = "0.00" splitx(sprintf("%f", systime() * 0.000001), ".", 2)
#    should be defined one-time only eg. in the BEGIN{} section
#
function randomnumber(max, i,randomArr) {

  # if missing _cliff_seed fallback to less-robust rand() method
    if (empty(_cliff_seed))
        return randomnumber1(max)

  # create array of 1000 random numbers made by cliff_rand() method seeded by systime()                
    for (i = 0; i <= 1002; i++)
        randomArr[i] = randomnumber2(max)  

  # choose one at random using rand() method seeded by PROCINFO["pid"]
    return randomArr[randomnumber1(1000)]

}                           
function randomnumber1(max) {
    srand(PROCINFO["pid"])
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
# stdErr() - print s to /dev/stderr
#
#  . if flag = "n" no newline
#  
function stdErr(s, flag) {
    if (flag == "n")
        printf("%s",s) > "/dev/stderr"
    else
        printf("%s\n",s) > "/dev/stderr"
    close("/dev/stderr")
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
        if (T[i] ~ /^\"/) {
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
                        w = substr(u, 1, 1)  
                        if (w == "b") v = v "\b" substr(u, 2)
                        else if (w == "f") v = v "\f" substr(u, 2)
                        else if (w == "n") v = v "\n" substr(u, 2)
                        else if (w == "r") v = v "\r" substr(u, 2)
                        else if (w == "t") v = v "\t" substr(u, 2)
                        else v = v u
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
        if (a[c] == value) 
            arr[a[indexn]] = jsonarr[ja]
    }
    return length(arr)
}

# [[ ________ Edit ___________________________________________________________ ]]


function setupEdit(   cookiejar) {

 # OAuth credentials

    G["consumerKey"]    = ""
    G["consumerSecret"] = ""
    G["accessKey"]      = ""
    G["accessSecret"]   = ""

    if (empty(G["consumerKey"])) {
        stdErr("No account. See EDITSETUP for login/authentication info.")
        exit
    }

  # Where to store cookies

    cookiejar = "/tmp/cookiejar"
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

function editPage(title,summary,page,    sp,jsona,data,command,postfile,fp,line,outfile,text) {

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
      exit
    }

    data = strip("action=edit&bot=&format=json&text=" text "&title=" urlencodeawk(title, "rawphp") "&summary=" urlencodeawk(summary, "rawphp") "&token=" urlencodeawk(getEditToken()) )
    postfile = genPostfile(data)
    command = "wget " cookieopt " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(strip(oauthHeader(data))) " --post-file=" shquote(postfile) " -q -O- " shquote(G["apiURL"]) 
    sp = sys2var(command)

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

function getEditToken(  sp,jsona,command,data) {

    setupEdit()
    data = "action=query&format=json&meta=tokens"
    sp = sys2var(apiurl(data))
    query_json(sp, jsona)

    if (G["debug"] ) {
        print "\nGET TOKEN\n-------"
        print command
        print "  ---JSON---"
        awkenough_dump(jsona, "jsona")
        print "  ---RAW---"
        print sp
    }

    return jsona["query","tokens","csrftoken"]

}

function moveArticle(from,to,    sp,jsona,data,command) {

    setupEdit()
    data = strip("action=move&bot&format=json&from=" urlencodeawk(from, "rawphp") "&to=" urlencodeawk(to, "rawphp") "&movetalk&token=" urlencodeawk(getEditToken()) )
    sp = sys2var(apiurl(data))

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
# userInfo() - user info via API
#  https://www.mediawiki.org/wiki/API:userinfo
#
function userInfo(  sp,jsona,command,data) {

    setupEdit()
    data = "action=query&meta=userinfo&uiprop=" urlencodeawk("rights|groups|blockinfo") "&format=json"
    sp = sys2var(apiurl(data))
    query_json(sp, jsona)
    awkenough_dump(jsona, "jsona")
}

#
# printResult() - print result of action
#
function printResult(json,  jsona,nc,sc) {

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
      else
        print "Unknown error"
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
function apiurl(data,  command,wget_opts) {

    command = "wget " cookieopts " --header=" shquote("Content-Type: application/x-www-form-urlencoded") " --header=" shquote(strip(oauthHeader(data))) " --post-data=" shquote(data) " -q -O- " shquote(G["apiURL"]) 
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

#
# MWOAuthGenerateHeader() - MediaWiki Generate OAuth Header
#
#   . requires openssl
#
#   Credit: translation of PhP script https://www.mediawiki.org/wiki/OAuth/Owner-only_consumers#Algorithm
#
function MWOAuthGenerateHeader(consumerKey, consumerSecret, accessKey, accessSecret, url, method, data,  

                               nonce,headerParams,dataArr,allParams,allParamsJoined,k,i,j,url2,
                               signatureBaseParts,signatureBaseString,hmac,header,save_sorted) {

  # sort associative arrays by index string ascending
    if ("sorted_in" in PROCINFO)               
        save_sorted = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = "@ind_str_asc"

    nonce = strip(splitx(sys2varPipe(systime() randomnumber(1000000), "openssl md5"), "= ", 2))

    asplit(headerParams, "oauth_consumer_key=" consumerKey " oauth_token=" accessKey " oauth_signature_method=HMAC-SHA1 oauth_timestamp=" systime() " oauth_nonce=" nonce " oauth_version=1.0") 
    asplit(dataArr, data, "=", "&")
    concatarray(headerParams,dataArr,allParams)
    for (k in allParams) 
        allParamsJoined[i++] = k "=" allParams[k]

    url2 = urlElement(url, "scheme") "://" tolower(urlElement(url, "netloc")) urlElement(url, "path")
    asplit(signatureBaseParts, "0=" toupper(method) " 1=" url " 2=" join(allParamsJoined, 0, length(allParamsJoined) - 1, "&"))
    signatureBaseString = urlencodeawk(signatureBaseParts[0], "rawphp") "&" urlencodeawk(signatureBaseParts[1], "rawphp") "&" urlencodeawk(signatureBaseParts[2], "rawphp")

  # printf "value" | openssl dgst -sha1 -hmac 'key' -binary
    hmac = sys2varPipe(signatureBaseString, "openssl sha1 -hmac " shquote(urlencodeawk(consumerSecret, "rawphp") "&" urlencodeawk(accessSecret, "rawphp")) " -binary")

  # printf "hmac" | openssl base64
    headerParams["oauth_signature"] = strip(sys2varPipe(hmac, "openssl base64") )

    for (k in headerParams) 
        header[j++] = urlencodeawk(k, "rawphp") "=" urlencodeawk(headerParams[k], "rawphp")

    if (save_sorted)
        PROCINFO["sorted_in"] = save_sorted
    else
        PROCINFO["sorted_in"] = ""

    return sprintf("%s", "Authorization: OAuth " join(header, 0, length(header) - 1, ", "))
}

