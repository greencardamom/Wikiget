#!/usr/local/bin/awk -bE

#
# Wikiget - command-line access to some Wikimedia API functions
#

# Changes in reverse chronological order
#
# 0.71 Mar 06      - add -z project option
# 0.70 Feb 21 2018 - add -y debug option
#                    add -n option when using -b
#                    help display changed to ~80 column 
# 0.62 Oct 03 2017 - -a max's out at 10000
# 0.61 Apr 14      - fix -r (rccontinue) 
# 0.60 Mar 17      - add -r option
# 0.51 Mar 13 2017 - add -n option when using -x
# 0.50 Dec 15 2016 - add -x (external link search) 
# 0.47 Nov 30      - fix &utf8=1 in API for usercontributions and categories 
# 0.46 Nov 30      - fix -g (for +50 results)
#                    add errormsg()
# 0.45 Nov 29      - fix -g (search title or article)
# 0.40 Nov 28      - add -a (search and sub-options)
#                    add apierror() (check for API errors)
# 0.30 Nov 27      - converted -c and -u to JSON 
# 0.20 Nov 26      - add -t (backlink types)
#                    add -q (category link types)
# 0.10 Nov 24 2016 - initial release

# The MIT License (MIT)
#
# Copyright (c) 2016-2017 by User:GreenC (at en.wikipedia.org)
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


BEGIN {

# Contact = "User:GreenC (en)"                                # Your contact info - informational only for API Agent string. Optional.
  Contact = ""                                

  G["program"] = "Wikiget"
  G["version"] = "0.71"
  G["agent"] = Program " " G["version"] " " Contact
  G["maxlag"] = "5"                                           # Wiki API max lag default
  G["lang"] = "en"                                            # Wiki language default eg. en, fr, sv etc..
  G["project"] = "wikipedia"                                  # Wiki project default eg. wikinews, wikisource etc..
                                 
  setup("wget curl lynx")                                     # Use one of wget, curl or lynx - searches PATH in this order
  Optind = Opterr = 1                                         #  They all achieve the same thing just need one 
  parsecommandline()
  processarguments()

}

# _____________________________ Command line parsing and argument processing ______________________________________________

#
# Parse command-line
#
function parsecommandline(c, opts) {

  while ((c = getopt(ARGC, ARGV, "yrhVfjpdo:k:a:g:i:s:e:u:m:b:l:n:w:c:t:q:x:z:")) != -1) {
      opts++
      if(c == "h") {
        usage()
        usage_extended()
        exit
      }

      if(c == "b") {               #  -b <entity>     Backlinks for entity ( -b "Template:Project Gutenberg" )
        Arguments["main"] = verifyval(Optarg)
        Arguments["main_c"] = "b"
      }
      if(c == "t") {               #  -t <types>      Types of backlinks ( -t "ntf" )
        Arguments["bltypes"] = verifyval(Optarg)
      }

      if(c == "c") {               #  -b <entity>     List articles in a category ( -c "Category:1900 births" )
        Arguments["main"] = verifyval(Optarg)
        Arguments["main_c"] = "c"
      }
      if(c == "q") {               #  -q <types>      Types of links in a category ( -t "psf" )
        Arguments["cattypes"] = verifyval(Optarg)
      }

      if(c == "a") {               #  -a <search>     List articles in search results ( -a "John Smith" )
        Arguments["main"] = verifyval(Optarg)
        Arguments["main_c"] = "a"
      }
      if(c == "d") {               #  -d              Include search snippet in results (optional with -a )
        Arguments["snippet"] = "true"
      }
      if(c == "j") {               #  -j              Show number of search results (optional with -a)
        Arguments["numsearch"] = "true"
      }
      if(c == "i")                 #  -i <max>        Max number of search results (optional with -a)
        Arguments["maxsearch"] = verifyval(Optarg)
      if(c == "g")                 #  -g <type>       Target search (optional with -a)
        Arguments["searchtarget"] = verifyval(Optarg)

      if(c == "u") {               #  -u <username>   User contributions ( -u "User:Green Cardamom")
        Arguments["main"] = verifyval(Optarg)
        Arguments["main_c"] = "u"
      }
      if(c == "s")                 #  -s <time>       Start time for -u (required w/ -u)
        Arguments["starttime"] = verifyval(Optarg)
      if(c == "e")                 #  -e <time>       End time for -u (required w/ -u)
        Arguments["endtime"] = verifyval(Optarg)
      if(c == "n")                 #  -n <namespace>  Namespace for -u, -a and -x (option)
        Arguments["namespace"] = verifyval(Optarg)
   
      if(c == "r")                 #  -r              Recent changes
        Arguments["main_c"] = "r"
      if(c == "o")                 #  -o <username>   Username for recent changes
        Arguments["username"] = verifyval(Optarg)
      if(c == "k")                 #  -k <tag>        Tag for recent changes
        Arguments["tags"] = verifyval(Optarg)
        
   
      if(c == "w") {               #  -w <article>    Print wiki text 
        Arguments["main"] = verifyval(Optarg)
        Arguments["main_c"] = "w"
      }
      if(c == "f")                 #  -f              Don't follow redirect (return source of redirect page)
        Arguments["followredirect"] = "false"
      if(c == "p")                 #  -p              Plain text (strip wiki markup)
        Arguments["plaintext"] = "true"

      if(c == "x") {               #  -x <URL>        List articles containing an external link 
        Arguments["main"] = verifyval(Optarg)
        Arguments["main_c"] = "x"
      }

      if(c == "m")                 #  -m <maxlag>     Maxlag setting when using API, default set in BEGIN{} section
        Arguments["maxlag"] = verifyval(Optarg)
      if(c == "l")                 #  -l <lang>       Language code, default set in BEGIN{} section
        Arguments["lang"] = verifyval(Optarg)
      if(c == "z")                 #  -z <project>    Project name, default set in BEGIN{} section
        Arguments["project"] = verifyval(Optarg)
      if(c == "y")                 #  -y              Show debugging info to stderr
        Arguments["debug"] = 1
      if(c == "V") {               #  -V              Version and copyright info.
        version()
        exit
      }  
  }
  if(opts < 1) {
    usage()
    exit
  }
  return 
}

