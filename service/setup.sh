#!/bin/bash
set -e

# This dependency is needed to resolve `ImportError: libGL.so.1: cannot open shared object file: No such file or directory` error.
apt-get install -y libgl1-mesa-glx