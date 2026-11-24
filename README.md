# Open Journals :: Check archive's authors

This action runs checks on the archive of a paper submitted to Open Journals, and posts the result as a comment in the review issue. There are two checks, chosen with the `check` input:

- **`authors`** (default): reads the `authors` list from the paper's metadata (`paper.md`, or `paper.yml` for LaTeX papers) and compares it with the creators of the paper's Zenodo archive and with the contributors of the software's GitHub repository.
- **`zenodo-doi`**: checks that the archive's DOI is a Zenodo *version* DOI, the DOI of one specific version of a record. A *concept* DOI fails the check: it covers all versions of a record and always resolves to the latest one, so it won't keep pointing to the version that was reviewed. The reply gives the DOI of the latest version.

## Authors check

The comment has a table with one row per paper author, showing whether they are a creator of the Zenodo archive and whether they are among the GitHub contributors. It also lists Zenodo creators and GitHub contributors who weren't matched to any author. It is a helper for editors, not a pass/fail check.

Names are matched leniently, so small differences are flagged instead of missed:

- **Zenodo:** ✅ means the name is written exactly the same way (Zenodo's `Last, First` format counts as the same as `First Last`, and periods after initials are ignored). ⚠️ means it is probably the same person but the name is written differently: accents, capitalization, a missing initial, a short form of a name (`Eli` for `Elijah`), a one-letter typo, or a different name with the same ORCID. It is also shown, with both ORCIDs, when the paper and Zenodo list different ORCIDs for the same name.
- **GitHub:** ✅ means the name in the contributor's GitHub profile matches. ⚠️ means it is probably the same person: a similar name, or a username built from the author's name (for example `jsmith` for John Smith) when the profile doesn't have a different name.

GitHub contributors are people who made commits, so authors who contributed in other ways won't be found there. Reviewers, the editor and bots (the `ignored_users` input) are left out of the contributors list. If a repository has more than 50 contributors, only the 50 with the most commits are checked.

Usernames, and any other text containing `@` or `#`, are written in code spans, so the comment never mentions anyone or references other issues.

Only the paper's metadata is downloaded: the repository is cloned shallowly without file contents, and only `paper.md` or `paper.yml` is fetched.

### Finding the archive

1. The `archive` input, if it is a value other than empty or `Pending`.
2. The most recent comment in the review issue (not written by the bot) that mentions a Zenodo DOI or a Zenodo record URL. The reply links to the comment it used.

If the most recent `@bot set ... as archive` comment doesn't match the `archive` input (for example because that command didn't go through), the action doesn't guess: it replies with an error that links to that comment and asks the editor to set the right archive in the issue.

Only Zenodo archives and GitHub repositories can be checked. Other archives (and Zenodo sandbox records) and repositories that aren't on GitHub are skipped, and the reply starts with a warning that says so. A Zenodo record URL is replaced by its DOI, and the reply says so.

## Inputs

- **check**: Optional. `authors` (default) or `zenodo-doi`.
- **issue_id**: Required. The review issue id of the submission.
- **repository_url**: Required for `authors`. The repository URL of the submission containing the paper file.
- **branch**: Optional. Git branch where the paper is located. Defaults to the repository's default branch.
- **archive**: Optional. The archive value in the review issue, a Zenodo DOI. For `authors`, if it's empty or `Pending`, the issue's comments are searched. For `zenodo-doi` it is the DOI to check.
- **paper**: Optional, for `authors`. Path of the paper's file in the repository. Defaults to the `paper.md` or `paper.tex` closest to the root.
- **ignored_users**: Optional, for `authors`. GitHub usernames to leave out of the contributors list, separated by commas, spaces or new lines. Usually the editor and the reviewers.
- **archive_field**: Optional, for `authors`. Name of the archive field in `@bot set <DOI> as <archive_field>` comments. Defaults to `archive`.
- **bot_name**: Optional. The bot that runs commands in the review issue; its comments are skipped when looking for the archive. Defaults to `editorialbot`.
- **silent_if_not_zenodo**: Optional, for `zenodo-doi`. If `true`, nothing is posted when the archive is empty or isn't a Zenodo DOI (a figshare DOI, an OSF link, ...). Defaults to `false`: the reply says there's nothing to check.

### ENV

For the action to be able to read the issue and post comments there must be two env vars set with valid values:

- **GITHUB_TOKEN**: The token of the user posting the results of the checks
- **GH_REPO**: The repository where the review issue is found, in `username/repo-name` format

## Example

A workflow that [buffy](https://github.com/openjournals/buffy) can trigger with the `github_action` responder:

````yaml
name: Archive and authors checks
on:
  workflow_dispatch:
    inputs:
      issue_id:
        description: 'The issue number of the submission to post the results'
      repository_url:
        description: 'The repository URL of the submission'
      branch:
        description: 'The branch of the repository with the paper'
      archive:
        description: 'The archive value in the issue'
      editor:
        description: 'The editor of the submission'
      reviewers:
        description: 'The reviewers of the submission'
      bot_name:
        description: 'The bot running the commands'
env:
  GITHUB_TOKEN: ${{ secrets.BOT_USER_TOKEN }}
  GH_REPO: myorg/reviews
jobs:
  authors:
    runs-on: ubuntu-latest
    steps:
      - name: Check authors
        uses: openjournals/gh-action-archive-authors-check@main
        with:
          check: authors
          issue_id: ${{ github.event.inputs.issue_id }}
          repository_url: ${{ github.event.inputs.repository_url }}
          branch: ${{ github.event.inputs.branch }}
          archive: ${{ github.event.inputs.archive }}
          ignored_users: ${{ github.event.inputs.editor }} ${{ github.event.inputs.reviewers }}
          bot_name: ${{ github.event.inputs.bot_name }}
  zenodo-doi:
    runs-on: ubuntu-latest
    steps:
      - name: Check the Zenodo DOI
        uses: openjournals/gh-action-archive-authors-check@main
        with:
          check: zenodo-doi
          issue_id: ${{ github.event.inputs.issue_id }}
          archive: ${{ github.event.inputs.archive }}
          silent_if_not_zenodo: true
````

And the commands in buffy's settings, which call the workflow with values from the review issue:

````yaml
github_action:
  - authors:
      command: check authors
      workflow_repo: myorg/papers
      workflow_name: archive-authors.yml
      workflow_ref: main
      description: "Compare the paper's authors with the Zenodo archive's authors and the repository's contributors"
      data_from_issue:
        - branch
        - target-repository
        - issue_id
        - archive
        - editor
        - reviewers-list
        - bot_name
      mapping:
        repository_url: target-repository
        reviewers: reviewers-list
````

## Development

```
bundle install
bundle exec rspec
```
