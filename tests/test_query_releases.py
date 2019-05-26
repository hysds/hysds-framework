from __future__ import unicode_literals
from __future__ import print_function
from __future__ import division
from __future__ import absolute_import
from builtins import str
from future import standard_library
standard_library.install_aliases()

import query_releases
import unittest

class TestQueryReleases(unittest.TestCase):

    def test_parse_url(self):
        """
        Tests the parse_url function
        """
        base_url = "https://test.url"
        token1, url1 = query_releases.parse_url(base_url)
        self.assertIsNone(token1)
        self.assertEqual(url1, base_url)

        test_url_2 = "https://token@test.url" # 2nd test URL is based on the base_url
        token2, url2 = query_releases.parse_url(test_url_2)
        self.assertEqual(token2, 'token')
        self.assertEqual(url2, base_url)

if __name__ == '__main__':
    unittest.main()
