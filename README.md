# hysds-framework
Installer for HySDS framework releases

## Prerequisites
1. ensure the following packages are installed:
   - python 2.7
   - pip 9.0.1+
   - setuptools 36.0.1+
   - virtualenv 1.10.1+
2. setup Github OAuth token file
   ```
   cd $HOME
   echo "GIT_OAUTH_TOKEN=<your github oauth token>" > .git_oauth_token
   chmod 400 .git_oauth_token
   ```
3. clone repository
   ```
   git clone https://github.jpl.nasa.gov/hysds-org/hysds-framework.git
   cd hysds-framework
   ```

## Usage
```
$ ./install.sh -h
Usage:
    install.sh <component>
    -r RELEASE | --release=RELEASE
                                Release tag to use for installation; without this option specified, a list
                                of releases will be printed and the installation stops
    -h | --help                 Print help
    -t | --test                 Install test HySDS component, e.g. /home/ops/mozart-test instead of /home/ops/mozart
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
  [2017-08-09 19:25:37,789: INFO/main] Github repo URL: https://xxxxxxxx@github.jpl.nasa.gov/api/v3/repos/hysds-org/hysds-framework/releases
  [2017-08-09 19:25:37,798: INFO/_new_conn] Starting new HTTPS connection (1): github.jpl.nasa.gov
  No release specified. Use -r RELEASE | --release=RELEASE to install a specific release. Listing available releases:
  v2.0.0-alpha.1
  v2.0.0-alpha.2
  v2.0.0-alpha.3
  ```
- install HySDS release for the mozart component
  ```
  $ ./install.sh mozart -r v2.0.0-alpha.1
  ```
