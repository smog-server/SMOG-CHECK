#!/bin/bash

echo cleaning up files that may have been generated by an earlier execution of the test script
rm -r *.gro *.contacts *.settings *.output *.top *.ndx shadow.log FAILED temp.bifsif testing temp.cont.bifsif *contacts.SCM
