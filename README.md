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
alias commit="path/to/bin/commit"
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

### `Git::Base`
Description: `Git::Base` is primarily used an abstract base class for other `Git` module classes to inherit from.

Intended uses: Abstract parent class for other `Git` module classes.
- Adds common methods to run git commands.
- Adds basic global variables getter methods
- Checks if globals.yml has necessary keys defined.

### `Git::Branch`
Description: `Git::Branch` is primarily used for basic functionality surrounding `git branch` commands.

Intended uses:
- Create a new branch based on `main`. This will get the most recent `main`, get user input to generate a branch name, bundle and yarn install, and migrate.
- Prune branches based on matching patterns provided by the user.

### `Git::Commit`
Description: `Git::Commit` is primarily used for basic functionality surrounding `git commit` commands.

Intended uses:
- Commit all your current work by validating it first by running rubocop, brakeman, and eslint. Then getting the user's input for the commit subject and body message. In doing so, we then can create the commit. The commit message has the Jira link automatically added to it.
- Amend will add all the current work and amend the last commit with no edit.

### `Git::Push`
Description: `Git::Push` is primarily used for basic functionality surrounding `git push` commands.

Intended uses:
- Can push, or force a push with a lease when including `--force` or `-f` flags, and before pushing, it will perform validation checks to make sure you're not pushing to `main` and run work validations like `brakeman`, `rubocop`, and `eslint`.
- Amend and push will validate your changes, amend the last commit with all of your changes, and then force a push with a lease.
- Or you can just run validation checks by themselves.

### `Git::Reset`
Description: `Git::Reset` is primarily used for basic functionality surrounding `git reset` commands.

Intended uses:
- Can automatically reset the current branch to the last commit.


