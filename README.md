# Introduction
* lib_shell.sh is a collection of shell functions I use in differents bash shell projects.
* my_warp.sh is the main script used to call all functions

Assuming you check out everything in ${HOME}/git, minimal conf file will be:
``` shell
chmod +x ${HOME}/git/shell/my_warp.sh ; mkdir ${HOME}/conf ; echo -e "VERBOSE=false\nDEBUG=false\nFUNC_LIST=()\nGIT_DIR=\"\${HOME}/git\"" > ${HOME}/conf/my_warp.conf
```

# 
[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/PJuzGhtpJT1B6rC5YF9SLA/RD3EguHi6n1Hz4ZnXR7yD2/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/circleci/PJuzGhtpJT1B6rC5YF9SLA/RD3EguHi6n1Hz4ZnXR7yD2/tree/main) [![codecov](https://codecov.io/github/cretinon/shell/graph/badge.svg?token=KEXL9YUJNL)](https://codecov.io/github/cretinon/shell)
