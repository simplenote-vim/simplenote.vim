#!/bin/sh

#Script to automate some of the work involved in generating a new release
#Run it as `./generate_release 0.0.0`

#Regex to check argument
if [ `expr "$@" : '[0-9]\.[0-9]\.[0-9]'` -eq 0 ]; then
	echo "Argument must be in the form d.d.d";
	exit 1;
fi

#Bump version
sed -e "s/\(Version: \).*$/\1$@/" plugin/simplenote.vim > plugin/simplenote.vim.tmp && mv plugin/simplenote.vim.tmp plugin/simplenote.vim;

#Update Changelog with commits since last tag
last_tag=`git show-ref --tags | tail -n 1 | awk '{print $1}'`
git log $last_tag..HEAD --pretty=oneline --abbrev-commit | cut -d " " -f 2- > commit.log;
sed s/^/\-" "/ commit.log > commit.log.tmp;
echo "
## $@ `date '+(%m/%d/%Y)'`
`cat commit.log.tmp`" > commit.log
sed '/Changelog/ r commit.log' < CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
rm commit.log commit.log.tmp;

#Add commits
git add plugin/simplenote.vim;
git add CHANGELOG.md;
git commit -m "Bump version to v$@";

#Tag release
git tag v$@

#Echo what needs to be done next
echo "Changelog and version updated, commited and tagged."
echo "Review the Changelog and make necessary changes with git commit --amend."
echo "Remember to re-tag the commit if you amend it."
