
# Argo Navis

**Argo Navis** is a *set* of Galaxy tools designed for carrying out *Ancestral Discrete Trait* analyses, for phylogeographics and molecular epidemiology.
It does this in a Bayesian setting, using [BEAST2](http://beast2.org) to produce posteriors, and [PACT](http://bedford.io/projects/PACT/) as an analysis tool to extract information from these posteriors.

For more information about the tool, please see the help section of the `introduction.xml` "tool".


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
datatypes_config_file = <whateveryouhadbefor>,argo-navis/datatypes_conf.xml
tool_config_file = <whateveryouhadbefor>argo-navis/tool_conf.xml
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


