from __future__ import unicode_literals
from __future__ import print_function
from __future__ import division
from __future__ import absolute_import
from builtins import str
from future import standard_library

standard_library.install_aliases()

import download_latest
import unittest
import shutil


class TestDownloadLatest(unittest.TestCase):
    def test_get_latest_assets(self):
        """
        Tests ability to get the latest release for a repo, which
        simultaneously tests the call_github_api function
        This test will break if hysds-verdi-latest is not published correctly
        or when the Github API changes
        """
        api_url = "https://api.github.com"
        owner = "hysds"
        repo = "hysds-dockerfiles"
        token = None
        suffix = "tar.gz"
        assets = [
            i[0]
            for i in download_latest.get_latest_assets(
                api_url, owner, repo, token, suffix
            )
        ]
        self.assertIn("hysds-verdi-latest.tar.gz", assets)


if __name__ == "__main__":
    unittest.main()
