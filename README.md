# Bitex Main
Contains all bitex server side scripts.

# Setup
Clone this repo.
Under GUI enviroment, execute:
```bash
common/setup_env.sh
```

# Usage:
IB Runner:
```bash
tool/IB_tws_runner/ib_runner.sh $TWS_NAME $TWS_PSWD
```

# Guideline to add a new task:
Task files should be put in directory: 
```bash
$category/$taskname/
```
With a executor written in Bash:
```bash
$category/$taskname/$shortname.sh
```

Executor should always start with below lines:
```bash
#!/bin/bash --login
SOURCE="${BASH_SOURCE[0]}"
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $DIR/../../common/setup_env.sh
log "$SOURCE received args: $@"

# Invoke Python/Node.js/Ruby/... below:
```

Executor should always exit with code 0 when finished successfully, and with non-zero code in otherwise.
```bash
# Example: abort() is defined in common/setup_env.sh
python2 myscript.py || abort "Failed in executing myscript.py"
```

Task should use ./data and ./output to store crawled data and generated data. But these directories might be purged sometime and should not be used to store permanent data, use Database in this case.
```bash
$category/$taskname/data/
$category/$taskname/output/
# Could use date string as name of sub-directories, if needed:
$category/$taskname/data/20180601/
$category/$taskname/output/20180601/
```

Logs will be collected and put inside $category/$taskname/logs/ automatically if the script is executed by bitex system invoker. It is normal to find ./logs under this directory.