#
# Process arguments
#
function processarguments(  c,a,i) {

  if(length(Arguments["lang"]) > 0)                                # Check options, set defaults
    G["lang"] = Arguments["lang"]
    # default set in BEGIN{}

  if(length(Arguments["project"]) > 0)                             # Check options, set defaults
    G["project"] = Arguments["project"]
    # default set in BEGIN{}

  if(isanumber(Arguments["maxlag"])) 
    G["maxlag"] = Arguments["maxlag"]
    # default set in BEGIN{}

  if(isanumber(Arguments["maxsearch"])) 
    G["maxsearch"] = Arguments["maxsearch"]
  else
    G["maxsearch"] = 10000

  if(isanumber(Arguments["namespace"])) 
    G["namespace"] = Arguments["namespace"]
  else
    G["namespace"] = "0"

  if(Arguments["followredirect"] == "false")
    G["followredirect"] = "false"
  else
    G["followredirect"] = "true"

  if(Arguments["plaintext"] == "true")
    G["plaintext"] = "true"
  else
    G["plaintext"] = "false"

  if(Arguments["snippet"] == "true")
    G["snippet"] = "true"
  else
    G["snippet"] = "false"

  if(Arguments["numsearch"] == "true")
    G["numsearch"] = "true"
  else
    G["numsearch"] = "false"

  if(Arguments["searchtarget"] !~ /^text$|^title$/)
    G["searchtarget"] = "text"
  else
    G["searchtarget"] = Arguments["searchtarget"]

  if(length(Arguments["bltypes"]) > 0) {
    if(Arguments["bltypes"] !~ /[^ntf]/) {    # ie. contains only those letters
      c = split(Arguments["bltypes"], a, "")
      while(i++ < c) 
        G["bltypes"] = G["bltypes"] a[i]
    }
    else {
      errormsg("Invalid \"-t\" value(s)")
      exit
    }
  }
  else
    G["bltypes"] = "ntf"

  if(length(Arguments["cattypes"]) > 0) {
    if(Arguments["cattypes"] !~ /[^psf]/) {    
      c = split(Arguments["cattypes"], a, "")
      while(i++ < c) 
        G["cattypes"] = G["cattypes"] a[i]
    }
    else {
      errormsg("Invalid \"-q\" value(s)")
      exit
    }
  }
  else
    G["cattypes"] = "p"

  if(Arguments["debug"])                                    # Enable debugging
    G["debug"] = 1

  # ________________________________________ #

  if(Arguments["main_c"] == "b") {                          # backlinks
    if ( entity_exists(Arguments["main"]) ) {
      if ( ! backlinks(Arguments["main"]) )
        errormsg("No backlinks for " Arguments["main"]) 
    }
  }
  else if(Arguments["main_c"] == "c") {                     # categories
    category(Arguments["main"])
  }
  else if(Arguments["main_c"] == "x") {                     # external links
    xlinks(Arguments["main"])
  }
  else if(Arguments["main_c"] == "a") {                     # search results
    search(Arguments["main"])
  }

  else if(Arguments["main_c"] == "u") {                     # user contributions
    if(! isanumber(Arguments["starttime"]) || ! isanumber(Arguments["endtime"])) {
      errormsg("Invalid start time (-s) or end time (-e)\n")
      usage()
      exit
    }
    Arguments["starttime"] = Arguments["starttime"] "000000"
    Arguments["endtime"] = Arguments["endtime"] "235959"
    if ( ! ucontribs(Arguments["main"],Arguments["starttime"],Arguments["endtime"]) )
      errormsg("No user and/or edits found.")
  }

  else if(Arguments["main_c"] == "r") {                     # recent changes
    if( (length(Arguments["username"]) == 0 && length(Arguments["tags"]) == 0) || (length(Arguments["username"]) > 0 && length(Arguments["tags"]) > 0)) {
      errormsg("Recent changes requires either -f or -k\n")
      usage()
      exit
    }
    if ( ! rechanges(Arguments["username"],Arguments["tags"]) )
      errormsg("No recent changes found.")
  }

  else if(Arguments["main_c"] == "w") {                     # wiki text
    if ( entity_exists(Arguments["main"]) ) {
      if(G["plaintext"] == "true")
        print wikitextplain(Arguments["main"])
      else
        print wikitext(Arguments["main"])
    }
    else {
      errormsg("Unable to find " Arguments["main"])
      exit
    }
  }
  else {
    usage()
    exit
  }
}

