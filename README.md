# Overview

`finaldesign_ee/` - final design optimised for energy efficiency

`finaldesign_hpp/` - final design optimised for latency

# How do I work on this project using git?

You want to work on the project? Follow these steps!

Login to the et4351 server. If you have files there from the labs, the TAs recommend to delete them to make space for the project, as vcd files take a lot of space.

then clone the repository using 
```
git clone https://github.com/Philipp413/et4351_project.git
```
enter the repository using
```
cd et4351_project
```
If you enter `git status`, you should see that you are on the branch `stable`.

Before you start making changes, make sure you create a new branch using
```
git checkout -b <BRANCH-NAME>
```
Your branch name can be something like `working_on_something` or you can choose a name like `pk/testbench`, so other people know that Philipp Kueppers is working on a testbench here.

Why are we doing this? As we are with 5 people working on the same code, this makes it easier to keep track of our changes and combine our work.

Using `git status` you can see what changes you made after you are done.
Then you add them using, e.g. `git add .` to add all your changes.
Commit them using `git commit -m "YOUR MESSAGE DESCRIBING YOUR CHANGES"`

Now you can push them to the remote repository with
```
git push --set-upstream origin <THE BRANCH YOU CREATED>
```  

After you are done with working on one block of work on your branch. You can go to the repository in your browser and create a merge request from your branch into the `stable` branch. Assign at least one person to review your changes and then merge your changes!









