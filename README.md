# Act - A Conference Toolkit

Welcome to the yet another fork repository of Act. This README will
hopefully help you to get going with development of Act or to create
your own conference in a dummy playground on your local machine. This
version of Act uses psgi instead of Apache.

The focus here is to get a reproducible installation which allows to
hack on Act.  The first target is to get an installation recipe which
guides you from a checkout to a systems where *all tests pass.*

I know that the test suite is neither perfect nor complete, but
implementing new features without achieving that basic foundation is a
no-go.

In focus:

  * Allow new developers to hop on board easily
  * Fix known bugs
  * Work on legal restrictions (GDPR)
  * Get rid of the obsolete Apache 1 / modperl 1 platform (well,
    that's more or less a prerequisite for the first point)

Also interesting, but out of focus right now:

  * Platform considerations (docker, AWS etc.)
  * Introducing a database abstraction layer
  * Moving Act to a web application framework
  * Feature enhancements

Technical documentation about Act is available in the directory
lib/Act/Manual.  The pod files can be nicely read in GitHub, and even
more comfortably online from our demo server at
https://act-test.plix.at/manual/Manual.html.