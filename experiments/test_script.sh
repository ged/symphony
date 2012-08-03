#!/bin/sh

<?default subject to "Hooray!" ?>
<?default recipient to "isg@lists.laika.com" ?>

mail -s "<?attr subject ?>" <?attr recipient ?> <<EOF
Hello!  

By god, it seems to have worked.  Don't you feel good?
Cause you look good.

This mail was generated from a GroundControl job, sending and
executing a templated script on a random host.

host:  <?attr task_arguments[:hostname] ?> 
job:   <?attr job ?> 
queue: <?attr queue ?> 

Have a pleasant day.
EOF
