buildbot-scripts
================

This repo is an import of the state of lsst-dev:/home/buildbot/RHEL6/scripts
as of 2015-03-17.  These scripts are invoked by the buildbot slave that
is currently running on lsst-dev.

These scripts already appear in the
[`lsst/buildbot`](https://github.com/lsst/buildbot/tree/master/scripts) repo.
However, that repo and the versions actively in use on lsst-dev are out of
sync.

It was decided to create a new repo for these scripts for experiments in running them outside of lsst-dev/buildbot.  The other buildbot related files in `lsst/buildbot` are not needed or desired for this work.

If these experiments are considered successful, this repo is intended to
become the authoritative source for these scripts and the duplicates will be
purged from `lsst/buildbot`.
