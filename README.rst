.. _ln-build:

Bootstrapping The Code
======================

Assumptions
-----------

- You are running on a Debian-based linux environment, specifically Ubuntu. If
  you are running on something else (OSX, WSL, etc) you will have to manually
  modify the script to work on your target platform and/or probably have to
  build a **LOT** more stuff from source manually.

- You either have sudo privileges on the machine you want to install the project
  on, or all of the necessary development packages/software have already been
  installed by your sysadmin.

If either of these conditions are not met, you will be on your own for
getting things setup in your development environment of choice.

Bootstrap A Debug Build
-----------------------

#. Clone this repo.

#. Mark ``bootstrap.sh`` as as executable if it isn't already (``chmod +x
   bootstrap.sh``). It takes a number of arguments, which you can read about
   via::

     ./bootstrap.sh --help

#. Read the previous step again and **DO IT**. Seriously. It'll make everything
   else less mysterious and reduce your chances of errors.

#. Run the bootstrap script (it can be run from anywhere).  The default values
   of the arguments should be OK for most use cases.  If you are bootstrapping
   for ROS, make sure you source the appropriate ``setup.bash`` file before
   running the bootstrap or it will fail.

   .. IMPORTANT::

      When the script asks to you check the configuration before running, **DO
      IT**, ESPECIALLY if you are setting up multiple variations on the same
      machine, in order to avoid having in-progress work deleted or overwritten.

   Example usage::

     ./bootstrap.sh --syspkgs  > output.txt 2>&1

   This will install system packages, setup your development environment under
   ``$HOME/research``, install dependencies such as ARGoS to
   ``$HOME/.local/system`` and install compiled research code to
   ``$HOME/.local`` . The ``> output.txt 2>&1`` part is important to capture the
   output of running the script so that if there are errors it is easier to
   track them down (the script generates a LOT of output, which usually
   overflows terminal ringbuffers).

   The script is configured such that it will stop if any command fails. So if
   the script makes it all the way through and you see a ``BOOTSTRAP SUCCESS!``
   line at the end of the ``output.txt``, then you know everything
   worked. Otherwise look in the ``output.txt`` for the error and fix it and try
   running the script again (the script **should** be idempotent).

Bootstrap An Optimized Build
----------------------------

If you want to build an optimized version of the libraries (necessary for large
swarms), make sure you pass ``--opt`` to the ``bootstrap.sh`` script, as it is
for a debug build by default.
