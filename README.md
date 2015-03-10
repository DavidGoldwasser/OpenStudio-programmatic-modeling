# OpenStudio-programmatic-modeling
Sample Code to programmatically create OpenStudio models by stringing measures together.



## Layout
* analysis - These are the exported files that are uploaded to the cloud server to run.
* analysis_local - These are models and IDF made by local run of the measures.
* projects - List of projects in the form of analysis scripts. These are the file that you should edit and copy.
* seeds - Example seed OSM models.
* weather - Where to dump other weather files of interest.
* measures- Measures used in the workflow

## Instructions

* Install Repo 2.0 based on instructions in the run tests section of the [OpenStudio Measure Training documentation](http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/#running-the-measure-tests) .
* Also make site folder in ruby has path to OpenStudio (For now this is needed to run measures locally)

* Clone this repository to your computer.

![Clone Repository](docs/img/clone_repo.png)


* Open repository in GitShell

![Configure](docs/img/open_in_git_shell.png)


* Configure Git username and email address, as described [here](https://help.github.com/articles/set-up-git/)
* Install Bundle

```ruby
bundle install
```

![Configure](docs/img/git_config_bundle_install.png)


* Open Command window using command prompt

![Configure](docs/img/open_command_window_here.png)


* Use rake -T to see possible commands. Example below then uses rake workflow:make_models

```ruby
rake -T
```

```ruby
rake workflow:make_models
```

![Configure](docs/img/rake_t.png)

