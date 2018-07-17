# vdirfloat

`vdirfloat` implements floating appointments using a vdir.

For information about vdirs, see
https://vdirsyncer.pimutils.org/en/stable/index.html.

A floating appointment is a todo-like appointment that gets shifted to
the current day. So it will stay on the today's list of appointments
until it is marked completed.

Since calendar clients do not know about floating appointments, the
functionality is emulated as follows:

* An appointment is floating if its description starts with a special
  symbol, "U+21AA", which looks like an arrow with a hook. If you or
  your editor is smart it will be straighforward to prepend this symbol
  to the description of an appointment.

* To stop the appointment from floating, just remove the "U+21AA" from
  the description, or mark the appointment as "Confirmed" (most
  calendar clients can do that for you).

By default, `vdirfloat` will process a vdir of calendars with
`.ics` files, examine each file to detect whether it is a floating
appointment, and update the date to today's date. This needs to be
done once per day, preferrable close after midnight. A cron task or
equivalent can do that for you.

`vdirfloat' is written in Perl and should run on virtually any system
that supports Perl. It requires CPAN modules `Data::ICal' and
`Data::ICal::DateTime'. 
