#!/usr/bin/env python
"""
Download github assets handling redirects to s3. Wget and curl do not remove 
headers from the original request and results in these errors:
  Only one auth mechanism allowed; only the X-Amz-Algorithm query parameter, 
  Signature query string parameter or the Authorization header should be specified
"""
import requests, argparse


def handle_redirects(url, path, token=None):
    """Download asset handling redirects to S3."""

    headers = {
        'Accept': 'application/octet-stream',
    }
    if token: headers['Authorization'] = 'token %s' % token
    r = requests.get(url, headers=headers, stream=True, verify=False)
    with open(path, 'wb') as f:
        for chunk in r.iter_content(chunk_size=1024): 
            if chunk: # filter out keep-alive new chunks
                f.write(chunk)
    return path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="asset url")
    parser.add_argument("path", help="file path to save asset as")
    parser.add_argument("--token", "-t", default=None, help="OAuth token")
    args = parser.parse_args()
    handle_redirects(args.url, args.path, args.token)
