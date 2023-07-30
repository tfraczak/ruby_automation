# Objective
The aim of this project is to utilize Ruby code to automate some frequently used commands. For example: `git`.

# Installation
1. Clone the repo.
2. `cd` into the directory where you cloned it.
3. Run `bundle install`.
4. Change the values in the `./lib/globals.yml` file to suit your own needs.
5. Make sure you are in your `patient-check-in` project directory for these to work as intended. It seems like if you try to run the commands from anywhere, it tries to look for local configurations with respect to the current directory you're in.

# Future Changes
- [x] Probably should redo how the ruby code is executed to run the specific commands. Perhaps create ruby scripts that import the classes and execute the code.
- [ ] Abstract more of the hardcoded values for automating git commands into the `./lib/globals.yml` file.

# Git
The `Git` module enables the user to automate basic git commands. For example, if you'd like to commit all your current work, you can the following bash alias to commit all your work and have the ruby code ask for a commit subject, a detailed commit body, and automatically appends the Jira link based on the branch name:
```shell
alias commit="COMMIT=true ruby path/to/commit.rb"
```
Please note, this means that the branch name needs to follow a particular standard.

## Classes

### `Git::Base`
Description: `Git::Base` is only used for the basic functionality needed to create a `Git` class.

Use: Regular abstract class inheritance, see following example.
```ruby
module Git
  class Rebase < Base
    # ... class stuff
  end
end
```

### `Git::Branch`
Description: `Git::Branch` is primarily used for basic functionality surrounding `git branch` commands.

Use: Instantiate a new branch object with `Git::Branch.new`.

Public methods:
- `.create_branch` - Driver code for creating a new branch with basic input from user.
- `.prune` - Driver code for pruning local branches provided in the `ARGV` array.
- `#current` - Returns the current branch name as a string.
- `#valid_push?` - Returns whether or not the branch is the `main` branch.
- `create_branch` - Instantiated driver code to run all the logic for `.create_branch`.
- `#delete` - Deletes a single branch matching a substring.
- `#prune` - Instantiated driver code to delete all branches matching the string patterns entered by the user.
- `#checkout` - Executes `git checkout` to a single branch that matches a substring. It will not switch branches if there are multiple branches matching the substring.
- `#main?` - Checks if the current branch is the `main` branch.
- `#jira_pattern?` - Checks to see if the current branch name matches a particular pattern: "dev_initials-(pod|eci)-(Integer)(-optional-descriptor)"

