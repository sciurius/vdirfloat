#!/bin/sh

lib=$HOME/wrk/DAViCal

cd $lib || exit 1

# Process all .ics files under the davical/calendars.
# Use --quiet to silcence informational messages.
vdirfloat davical/calendars
