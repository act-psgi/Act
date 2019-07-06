# Act - A Conference Toolkit

Welcome to the yet another fork repository of Act. This README will
hopefully help you to get going with development of Act or to create
your own conference in a dummy playground on your local machine. This
version of Act uses PSGI instead of Apache.

The focus here is to get a reproducible installation which allows to
hack on Act.  The first target is to get an installation recipe which
guides you from a checkout to a systems where *all tests pass.*

I know that the test suite is neither perfect nor complete, but
implementing new features without achieving that basic foundation is a
no-go.

## About this Branch

This branch is a work to refactor Act's database usage.  The behaviour
of the software is supposed to be unchanged.  The target is a
*separation between business logic and infrastructure/database layers.*

In the legacy branches, Act is using a homegrown database mapping
which allows declaration of attributes and offers a central store /
load interface for objects using Act::Object as a base class.  The
shortcoming is that this mapping does not support queries nor
relations between objects - this is why the SQL stuff for the missing
features has been spread over the individual modules.  Also, it was
left to individual modules to perform the database commit.  This makes
a separation between the application and infrastructure (here:
database) layers impossible.

In the intermediate step all classes - with exception of Act::Object
itself - got rid of their SQL stuff in favor of API calls to the new
and ephemeral module Act::Data.  Act::Data is ugly, and will vanish
again, but for the moment it serves to assess the API needed, to group
subroutines and methods, and to design suitable objects.  Before this
branch ever gets merged, this explanation should be removed, or
adapted accordingly.

Act::Data intentionally does not export any function so that all
function calls are like Act::Data::something to make identification of
the callers unambigous.

As short-term benefits, some duplicate SQL calls have been identified
and mapped ti the same function, and some these functions can be
useful for setting up defined test scenarios.
