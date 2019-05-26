#!/usr/bin/env python
"""
Helper script for querying github API for release info.
"""
from __future__ import unicode_literals
from __future__ import print_function
from __future__ import division
from __future__ import absolute_import
from future import standard_library
standard_library.install_aliases()
import os, sys, re, requests, json, logging, argparse
try:
    from urllib.parse import urlparse # Python3
except ImportError:
    from urlparse import urlparse # Python2

from query_releases import parse_url
from download_asset import handle_redirects


log_format = "[%(asctime)s: %(levelname)s/%(funcName)s] %(message)s"
logging.basicConfig(format=log_format, level=logging.INFO)


def call_github_api(url, token, method="get", **kargs):
    """General function to call github API."""

    headers = None if token is None else { 'Authorization': 'token %s' % token }
    r = getattr(requests, method)(url, headers=headers, **kargs)
    if r.status_code not in (200, 201):
        logging.error("Error response: {}".format(r.content))
    r.raise_for_status()
    return r.json()


def get_latest_assets(api_url, owner, repo, token, suffix=None):
    """Return latest release for repo."""

    # get latest release info
    latest_url = "{}/repos/{}/{}/releases/latest".format(api_url, owner, repo)
    latest = call_github_api(latest_url, token)

    # git sdspkg.tar asset
    assets = latest['assets']
    dl_assets = []
    for asset in assets:
        if suffix is not None:
            if asset['name'].endswith(suffix):
                dl_assets.append([asset['name'], asset['url']])
        else: dl_assets.append([asset['name'], asset['url']])
    return dl_assets


def main(url, owner, repo, outdir=None, suffix=None):
    """Route request."""

    token, api_url = parse_url(url)
    dl_assets = get_latest_assets(api_url, owner, repo, token, suffix)
    if outdir is not None and not os.path.isdir(outdir):
        os.makedirs(outdir)
    for pkg_name, pkg_url in dl_assets:
        local_path = pkg_name if outdir is None else os.path.join(outdir, pkg_name)
        handle_redirects(pkg_url, local_path, token)

    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--outdir", '-o', default=None,
                        help="directory to save packages to")
    parser.add_argument("--suffix", '-s', default=None,
                        help="filter by suffix")
    parser.add_argument("api_url", help="Github API url")
    parser.add_argument("owner", help="repo owner or org")
    parser.add_argument("repo", help="repo name")
    args = parser.parse_args()
    main(args.api_url, args.owner, args.repo, args.outdir, args.suffix)
