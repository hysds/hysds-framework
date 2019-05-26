#!/usr/bin/env python
"""
Helper script for querying github API for release info.
"""
from __future__ import print_function
from __future__ import unicode_literals
from __future__ import division
from __future__ import absolute_import
from future import standard_library
standard_library.install_aliases()
import os, sys, re, requests, json, logging, argparse
try:
    from urllib.parse import urlparse # Python3
except ImportError:
    from urlparse import urlparse # Python2


log_format = "[%(asctime)s: %(levelname)s/%(funcName)s] %(message)s"
logging.basicConfig(format=log_format, level=logging.INFO)


TOKEN_RE = re.compile(r'^(.+://)(?:.+@)?(.+)$')


def mask_token(url): return TOKEN_RE.sub(r'\1xxxxxxxx@\2', url)

    
def get_releases(url, token):
    """Query releases."""

    if token is not None:
        headers = { 'Authorization': 'token %s' % token }
    else: headers = {}
    r = requests.get(url, headers=headers)
    r.raise_for_status()
    return r.json()


def get_assets(url, token, release):
    """Query releases."""

    releases = get_releases(url, token)
    for rel in releases:
        if rel['tag_name'] == release:
            return rel['assets']
    return []


def parse_url(url):
    """Return oauth token and url."""

    u = urlparse(url)
    if '@' in u.netloc:
        token, host = u.netloc.split('@')
    else:
        token = None
        host = u.netloc
    return token, '{}://{}{}'.format(u.scheme, host, u.path)


def main(url, release):
    """Route request."""

    token, api_url = parse_url(url)
    logging.info("Github repo URL: %s" % mask_token(url))
    if release is None:
        for i in get_releases(url, token):
            #print(json.dumps(i, indent=2))
            print(("{}|{}".format(i['id'], i['tag_name'])))
    else:
        for i in get_assets(url, token, release):
            #print(json.dumps(i, indent=2))
            print(("{}|{}".format(i['name'], i['url'])))

    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-r", "--release", help="Get assets for a specific release",
                        required=False, default=None)
    parser.add_argument("repo_api_url", help="Github API url for repo")
    args = parser.parse_args()
    main(args.repo_api_url, args.release)
