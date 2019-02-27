# -*- coding: utf-8 -*-

import sys
from pprint import pprint

# START: Frawned approach to change default encoding
# But I intentionally take this approach since it's easy and believe it non-problematic in this limited program.
# See discussion detail here.
# https://stackoverflow.com/questions/3828723/why-should-we-not-use-sys-setdefaultencodingutf-8-in-a-py-script
reload(sys)
sys.setdefaultencoding('UTF8')
# END: Frawned approach to change default encoding

import os
from selenium import webdriver
from selenium.webdriver.common.action_chains import ActionChains
import time
import errno
from optparse import OptionParser
import re
import hashlib

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

def get_filename(text):
    if re.search('[^\w\.\-_]', text):
        return hashlib.sha256(text.encode('utf-8')).hexdigest()
    else:
        return text

def save_snapshot(driver, word, idx):
    fname = os.path.join(Options.dir, "%s.png" % get_filename(word))
    idx = "%03d" % (idx + 1)

    if os.path.isfile(fname):
        print "  [SKIP] %s: %s exists!" % (idx, fname)
        return

    driver.save_screenshot(fname)
    print "  [SAVE] %s: %s" % (idx, fname)

def get_words_from_file(fname):
    with open(fname) as f:
        content = f.readlines()
    content = [x.split("\t")[0] for x in content]
    return content

Options = {}

def main():
    global Options

    usage = "usage: %prog [options] word-list"
    parser = OptionParser(usage=usage)
    parser.add_option("-d", "--dir", dest="dir", help="Directory to write captured images.", default="slideshow/imgs")
    parser.add_option("-w", "--window", dest="window", help="Window size. 1280x720 by default.", default="1280x720")
    parser.add_option("-e", "--entry", dest="entry", help="App entry index.html", default="slideshow/index.html")
    (Options, args) = parser.parse_args()

    chrome_options = webdriver.ChromeOptions()
    chrome_options.add_argument('--headless')
    driver = webdriver.Chrome(chrome_options=chrome_options)

    (screen_width, screen_height) = Options.window.split("x")
    driver.set_window_size(screen_width, screen_height)
    print 'window size', driver.get_window_size()
    print 'output dir', Options.dir
    print 'app entry', Options.entry

    mkdir_p(Options.dir)

    driver.get('file://' +  os.path.abspath(Options.entry))
    fileinput_element = driver.find_element_by_id("fileinput")
    body = driver.find_element_by_id("fileinput")
    for file in args:
        fileinput_element.send_keys(os.path.abspath(file))
        driver.execute_script("app.screenCaptureMode();")
        driver.execute_script("app.refresh();")
        for idx, word in enumerate(get_words_from_file(file)):
            try:
                word_actual = driver.find_element_by_id('word').text
                assert len(word_actual) > 0
                # assert word == word_actual
            except Exception as e:
                pprint([word, word_actual])
                raise

            save_snapshot(driver, word, idx)
            driver.execute_script("app.setCard('next');")

    driver.quit()

main()