#
# usage()
#
function usage() {
  print ""              
  print "Wikiget - command-line access to some Wikimedia API functions"
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
  print " User contributions:"
  print "       -u <username>    User contributions"
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
  print "       -x <URL>         List articles containing external link (Special:Linksearch)"
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
  print " Global options:"
  print "       -l <language>    Wiki language code (default: " G["lang"] ")" 
  print "                         See https://en.wikipedia.org/wiki/List_of_Wikipedias"
  print "       -z <project>     Wiki project (default: " G["project"] ")"
  print "       -m <#>           API maxlag value (default: " G["maxlag"] ")"
  print "                         See https://www.mediawiki.org/wiki/API:Etiquette#Use_maxlag_parameter"
  print "       -y               Print debugging to stderr (show URLs sent to API)"
  print "       -V               Version and copyright"
  print "       -h               Help with examples"
  print ""
}
function usage_extended() {
  print "Examples:"
  print ""
  print " Backlinks:"
  print "   wikiget -b \"User:Jimbo Wales\"                                  (backlinks for a User: showing all link types (\"ntf\"))"
  print "   wikiget -b \"User:Jimbo Wales\" -t nt                            (backlinks for a User: showing normal and transcluded links)"                                 
  print "   wikiget -b \"Template:Gutenberg author\" -t t                    (backlinks for a Template: showing transcluded links)"
  print "   wikiget -b \"File:Justforyoucritter.jpg\" -t f                   (backlinks for a File: showing file links)"
  print "   wikiget -b \"Paris (Idaho)\" -l fr                               (backlinks for article \"Paris (Idaho)\" on the French Wiki)"
  print ""
  print " User contributions:"
  print "   wikiget -u \"User:Jimbo Wales\" -s 20010910 -e 20010912          (show all edits from 9/10-9/12 on 2001)"  
  print "   wikiget -u \"User:Jimbo Wales\" -s 20010911 -e 20010911          (show all edits during the 24hrs of 9/11)"  
  print "   wikiget -u \"User:Jimbo Wales\" -s 20010911 -e 20010930 -n 0     (articles only)"
  print "   wikiget -u \"User:Jimbo Wales\" -s 20010911 -e 20010930 -n 1     (talk pages only)"
  print "   wikiget -u \"User:Jimbo Wales\" -s 20010911 -e 20010930 -n \"0|1\" (talk and articles only)"
  print "    -n codes: https://www.mediawiki.org/wiki/Extension_default_namespaces"
  print ""
  print " Category list:"
  print "   wikiget -c \"Category:1900 births\"              (list pages in a category)"
  print "   wikiget -c \"Category:Dead people\" -q s         (list subcats in a category)"
  print "   wikiget -c \"Category:Dead people\" -q sp        (list subcats and pages in a category)"
  print ""
  print " Search-result list:"
  print "   wikiget -a \"Jethro Tull\" -g title              (list article titles containing a search string)"
  print "   wikiget -a John -i 50                          (list first 50 articles containing a search string)"
  print "   wikiget -a John -i 50 -d                       (include snippet of text containing the search string)"
  print "   wikiget -a \"Barleycorn\" -n \"0|1\"               (search talk and articles only)"
  print "   wikiget -a \"user: subpageof:GreenC\"            (list subpages of User:GreenC)"
  print "    search docs: https://www.mediawiki.org/wiki/Help:CirrusSearch"
  print "    -n codes: https://www.mediawiki.org/wiki/Extension_default_namespaces"
  print ""
  print " External link list:"
  print "   wikiget -x \"news.yahoo.com\"                    (list articles containing a URL that contains this)"
  print ""
  print " Recent changes:"
  print "   wikiget -r -k \"OAuth CID: 678\"                 (list recent changes last 30 days tagged with this)"
  print ""
  print " Print wiki text:"
  print "   wikiget -w \"Paris\"                       (print wiki text of article \"Paris\" on the English Wiki)"
  print "   wikiget -w \"China\" -p -l fr              (print plain-text of article \"China\" on the French Wiki)"
  print ""  
}
function version() {
  print "Wikiget " G["version"]
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

  if(val == "" || substr(val,1,1) ~ /^[-]/) {
    errormsg("\nCommand line argument has an empty value when it should have something.\n")
    usage()
    exit
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
        if (length(substr(argv[Optind], _opti + 1)) > 0)
            Optarg = substr(argv[Optind], _opti + 1)
        else
            Optarg = argv[++Optind]
        _opti = 0
    } else
        Optarg = ""
    if (_opti == 0 || _opti >= length(argv[Optind])) {
        Optind++
        _opti = 0
    } else
        _opti++
    return thisopt
}

# _____________________________ Setup __________________________________________________

#
# Check for existence of needed programs and files.
#
function setup(files_system) {

        if ( ! files_verify("ls") ) {
            errormsg("Unable to find ls and/or command. PATH problem?\n")
            exit
        }
        if ( ! files_verify(files_system) ) 
            exit
}

