#!/bin/bash

# Assumes that all turtlebots are named turtlebotXYZ where X,Y,Z are numbers
port=$(echo 43000 + $(hostname | tr -d -c 0-9) | bc)
echo "PORT: $port"
/bin/ssh -NT -o ServerAliveInterval=60 -R $port:localhost:22 jharwell@hal.cs.umn.edu
