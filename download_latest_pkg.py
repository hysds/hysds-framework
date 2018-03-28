#!/usr/bin/env python
"""
Helper script for querying github API for release info.
"""
import os, sys, re, requests, json, logging, argparse
from urlparse import urlparse

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


def get_latest_pkg(api_url, owner, repo, token):
    """Return latest release for repo."""

    # get latest release info
    latest_url = "{}/repos/{}/{}/releases/latest".format(api_url, owner, repo)
    latest = call_github_api(latest_url, token)

    # git sdspkg.tar asset
    assets = latest['assets']
    for asset in assets:
        if asset['name'].endswith('.sdspkg.tar'):
            return asset['name'], asset['url']


def main(url, owner, repo, outdir=None):
    """Route request."""

    token, api_url = parse_url(url)
    print("token: {}".format(token))
    print("api_url: {}".format(api_url))
    latest_pkg_name, latest_pkg_url = get_latest_pkg(api_url, owner, repo, token)
    print("latest_pkg_name: {}".format(latest_pkg_name))
    print("latest_pkg_url: {}".format(latest_pkg_url))
    if outdir is not None and not os.path.isdir(outdir):
        os.makedirs(outdir)
        local_path = os.path.join(outdir, latest_pkg_name)
    else: local_path = latest_pkg_name
    handle_redirects(latest_pkg_url, local_path, token)

    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--outdir", '-o', default=None,
                        help="directory to save packages to")
    parser.add_argument("api_url", help="Github API url")
    parser.add_argument("owner", help="repo owner or org")
    parser.add_argument("repo", help="repo name")
    args = parser.parse_args()
    main(args.api_url, args.owner, args.repo, args.outdir)
