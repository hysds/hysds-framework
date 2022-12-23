#!/usr/bin/env python
"""
Download github assets handling redirects to s3. Wget and curl do not remove 
headers from the original request and results in these errors:
  Only one auth mechanism allowed; only the X-Amz-Algorithm query parameter, 
  Signature query string parameter or the Authorization header should be specified
"""
from __future__ import unicode_literals
from __future__ import print_function
from __future__ import division
from __future__ import absolute_import
from builtins import open
from future import standard_library

standard_library.install_aliases()
import argparse
import requests
import backoff


def backoff_max_value():
    """Return max value for backoff."""
    return 64


def backoff_max_time():
    """Total time it will retry the function"""
    return 600


@backoff.on_exception(backoff.expo, Exception, max_time=backoff_max_time, max_value=backoff_max_value)
def handle_redirects(url, path, token=None):
    """Download asset handling redirects to S3."""

    headers = {"Accept": "application/octet-stream"}
    if token:
        headers["Authorization"] = "token %s" % token
    r = requests.get(url, headers=headers, stream=True, verify=False)
    if not (200 <= r.status_code < 400):
        raise requests.exceptions.HTTPError(r.status_code, r.text)
    with open(path, "wb") as f:
        for chunk in r.iter_content(chunk_size=1024):
            if chunk:  # filter out keep-alive new chunks
                f.write(chunk)
    return path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="asset url")
    parser.add_argument("path", help="file path to save asset as")
    parser.add_argument("--token", "-t", default=None, help="OAuth token")
    args = parser.parse_args()
    handle_redirects(args.url, args.path, args.token)
