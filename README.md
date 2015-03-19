
# Argo Navis

**Argo Navis** is a set of Galaxy tools to carry out Bayesian discrete phylogenetic trait analyses using [BEAST2](http://beast2.org) to sample posteriors and [PACT](http://bedford.io/projects/PACT/) to extract information from these posteriors.
For background and more information, please see the help section of the `introduction.xml` "tool".

## Dependencies

Before running Argo Navis in either dev or production, there are a number of dependencies which must be installed:

* BEAST2, and the BEAST_CLASSIC package
* PACT
* R, and the following libraries
    * RColorBrewer
    * ggplot2
    * gtable
    * argparse
* python, and the following libraries
    * alnclst
    * biopython
    * biopy
    * numpy
    * csvkit
    * svg_stack.py
* inkscape
* java

Java, Inkscape, and R must all be installed.
For all the other dependencies, the `env/envbootstrap.sh` can be run to set up a virtualenv which contains the rest of the dependencies.


## Running in dev mode

### 1. Checkout the `galaxy-central` code:

```hg clone https://bitbucket.org/galaxy/galaxy-central```

You will need Mercurial installed.
I _know_.
`sudo apt-get install mercurial` if you don't have `hg` already.
Then run the above and `cd galaxy-central`.

### 2. Next clone _this_ repo into `tools/argo-navis`

```git clone git@github.com:fredhutchio/argo-navis.git tools/argo-navis```

Galaxy is a bit picky about where things live, so make sure you get the path right.

### 3. Setup your `galaxy.ini` file

Copy over `config/galaxy.ini.sample` to `config/galaxy.ini`
In your copy now, look for the following lines:

```
#datatypes_config_file = config/datatypes_conf.xml
...
#tool_config_file = config/tool_conf.xml,config/shed_tool_conf.xml
```

First, uncomment these and add `.sample` to the end of each of these files.
Then, add the `datatypes_conf.xml` and `tool_conf.xml` files to the end of these lines so they look like this:

```
datatypes_config_file = <whateveryouhadbefor>,tools/argo-navis/datatypes_conf.xml
tool_config_file = <whateveryouhadbefor>tools/argo-navis/tool_conf.xml
```

#### b) Friendly hosts/ports

By default, the server will run on `127.0.0.1`.
To easily access this server over the network, you can change this to `0.0.0.0` by uncommenting `#host=...` line on the 36 line of the `ini` file (there are other `host` settings, so make sure you get the right one) and setting it to `0.0.0.0`.
If you're running in a local network on a computer named `servername`, you will now be able to access the server on `servername:8080`.
You can also edit the `port` variable around line 31 if you need a port other than 8080, the default.

#### c) Consider activating the watch tools

Just uncomment the line `#watch_tools = False` and set to `True`.
You will need to install `watchdog` for this to work, if not already installed on your system.
It's a python library; Look it up.

### 4. Run it!

`sh run.sh` and observe the awesomeness!


## Setting up on an existing Galaxy deployment

If you already have an existing Galaxy deployment, you should be able to just clone the repo, and modify the datatypes and tool config lines in your `ini` file, as explained above.

If you've configured your Galaxy instance for installation of tools from the Galaxy toolsheds, you can use the `env/envbootstrap.sh` script mentioned above to install Argo Navis's dependencies (except Java, Inkscape, and R) to Galaxy's `tool_dependency_dir`.

Say your `tool_dependency_dir` is in `/home/galaxy/tool_deps`.
Create a directory called `argo_env/0.1` in this directory:

```
$ mkdir -p /home/galaxy/tool_deps/argo_env/0.1
```

Use the bootstrap script to create the virtualenv in the new directory:

```
$ ./env/envbootstrap.sh --venv /home/galaxy/tool_deps/argo_env/0.1/venv
```

This will take a while.
Once the bootstrap script finishes, create an `env.sh` file in `/home/galaxy/tool_deps/argo_env/0.1` with the following contents:

```
. /home/galaxy/tool_deps/argo_env/0.1/venv/bin/activate
R_LIBS=/home/galaxy/tool_deps/argo_env/0.1/venv/lib/R ; export R_LIBS
```

Galaxy will automatically source this file just before executing the tool command line in order to set up the job environment.
For more information on how this works, see the [tool dependencies page](https://wiki.galaxyproject.org/Admin/Config/ToolDependencies) on the Galaxy wiki.