#
# Verify existence of programs in path
# Return 0 if fail.
#
function files_verify(files_system,
        a, i, missing) {

        missing = 0
        split(files_system, a, " ")
        for ( i in a ) {
            if ( ! sys2var(sprintf("command -v %s",a[i])) ) {
                if(a[i] == "wget") G["wget"] = "false"
                if(a[i] == "curl") G["curl"] = "false"
                if(a[i] == "lynx") G["lynx"] = "false"
            }
            else if(a[i] == "wget") G["wget"] = "true"
            else if(a[i] == "curl") G["curl"] = "true"
            else if(a[i] == "lynx") G["lynx"] = "true"
        }

        if(G["wget"] == "false" && G["curl"] == "false" && G["lynx"] == "false") {
          errormsg("Abort: unable to find wget, curl or lynx in PATH. Manually set a location for one of these in function http2var().")
          return 0
        }
        else if(G["wget"] == "true")
          G["wta"] = "wget"
        else if(G["curl"] == "true")
          G["wta"] = "curl"
        else if(G["lynx"] == "true")
          G["wta"] = "lynx"

        return 1
}

# _____________________________ Search list (-a) ______________________________________________

#
# Search list main
#
function search(srchstr,    url, results, a) {

        # MediaWiki API:Search
        #  https://www.mediawiki.org/wiki/API:Search

        if(G["snippet"] == "false")
          G["srprop"] = "timestamp"
        else
          G["srprop"] = "timestamp|snippet"
                                       
        if(G["searchtarget"] ~ /title/)  # Use this instead of &srwhat
          srchstr = "intitle:" srchstr   # See https://www.mediawiki.org/wiki/API_talk:Search#title_search_is_disabled  

        url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=search&srsearch=" urlencodeawk(srchstr) "&srprop=" urlencodeawk(G["srprop"]) "&srnamespace=" urlencodeawk(G["namespace"]) "&srlimit=50&continue=" urlencodeawk("-||") "&format=xml&maxlag=" G["maxlag"]

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
        if(apierror(xmlin, "xml") > 0)
          return ""
        xmlout = parsexmlsearch(xmlin)
        offset = getoffsetxml(xmlin)

        if(G["numsearch"] == "true") 
          return totalhits(xmlin)

        retrieved = 50
        if(retrieved > G["maxsearch"] && G["maxsearch"] != 0) 
          return trimxmlout(xmlout, G["maxsearch"])
   
        while( offset) {
          url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=search&srsearch=" urlencodeawk(srchstr) "&srprop=" urlencodeawk(G["srprop"]) "&srnamespace=" urlencodeawk(G["namespace"]) "&srlimit=50&continue=" urlencodeawk("-||") "&format=xml&maxlag=" G["maxlag"] "&sroffset=" offset
          xmlin = http2var(url)
          xmlout = xmlout "\n" parsexmlsearch(xmlin)
          offset = getoffsetxml(xmlin)
          retrieved = retrieved + 50
          if(retrieved > G["maxsearch"] && G["maxsearch"] != 0)
            return trimxmlout(xmlout, G["maxsearch"])
        }

        return xmlout
} 
function parsexmlsearch(xmlin,   f,g,e,c,a,i,out,snippet,title) {

        if(xmlin ~ /error code="maxlag"/) {
          errormsg("Max lag (" G["maxlag"] ") exceeded - aborting. Try again when API servers are less busy, or increase Maxlag (-m)")
          exit
        }

        f = split(xmlin,e,/<search>|<\/search>/)
        c = split(e[2],a,"/>")  

        while(++i < c) {
          if(a[i] ~ /title[=]/) {
            match(a[i], /title="[^\"]*"/,k)
            split(gensub("title=","","g",k[0]), g, "\"")
            title = convertxml(g[2])
            match(a[i], /snippet="[^\"]*"/,k)
            snippet = gensub("snippet=","","g",k[0])
            snippet = convertxml(snippet)
            gsub(/<span class[=]"searchmatch">|<\/span>/,"",snippet)
            snippet = convertxml(snippet)
            gsub(/^"|"$/,"",snippet)
            if(G["snippet"] != "false") 
              out = out title " <snippet>" snippet "</snippet>\n"
            else
              out = out title "\n"
          }
        }
        return strip(out)
}
function getoffsetxml(xmlin,  a) {

        if( match(xmlin, /<continue sroffset[=]"[0-9]{1,}"/, offset) > 0) {     
          split(offset[0],a,/"/)
          return a[2]
        }
        else 
          return ""
}
function trimxmlout(xmlout, max,   c,a,i) {

        if( split(xmlout, a, "\n") > 0) {
          while(i++ < max) 
            out = out a[i] "\n"
          return out
        }
}
function totalhits(xmlin) {

        # <searchinfo totalhits="40"/>
        if(match(xmlin, /<searchinfo totalhits[=]"[0-9]{1,}"/, a) > 0) {
          if(split(a[0],b,"\"") > 0) 
            return b[2]
          else
            return "error"
        }
        else
          return "error"
}


# _____________________________ Category list (-c) ______________________________________________

#
# Category list main
#
function category(entity,   ct, url, results) {

        # MediaWiki API:Categorymembers
        #  https://www.mediawiki.org/wiki/API:Categorymembers

        if(entity !~ /^[Cc]ategory[:]/)
          entity = "Category:" entity

        if(G["cattypes"] ~ /p/)
          ct = ct " page"
        if(G["cattypes"] ~ /s/)
          ct = ct " subcat"
        if(G["cattypes"] ~ /f/)
          ct = ct " file"
        ct = strip(ct)
        gsub(/[ ]/,"|",ct)
 
        url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=categorymembers&cmtitle=" urlencodeawk(entity) "&cmtype=" urlencodeawk(ct) "&cmprop=title&cmlimit=500&format=json&utf8=1&maxlag=" G["maxlag"]

        results = uniq( getcategory(url, entity) )

        if ( length(results) > 0)
          print results
        return length(results)
}
function getcategory(url, entity,   jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if(apierror(jsonin, "json") > 0)
          return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin, "cmcontinue")
        while ( continuecode ) {
            url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=categorymembers&cmtitle=" urlencodeawk(entity) "&cmtype=page&cmprop=title&cmlimit=500&format=json&utf8=1&maxlag=" G["maxlag"] "&continue=-||&cmcontinue=" continuecode 
            jsonin = http2var(url)
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin, "cmcontinue")
        }
        return jsonout
}

