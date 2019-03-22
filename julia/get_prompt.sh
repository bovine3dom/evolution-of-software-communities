#!/bin/bash

: ${JULIA_NUM_THREADS:=4}
export JULIA_NUM_THREADS
julia -L init.jl
