#!/bin/fish

set PATH /usr/lib/jvm/java-8-openjdk/bin /usr/local/sbin /usr/local/bin /usr/bin /opt/cuda/bin /usr/lib/jvm/default/bin /usr/bin/site_perl /usr/bin/vendor_perl /usr/bin/core_perl
set NEO4J_HOME /usr/share/neo4j
neo4j-admin $argv