# _____________________________ External links list (-x) ______________________________________________

#
# External links list main
#
function xlinks(entity,   ct, url, results) {

        # MediaWiki API:Exturlusage 
        #  https://www.mediawiki.org/wiki/API:Exturlusage

        if(entity ~ /^https?/ )
          gsub(/^https?[:]\/\//,"",entity)
        else if(entity ~ /^\/\// ) 
          gsub(/^\/\//,"",entity)
        
        if(entity ~ /^[*]$/) {
          entity = ""
        }

        url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=exturlusage&euquery=" urlencodeawk(entity) "&euprop=title&eunamespace=" urlencodeawk(G["namespace"]) "&eulimit=500&format=json&utf8=1&maxlag=" G["maxlag"]
 
        results = uniq( getxlinks(url, entity) )

        if ( length(results) > 0)
          print results
        return length(results)
}
function getxlinks(url, entity,   jsonin, jsonout, offset) {

        jsonin = http2var(url)
        if(apierror(jsonin, "json") > 0)
          return ""
        jsonout = json2var(jsonin)
        offset = getoffsetjson(jsonin, "euoffset")
        while ( offset ) {
            url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=exturlusage&euquery=" urlencodeawk(entity) "&euprop=title&eulimit=500&format=json&utf8=1&maxlag=" G["maxlag"] "&continue=" urlencodeawk("-||") "&euoffset=" offset 
            jsonin = http2var(url)
            jsonout = jsonout "\n" json2var(jsonin)
            offset = getoffsetjson(jsonin, "euoffset")
        }
        return jsonout
}

# _____________________________ Recent changes (-r) ______________________________________________

#
# Recent changes main 
#
function rechanges(username, tag,      url, results, entity) {

        # Recent changes API
        #  https://www.mediawiki.org/wiki/API:RecentChanges#cite_note-1

        if(length(username) > 0) 
          entity = "&rcuser=" urlencodeawk(username)
        else if(length(tag) > 0)
          entity = "&rctag=" urlencodeawk(tag)
        else 
          return 0

        url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=recentchanges&rcprop=title" entity "&rclimit=500&rcnamespace=" urlencodeawk(G["namespace"]) "&format=json&utf8=1&maxlag=" G["maxlag"]

        results = uniq( getrechanges(url, entity) )

        if ( length(results) > 0) 
          print results
        return length(results)
}
function getrechanges(url, entity,         jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if(apierror(jsonin, "json") > 0)
          return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin,"rccontinue")

        while ( continuecode ) {
          url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=recentchanges&rcprop=title" entity "&rclimit=500&continue=" urlencodeawk("-||") "&rccontinue=" urlencodeawk(continuecode) "&rcnamespace=" urlencodeawk(G["namespace"]) "&format=json&utf8=1&maxlag=" G["maxlag"]
          jsonin = http2var(url)
          jsonout = jsonout "\n" json2var(jsonin)
          continuecode = getcontinue(jsonin,"rccontinue")
        }

        return jsonout
}

# _____________________________ User Contributions (-u) ______________________________________________

#
# User Contribs main 
#
function ucontribs(entity,sdate,edate,      url, results) {

        # MediaWiki namespace codes
        #  https://www.mediawiki.org/wiki/Extension_default_namespaces

        if(entity !~ /^[Uu]ser[:]/)
          entity = "User:" entity

        url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=usercontribs&ucuser=" urlencodeawk(entity) "&uclimit=500&ucstart=" urlencodeawk(sdate) "&ucend=" urlencodeawk(edate) "&ucdir=newer&ucnamespace=" urlencodeawk(G["namespace"]) "&ucprop=" urlencodeawk("title|parsedcomment") "&format=json&utf8=1&maxlag=" G["maxlag"]

        results = uniq( getucontribs(url, entity, sdate, edate) )

        if ( length(results) > 0) 
          print results
        return length(results)
}
function getucontribs(url, entity, sdate, edate,         jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if(apierror(jsonin, "json") > 0)
          return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin,"uccontinue")

        while ( continuecode ) {
            url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=usercontribs&ucuser=" urlencodeawk(entity) "&uclimit=500&continue=" urlencodeawk("-||") "&uccontinue=" urlencodeawk(continuecode) "&ucstart=" urlencodeawk(sdate) "&ucend=" urlencodeawk(edate) "&ucdir=newer&ucnamespace=" urlencodeawk(G["namespace"]) "&ucprop=" urlencodeawk("title|parsedcomment") "&format=json&utf8=1&maxlag=" G["maxlag"]
            jsonin = http2var(url)
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin,"uccontinue")
        }

        return jsonout
}

