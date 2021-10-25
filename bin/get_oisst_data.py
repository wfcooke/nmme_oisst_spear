#!/usr/bin/env python 

import urllib.request
import urllib.parse
import urllib.error
import re
import bs4
import datetime
from dateutil.relativedelta import relativedelta
import pandas as pd
import os
import sys
import errno
import logging
import logging.handlers
import configobj

class RedirectError(Exception):
   """Class to handle a redirection."""
   def __init__(self, message=None):
       """Currently nothing is really done, but set a message."""
       if not message:
           self.message="Redirect detected."
       else:
           self.message=message

class NoTableError(Exception):
   """Class to handle if the HTML data does not contain the requested table."""
   def __init__(self):
       self.message="No tables found in HTML data."

class UrlData(object):
    def __init__(self, url):
        """Get a list of directories and files served from URL.

        The URL string passed in, must be a HTML served list of directories/Files.
        """

        # Get the logger
        logger = logging.getLogger(__name__)

        # Set dirs and files to be empty lists
        self.dirs = []
        self.files = []

        # Split the URL to get the scheme
        split_url = urllib.parse.urlsplit(url)

        if re.match('https?', split_url.scheme):
            # Deal with http
            try:
                request=urllib.request.urlopen(url)
                # Check if URL redirected
                if str(split_url.netloc) != str(urllib.parse.urlparse(request.geturl()).netloc):
                    raise RedirectError(message="A redirection of \"{0}\" to \"{1}\" detected.  Data may be suspect.".format(split_url.netloc,urllib.parse.urlparse(request.geturl()).netloc))
            except urllib.error.URLError as err:
                logger.error("Unable to open URL \"{0}\" for parsing: {1}".format(url,err.reason))
                raise
            except RedirectError as err:
                logger.warning(err.message)
                pass
            # Verify the URL is a "text/html" type
            if not re.match("text/html", request.getheader('Content-Type')):
                print("URL \"{0}\" does not return a text/html content type.  Unable to parse.".format(url))
            else:
                # Get the directories and files
                try:
                    data=request.read()

                    # Soupify, parse the html
                    soup = bs4.BeautifulSoup(data,'html.parser')

                    # The version of the web server used places all the files in a table.  If the
                    # web server is updated, or if the format changes, the table parser below will need
                    # to be updated.

                    # The directories/files start at row 3
                    # Get all the directories
                    rows=soup.table.findAll('tr')[3:]

                    # Check if rows is empty
                    if not rows:
                        raise NoTableError
                    # Get the directory names and mod time.  Directories have a name that end with "/"
                    self.dirs=[{'name': row.findAll('td')[0].a.get_text(),
                        'mdate': row.findAll('td')[1].get_text(),
                        'size': row.findAll('td')[2].get_text()}
                        for row in rows if len(row.findAll('td')) >= 4 and row.findAll('td')[0].a.get_text().endswith("/")]
                    # Get the file names size and mod time
                    self.files = [{'name': row.findAll('td')[0].a.get_text(),
                        'mdate': row.findAll('td')[1].get_text(),
                        'size': row.findAll('td')[2].get_text()}
                        for row in rows if len(row.findAll('td')) >= 4 and not row.findAll('td')[0].a.get_text().endswith("/")]
                except NoTableError as err:
                    logger.error(err.message)
                    exit(1)
                except:
                    logger.error("Unable to parse HTML returned from {0}".format(url))
                    exit(1)
        else:
            print("Unable to parse URL scheme {0}.  Not yet implemented".format(split_url.scheme))
def readConfig(configFile='~/.oisstrc'):
    """Read in the config file

    A dictionary will be returned containing the keys and values of
    the config file.

    The keys currently included in the config file are:
    scheme, hostURL, hostPath, outputDir, logDir
    """

    # Read in the config file.
    # TODO: Put this in a try with exception handeling: http://www.voidspace.org.uk/python/configobj.html#exceptions
    # TODO: Add validation to the config file.
    return configobj.ConfigObj(infile=configFile, file_error=True)

