#!/bin/sh

lib=$HOME/wrk/DAViCal
export PATH=$HOME/bin:$PATH

cd $lib || exit 1

# Process all .ics files under the davical/calendars.
# Use --quiet to silence informational messages.
vdirfloat davical/calendars