# _____________________________ Backlinks (-b) ______________________________________________

#
# Backlinks main 
#
function backlinks(entity,      url, blinks) {

        # MediaWiki API:Backlinks
        #  https://www.mediawiki.org/wiki/API:Backlinks

        if(G["bltypes"] ~ /n/) {
          url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=backlinks&bltitle=" urlencodeawk(entity) "&blnamespace=" urlencodeawk(G["namespace"]) "&blredirect&bllimit=250&continue=&blfilterredir=nonredirects&format=json&utf8=1&maxlag=" G["maxlag"]
          blinks = getbacklinks(url, entity, "blcontinue") # normal backlinks
        }

        if ( entity ~ /^[Tt]emplate[:]/ && G["bltypes"] ~ /t/) {    # transclusion backlinks
            url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&continue=&eilimit=500&format=json&utf8=1&maxlag=" G["maxlag"]
            if(length(blinks) > 0)
              blinks = blinks "\n" getbacklinks(url, entity, "eicontinue")
            else
              blinks = getbacklinks(url, entity, "eicontinue")
        } else if ( entity ~ /^[Ff]ile[:]/ && G["bltypes"] ~ /f/) { # file backlinks
            url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=imageusage&iutitle=" urlencodeawk(entity) "&iunamespace=" urlencodeawk(G["namespace"]) "&iuredirect&iulimit=250&continue=&iufilterredir=nonredirects&format=json&utf8=1&maxlag=" G["maxlag"]
            if(length(blinks) > 0)
              blinks = blinks "\n" getbacklinks(url, entity, "iucontinue")
            else
              blinks = getbacklinks(url, entity, "iucontinue")
        }

        blinks = uniq(blinks)
        if(length(blinks) > 0)
          print blinks 

        close(outfile)
        return length(blinks)
}
function getbacklinks(url, entity, method,      jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if(apierror(jsonin, "json") > 0)
          return ""
        jsonout = json2var(jsonin)
        continuecode = getcontinue(jsonin, method)

        while ( continuecode ) {

            if ( method == "eicontinue" )
                url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&eilimit=500&continue=" urlencodeawk("-||") "&eicontinue=" urlencodeawk(continuecode) "&format=json&utf8=1&maxlag=" G["maxlag"]
            if ( method == "iucontinue" )
                url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=imageusage&iutitle=" urlencodeawk(entity) "&iunamespace=" urlencodeawk(G["namespace"]) "&iuredirect&iulimit=250&continue=" urlencodeawk("-||") "&iucontinue=" urlencodeawk(continuecode) "&iufilterredir=nonredirects&format=json&utf8=1&maxlag=" G["maxlag"]
            if ( method == "blcontinue" )
                url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&list=backlinks&bltitle=" urlencodeawk(entity) "&blnamespace=" urlencodeawk(G["namespace"]) "&blredirect&bllimit=250&continue=" urlencodeawk("-||") "&blcontinue=" urlencodeawk(continuecode) "&blfilterredir=nonredirects&format=json&utf8=1&maxlag=" G["maxlag"]

            jsonin = http2var(url)
            jsonout = jsonout "\n" json2var(jsonin)
            continuecode = getcontinue(jsonin, method)
        }

        return jsonout
}

# _____________________________ Print wiki text (-w) ______________________________________________

