#!/bin/bash
ss -s|grep "TCP:" | sed 's/,/ /g'|cut -d ' ' -f 6;