def init_logging(logDir, logLevel='DEBUG'):
    """Initialize the logging

    The logging used in this program will always log to a file.  If
    run on a tty, then the logging messages will also be displayed in
    the console.  An option may be added later to not create the log
    file.

    The logDir must already exist, and the user _must_ have permission
    to write to the log file.  The application will exit if the user
    is unable to write to the log file.

    The log file created will be "get_oisst.log".

    The log file will be rotated each week (on Sunday), the old log
    file will have the date appened with the format "YYYY-MM-DD".

    A return of None indicates an error was found creating the logger.
    """

    # Check if logDir directory exists, and is a directory
    if not os.path.isdir(logDir):
        # Logger is not started, must write directly to stderr
        print("ERROR: The log directory '{0}' does not exist.\n"
              "ERROR: Please create and try again.".format(logDir), file=sys.stderr)
        return None

    # Check if the user has permission to write to the logDir
    if not os.access(logDir, os.W_OK):
        # Logger is not started, must write directly to stderr
        print("ERROR: Permissions on the log directory '{0}' do not allow the current user to write the log file.\n"
              "ERROR: Please correct the permissions and try again.".format(logDir), file=sys.stderr)
        return None

    # Set the logFile name
    logFile = os.path.join(logDir, 'get_oisst.log')

    # Get the logger
    logger = logging.getLogger(__name__)
    logger.setLevel(logLevel)

    # Setup the rotating log file, rotate each Sunday (W6), delete
    # files more then 4 month old.
    logFileHandler = logging.handlers.TimedRotatingFileHandler(logFile,
                                                               when='W6',
                                                               backupCount=17)
    # Log file format
    logFileFormat = logging.Formatter('%(asctime)s %(levelname)-8s %(message)s')
    logFileHandler.setFormatter(logFileFormat)
    # Add the handler to the logger
    logger.addHandler(logFileHandler)

    # Create the consol logger if run in a tty
    if os.isatty(sys.stdin.fileno()):
        # Define a log hander for the console
        console = logging.StreamHandler()
        console.setLevel(logLevel)
        consoleFormat = logging.Formatter('%(levelname)-8s %(message)s')
        console.setFormatter(consoleFormat)

        # Add the console logger
        logger.addHandler(console)

    return logger

def getFile(url='', source='', target=''):
    """Download the file listed at url and source, and place in target

    url is a string that contains the base url with scheme and optional path.
    url and source will be combined to create the full URL for downloading.

    This function will check if the file exists.  If it does exist,
    then it will check the size and date stamp.  If the file on the
    url site is newer, or a different size, then the file will be
    downloaded again.  If the size is the same, and the date stamp on
    the ftp site is older, then the download will not be retried.

    This funtion will return True if successful (or if the file didn't
    need to be downloaded).
    """

    # Get the logger
    logger = logging.getLogger(__name__)

    # Default return value
    myRet = False

    # Check if scheme is http
    split_url = urllib.parse.urlsplit(url)
    if re.match('https?', split_url.scheme):
        # Default is to attempt the download.  doDownload will be changed to False
        # if the download should not be retried.
        doDownload=True

        # Open the URL to the file to collect information about the file
        try:
            full_url = urllib.parse.urljoin(url,source)
            request = urllib.request.urlopen(urllib.parse.urljoin(url,source))
        except urllib.error.URLError as err:
            print("Unable to open URL \"{0}\" for parsing: {1}".format(full_url,err.reason))
            raise

        # Check if the target file exists
        if os.path.isfile(target):
            # Need to get file sizes and ctime
            try:
                target_size=os.path.getsize(target)
                target_ctime=datetime.datetime.utcfromtimestamp(os.path.getctime(target))
            except OSError as err:
                logger.warning("Unable to get the size or ctime of the target file \"{0}\".".format(target))
                logger.warning("Retrying the download. ([{0}] {1})".format(err.errno, err.strerror))
            else:
                # Need to get source size and ctime
                try:
                    source_size=int(request.getheader("Content-Length"))
                    source_ctime=datetime.datetime.strptime(request.getheader("Last-Modified"), "%a, %d %b %Y %H:%M:%S %Z")
                except Exception as err:
                    logger.warning("Unable to get the size or ctime of the source file \"{0}\".".format(full_url))
                    logger.warning("Retrying the download. ({1})".format(err))

                # Check if the files are the _same_. Same here is that
                # the file sizes are the same, and the source ctime is
                # older than the target's ctime.
                if source_size == target_size and source_ctime <= target_ctime:
                    logger.info("File \"{0}\" already retrieved.".format(full_url))
                    doDownload = False
                else:
                    logger.warning("Target \"{0}\" exists, but does not match the source \"{1}\".  Retrieving.".format(target, full_url))
                    logger.warning("Target size={0}, ctime={1}. Source size={2}, ctime={3}".format(target_size, target_ctime, source_size, source_ctime))
        # Now do the download
        if doDownload:
            try:
                logger.info("Downloading file {0} to {1}.".format(full_url, target))
                urllib.request.urlretrieve(full_url, target)
            except urllib.error.URLError as err:
                logger.warning("Error while attempting to retrieve file \"{0}\". ({1})".format(full_url, err))
            except OSError as err:
                logger.warning("Unable to write target file \"{0}\". ([{1}] {2})".format(target, err.errno, err.strerror))
            else:
                myRet = True
    return myRet