#
# Print wiki text (-w) with the plain text option (-p)
#
function wikitextplain(namewiki,   command,f,r,redirurl,xml,i,c,b,k) {

        # MediaWiki API Extension:TextExtracts
        #  https://www.mediawiki.org/wiki/Extension:TextExtracts

        command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(strip(namewiki)) "&action=raw"
        f = http2var(command)
        if(length(f) < 5) 
          return ""
        if(tolower(f) ~ /[#][ ]{0,}redirect[ ]{0,}[[]/ && G["followredirect"] == "true") {
          match(f, /[#][ ]{0,}[Rr][Ee][^]]*[]]/, r)
          gsub(/[#][ ]{0,}[Rr][Ee][Dd][Ii][^[]*[[]/,"",r[0])
          redirurl = strip(substr(r[0], 2, length(r[0]) - 2))
          command = "https://" G["lang"] "." G["project"] ".org/w/api.php?format=xml&action=query&prop=extracts&exlimit=1&explaintext&titles=" urlencodeawk(redirurl) 
          xml = http2var(command)
        }
        else {
          command = "https://" G["lang"] "." G["project"] ".org/w/api.php?format=xml&action=query&prop=extracts&exlimit=1&explaintext&titles=" urlencodeawk(namewiki)
          xml = http2var(command)
        }

        if(apierror(xmlin, "xml") > 0)
          return ""
        else {
          c = split(convertxml(xml), b, "<extract[^>]*>")
          i = 1
          while(i++ < c) {
            k = substr(b[i], 1, match(b[i], "</extract>") - 1)
            return strip(k)
          }
        }
}

function wikitext(namewiki,   command,f,r,redirurl) {

        command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(strip(namewiki)) "&action=raw"
        f = http2var(command)
        if(length(f) < 5) 
          return ""

        if(tolower(f) ~ /[#][ ]{0,}redirect[ ]{0,}[[]/ && G["followredirect"] == "true") {
          match(f, /[#][ ]{0,}[Rr][Ee][^]]*[]]/, r)
          gsub(/[#][ ]{0,}[Rr][Ee][Dd][Ii][^[]*[[]/,"",r[0])
          redirurl = strip(substr(r[0], 2, length(r[0]) - 2))
          command = "https://" G["lang"] "." G["project"] ".org/w/index.php?title=" urlencodeawk(redirurl) "&action=raw"
          f = http2var(command)
        }
        if(length(f) < 5)
          return ""
        else
          return f
}

# _____________________________ Utility ______________________________________________

#
# Run a system command and store result in a variable
#   eg. googlepage = sys2var("wget -q -O- http://google.com")
# Supports pipes inside command string. Stderr is sent to null.
# If command fails return null
#
function sys2var(command        ,catch, weight, ship) {

        command = command " 2>/dev/null"
        while ( (command | getline catch) > 0 ) {
          if ( ++weight == 1 )
            ship = catch
          else
            ship = ship "\n" catch
        }
        close(command)
        return ship
}

#
# Webpage to variable. url is assumed to be percent encoded.
#
function http2var(url) {

        if(G["debug"])
          print url > "/dev/stderr"

        if(G["wta"] == "wget")
          return sys2var("wget --no-check-certificate --user-agent=\"" G["agent"] "\" -q -O- -- " shquote(url) )
        else if(G["wta"] == "curl")
          return sys2var("curl -L -s -k --user-agent \"" G["agent"] "\" -- " shquote(url) )
        else if(G["wta"] == "lynx")
          return sys2var("lynx -source -- " shquote(url) )
}

#
# Percent encode a string for use in a URL
#  Credit: Rosetta Code May 2015 
#  GNU Awk needs -b to encode extended ascii eg. "ł"
#           
function urlencodeawk(str,  c, len, res, i, ord) {    

        for (i = 0; i <= 255; i++)
                ord[sprintf("%c", i)] = i
        len = length(str)
        res = ""
        for (i = 1; i <= len; i++) {
                c = substr(str, i, 1);
                if (c ~ /[0-9A-Za-z]/)
                        res = res c
                else
                        res = res "%" sprintf("%02X", ord[c])
        }                 
        return res
}

#
# Parse continue code from JSON input
#
function getcontinue(jsonin, method     ,re,a,b,c) {

        # "continue":{"blcontinue":"0|20304297","continue"

        re = "\"continue\"[:][{]\"" method "\"[:]\"[^\"]*\""
        match(jsonin, re, a)
        split(a[0], b, "\"")

        if ( length(b[6]) > 0)
            return b[6]
        return 0
}

#
# Parse offset code from JSON input
#
function getoffsetjson(jsonin, method     ,re,a,b,c) {

        # "continue":{"euoffset": 10,"continue"

        re = "\"continue\"[:][{]\"" method "\"[:][^,]*[^,]"
        match(jsonin, re, a)
        split(a[0], b, /[:]/)

        if ( length(b[3]) > 0)
            return strip(b[3])
        return 0
}

# 
# Make string safe for shell
#  print shquote("Hello' There")    produces 'Hello'\'' There'              
#  echo 'Hello'\'' There'           produces Hello' There                 
# 
function shquote (str,  safe) {
        safe = str
        gsub(/'/, "'\\''", safe)
        gsub(/’/, "'\\’'", safe)
        return "'" safe "'"
}

# 
# Convert XML to plain
#
function convertxml(str,   safe) {

        safe = str
        gsub(/&lt;/,"<",safe)
        gsub(/&gt;/,">",safe)
        gsub(/&quot;/,"\"",safe)
        gsub(/&amp;/,"\\&",safe)
        gsub(/&#039;/,"'",safe)
        return safe
}

#
# Print error message to STDERR
#
function errormsg(msg) {

        if(length(msg) > 0)
          print msg > "/dev/stderr"
        else
          print "Unknown error in " G["program"] > "/dev/stderr"
}

#
# Basic check of API results for error
#
function apierror(input, type,   pre, code) {

        pre = "API error: "

        if(length(input) < 5) {
          errormsg(pre "Received no response.")
          return 1
        }

        if(type == "json") {
          if(match(input, /"error"[:]{"code"[:]"[^\"]*","info"[:]"[^\"]*"/, code) > 0) {
            errormsg(pre code[0])
            return 1
          }
        }
        else if(type == "xml") {
          if(match(input, /error code[=]"[^\"]*" info[=]"[^\"]*"/, code) > 0) {
            errormsg(re code[0])
            return 1
          }
        }
        else
          return
}

#
# entity_exists - see if a page on Wikipedia exists
#   eg. if ( ! entity_exists("Gutenberg author") ) print "Unknown page"
#
function entity_exists(entity   ,url,jsonin) {

        url = "https://" G["lang"] "." G["project"] ".org/w/api.php?action=query&titles=" urlencodeawk(entity) "&format=json"
        jsonin = http2var(url)
        if(jsonin ~ "\"missing\"")
            return 0
        return 1
}

#
# Uniq a list of \n separated names
#
function uniq(names,    b,c,i,x) {

        c = split(names, b, "\n")
        names = "" # free memory
        while (i++ < c) {
            gsub(/\\["]/,"\"",b[i])
            if(b[i] ~ "for API usage") { # Max lag exceeded.
                errormsg("\nMax lag (" G["maxlag"] ") exceeded - aborting. Try again when API servers are less busy, or increase Maxlag (-m)")
                exit
            }
            if(b[i] == "")
                continue
            if(x[b[i]] == "")
                x[b[i]] = b[i]
        }
        delete b # free memory
        return join2(x,"\n")
}

#
# Strip leading/trailing whitespace
#
function strip(str) {
        return gensub(/^[[:space:]]+|[[:space:]]+$/,"","g",str)
}

#
# Merge an array of strings into a single string. Array indice are numbers.
#
function join(array, start, end, sep,    result, i) {

        result = array[start]
        for (i = start + 1; i <= end; i++)
          result = result sep array[i]
        return result
}

#
# Merge an array of strings into a single string. Array indice are strings.
#
function join2(arr, sep         ,i,lobster) {

        for ( lobster in arr ) {
            if(++i == 1) {
                result = lobster
                continue
            }
            result = result sep lobster
        }
        return result
}

#
# Return 1 if str is a pure digit
#  eg. "1234" == 1. "0fr123" == 0
#
function isanumber(str,    safe,i) {

        safe = str
        if(safe == "") return 0
        if(safe == "0") return 1
        while( i++ < length(safe) ) {
          if( substr(safe,i,1) !~ /[0-9]/ )
            return 0
        }            
        return 1
}


# =====================================================================================================
# JSON parse function. Returns a list of values parsed from json data.
#   example:  jsonout = json2var(jsonin)
# Returns a string containing values separated by "\n".
# See the section marked "<--" in parse_value() to customize for your application.
#
# Credits: by User:Green Cardamom at en.wikipedia.org
#          JSON parser derived from JSON.awk
#          https://github.com/step-/JSON.awk.git
# MIT license. May 2015        
# =====================================================================================================
function json2var(jsonin) {

        TOKEN=""
        delete TOKENS
        NTOKENS=ITOKENS=0
        delete JPATHS
        NJPATHS=0
        VALUE=""

        tokenize(jsonin)

        if ( parse() == 0 ) {
          return join(JPATHS,1,NJPATHS, "\n")
        }
}
function parse_value(a1, a2,   jpath,ret,x) {
        jpath=(a1!="" ? a1 "," : "") a2 # "${1:+$1,}$2"
        if (TOKEN == "{") {
                if (parse_object(jpath)) {
                        return 7
                }
        } else if (TOKEN == "[") {
                if (ret = parse_array(jpath)) {
                        return ret
        }
        } else if (TOKEN ~ /^(|[^0-9])$/) {
                # At this point, the only valid single-character tokens are digits.
                return 9
        } else {
                VALUE=TOKEN
        }
        if (! (1 == BRIEF && ("" == jpath || "" == VALUE))) {

                # This will print the full JSON data to help in building custom filter
              #   x = sprintf("[%s]\t%s", jpath, VALUE)
              #   print x

                if ( a2 == "\"*\"" || a2 == "\"title\"" ) {     # <-- Custom filter for MediaWiki API. Add custom filters here.
                    x = substr(VALUE, 2, length(VALUE) - 2)
                    NJPATHS++
                    JPATHS[NJPATHS] = x
                }

        }
        return 0
}
function get_token() {
        TOKEN = TOKENS[++ITOKENS] # for internal tokenize()
        return ITOKENS < NTOKENS
}
function parse_array(a1,   idx,ary,ret) {
        idx=0
        ary=""
        get_token()
        if (TOKEN != "]") {
                while (1) {
                        if (ret = parse_value(a1, idx)) {
                                return ret
                        }
                        idx=idx+1
                        ary=ary VALUE
                        get_token()
                        if (TOKEN == "]") {
                                break
                        } else if (TOKEN == ",") {
                                ary = ary ","
                        } else {
                                return 2
                        }
                        get_token()
                }
        }
        VALUE=""
        return 0
}
function parse_object(a1,   key,obj) {
        obj=""
        get_token()
        if (TOKEN != "}") {
                while (1) {
                        if (TOKEN ~ /^".*"$/) {
                                key=TOKEN
                        } else {
                                return 3
                        }
                        get_token()
                        if (TOKEN != ":") {
                                return 4
                        }
                        get_token()
                        if (parse_value(a1, key)) {
                                return 5
                        }
                        obj=obj key ":" VALUE
                        get_token()
                        if (TOKEN == "}") {
                                break
                        } else if (TOKEN == ",") {
                                obj=obj ","
                        } else {
                                return 6
                        }
                        get_token()
                }
        }
        VALUE=""
        return 0
}
function parse(   ret) {
        get_token()
        if (ret = parse_value()) {
                return ret
        }
        if (get_token()) {
                return 11
        }
        return 0
}
function tokenize(a1,   myspace) {

        # POSIX character classes (gawk) 
        # Replaced regex constant for string constant, see https://github.com/step-/JSON.awk/issues/1
        myspace="[[:space:]]+"
        gsub(/\"[^[:cntrl:]\"\\]*((\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})[^[:cntrl:]\"\\]*)*\"|-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?|null|false|true|[[:space:]]+|./, "\n&", a1)
        gsub("\n" myspace, "\n", a1)
        sub(/^\n/, "", a1)
        ITOKENS=0 
        return NTOKENS = split(a1, TOKENS, /\n/)

}
