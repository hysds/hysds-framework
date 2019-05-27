# hysds-framework
Installer for HySDS framework releases

## Prerequisites
1. ensure the following packages are installed:
   - python 3.7
   - pip 9.0.1+
   - setuptools 36.0.1+
   - virtualenv 1.10.1+
2. clone repository
   ```
   git clone https://github.com/hysds/hysds-framework.git
   cd hysds-framework
   ```

## Usage
```
$ ./install.sh -h
Usage:
    install.sh <component>
    -d | --dev
                                Development mode installation; install master branch of all repos instead
                                of official releases
    -r RELEASE | --release=RELEASE
                                Release tag to use for installation; without this option specified, a list
                                of releases will be printed and the installation stops
    -k GIT_OAUTH_TOKEN | --token=GIT_OAUTH_TOKEN
                                OAuth token to use to authenticate
    -h | --help                 Print help
    -t | --test                 Install test HySDS component, e.g. /export/home/hysdsops/mozart-test instead of /export/home/hysdsops/mozart
    COMPONENT                   <component>: mozart | grq | metrics | verdi
```

## Examples
- get list of releases for the mozart component
  ```
  $ ./install.sh mozart
  HySDS install directory set to /home/ops/mozart
  New python executable in /home/ops/mozart/bin/python
  Installing Setuptools............................................done.
  Installing Pip...................................................done.
  Created virtualenv at /home/ops/mozart.
  [2017-10-13 01:04:08,735: INFO/main] Github repo URL: https://xxxxxxxx@api.github.com/repos/hysds/hysds-framework/releases
  [2017-10-13 01:04:08,745: INFO/_new_conn] Starting new HTTPS connection (1): api.github.com
  No release specified. Use -r RELEASE | --release=RELEASE to install a specific release. Listing available releases:
  v2.0.0-alpha.1
  v2.0.0-alpha.2
  v2.0.0-alpha.3
  ```
- install HySDS release for the mozart component
  ```
  $ ./install.sh mozart -r v2.0.0-alpha.1
  ```