def main():
    """Download the OISST data for use in GFDL's ECDA model"""

    # Read in the coniguration file
    config = readConfig('oisst.conf')

    # Set the configurations into variables
    scheme_url = config['scheme']
    host_url = config['hostUrl']
    path_url = config['hostPath']
    rawDataDir = config['outputDir']

    # Initiate the Logger
    logger = init_logging(config['logDir'], config['logLevel'])
    if not isinstance(logger, logging.Logger):
        exit("Unable to setup logging")

    # path_url requires a final '/', or urllib.parse.join will not work correctly later
    if not path_url.endswith("/"):
        path_url = path_url+"/"

    try:
        base_url = urllib.parse.urlunsplit((scheme_url, host_url, path_url, '', ''))
    except Exception as err:
        logger.exception("Unable to create base full URL from configuration options: scheme={0}, hostUrl={1}, hostPath={3}".format(scheme_url, host_url, path_url))
        logger.exception("Got Exception: \"{0}\", \"{1}\"".format(err.errno, err.strerror))
        raise

    # Check if rawDataDir exists, if not create it
    #save data for each month under new directory
    now=datetime.datetime.now()
    current_mon_year=now.strftime('%^b%Y') 
    outDir=os.path.join(rawDataDir, current_mon_year)
    try:
        os.makedirs(outDir)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise
    
    # Get data from Dec 31 of previous year to the first of this month
    currentTime = datetime.datetime.now()
    lastMonTime = datetime.datetime(currentTime.year, currentTime.month, 15) - relativedelta(years=1)
    
    last=datetime.datetime(lastMonTime.year, 12, 15)
    #add one month for pandas date_range
    current_plus=datetime.datetime(currentTime.year, currentTime.month, 15) + relativedelta(months=1)
    
    mon_list_tmp=pd.date_range(last, current_plus, freq='M')
    
    #reformat mon_list
    mon_list=[]
    for mon in mon_list_tmp:
        mon_list.append(mon.strftime('%Y%m')+'/')
    
    url_data_base=UrlData(base_url)

    # Download files in mon_list
    #dirsToUse=(d for d in url_data_base.dirs if d['name'] == currentDateStr or d['name'] == lastMonDateStr)
    dirsToUse=(d for d in url_data_base.dirs if d['name'] in mon_list)
    for d in dirsToUse:

        dir_url = urllib.parse.urljoin(base_url,d['name'])
        my_url_data = UrlData(dir_url)

        # Download the files if the file does not already exist, is older than the file
        # on the site.  (Ideally size as well, but that may be difficult as the size I
        # get is not exact (I think))
        for f in my_url_data.files:
            getFile(dir_url, f['name'], os.path.join(outDir,f['name']))

if __name__ == '__main__':
    main()
